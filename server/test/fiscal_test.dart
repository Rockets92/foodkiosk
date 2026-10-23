import 'dart:convert';
import 'dart:io';

import 'package:kiosk_core/kiosk_core.dart';
import 'package:kiosk_server/kiosk_server.dart';
import 'package:path/path.dart' as p;
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

const pin = '1234';

late KioskApp app;

Future<(int, dynamic)> call(
  String method,
  String path, {
  Object? body,
  bool staff = true,
}) async {
  final res = await app.handler(
    Request(
      method,
      Uri.parse('http://localhost$path'),
      body: body == null ? null : jsonEncode(body),
      headers: {
        'content-type': 'application/json',
        if (staff) 'x-staff-pin': pin,
      },
    ),
  );
  final text = await res.readAsString();
  return (res.statusCode, text.isEmpty ? null : jsonDecode(text));
}

const merchant = {
  'legalName': 'Burger Bros S.r.l.',
  'vatNumber': '01234567897',
  'address': 'Via Roma 1',
  'zip': '20100',
  'city': 'Milano',
  'province': 'mi',
};

const credentials = {
  'taxCode': 'RSSMRA80A01H501U',
  'password': 'Segreta!2026',
  'pin': '1234567890',
};

/// Pay at the till, documento commerciale online when paid.
final tillFlow = FlowConfig(
  paymentMode: PaymentMode.counter,
  rules: {
    FlowEvent.submitted: [FlowAction.printCustomerTicket],
    FlowEvent.paid: [
      FlowAction.sendToKitchenDisplay,
      FlowAction.issueFiscalDocument,
    ],
  },
);

Future<void> configure(Map<String, Object?> patch) async {
  final (status, body) = await call('PUT', '/api/admin/settings', body: patch);
  expect(status, 200, reason: '$body');
}

Future<void> goLiveOnline() => configure({
  'demoMode': false,
  'flow': tillFlow.toJson(),
  'fiscal': {
    'type': 'adeOnline',
    'options': {'provider': 'sandbox'},
  },
  'merchant': merchant,
});

Future<Map<String, dynamic>> cashAtTill({
  String method = 'card',
  Map<String, Object?> extra = const {},
  int expect = 201,
}) async {
  final (s, order) = await call(
    'POST',
    '/api/staff/orders',
    body: {
      'serviceMode': 'takeAway',
      'lines': [
        {'productId': 'classic-burger', 'quantity': 2},
        {'productId': 'fries'},
      ],
      'payment': method,
      ...extra,
    },
  );
  if (s != expect) fail('HTTP $s: $order');
  return (order as Map).cast();
}

Future<List<dynamic>> jobs(String orderId) async {
  final (_, body) = await call('GET', '/api/staff/print-jobs?orderId=$orderId');
  return body['jobs'] as List;
}

void main() {
  setUp(() => app = KioskApp(AppDatabase.inMemory()));
  tearDown(() => app.close());

  group('tax ids', () {
    test('VAT numbers and tax codes are checked', () {
      expect(TaxId.isValidVatNumber('01234567897'), isTrue);
      expect(TaxId.isValidVatNumber('01234567890'), isFalse);
      expect(TaxId.isValidTaxCode('RSSMRA80A01H501U'), isTrue);
      expect(TaxId.isValidTaxCode('RSSMRA80A01H501X'), isFalse);
      expect(TaxId.isValidTaxCode('01234567897'), isTrue, reason: 'company');
      expect(TaxId.isValidLotteryCode('AB12CD34'), isTrue);
      expect(TaxId.isValidLotteryCode('AB12'), isFalse);
    });

    test('going live online needs the business details', () async {
      final (s, body) = await call(
        'PUT',
        '/api/admin/settings',
        body: {
          'demoMode': false,
          'flow': tillFlow.toJson(),
          'fiscal': {'type': 'adeOnline', 'options': <String, Object?>{}},
          'merchant': {...merchant, 'vatNumber': '01234567890'},
        },
      );
      expect(s, 400);
      expect(body['message'], contains('VAT number'));
    });

    test('credentials cannot hide in the device options', () async {
      final (s, body) = await call(
        'PUT',
        '/api/admin/settings',
        body: {
          'fiscal': {
            'type': 'adeOnline',
            'options': {'password': 'x'},
          },
        },
      );
      expect(s, 400);
      expect(body['message'], contains('Agenzia delle Entrate section'));
    });
  });

  group('Agenzia delle Entrate account', () {
    test('credentials are stored encrypted and never sent back', () async {
      final (s0, before) = await call('GET', '/api/admin/fiscal/account');
      expect(s0, 200);
      expect(before['account']['connected'], isFalse);

      final (s, body) = await call(
        'PUT',
        '/api/admin/fiscal/account',
        body: credentials,
      );
      expect(s, 200, reason: '$body');
      final account = body['account'];
      expect(account['connected'], isTrue);
      expect(account['taxCode'], 'RSS************U');
      expect(account['daysLeft'], 89);
      expect(account['renewSoon'], isFalse);
      final text = jsonEncode(body);
      expect(text, isNot(contains('Segreta')));
      expect(text, isNot(contains('1234567890')));

      // Nowhere in the database in clear.
      final dump = jsonEncode([
        for (final r in app.db.db.select('SELECT * FROM settings')) r['value'],
      ]);
      expect(dump, isNot(contains('Segreta')));
      expect(dump, isNot(contains('1234567890')));
      expect(dump, isNot(contains('RSSMRA80A01H501U')));
      expect(app.fiscalAccount.credentials!.password, 'Segreta!2026');

      final (_, settings) = await call('GET', '/api/admin/settings');
      expect(jsonEncode(settings), isNot(contains('Segreta')));
    });

    test('a renewal only needs the new password', () async {
      await call('PUT', '/api/admin/fiscal/account', body: credentials);
      final (s, _) = await call(
        'PUT',
        '/api/admin/fiscal/account',
        body: {'password': 'Nuova!2026x'},
      );
      expect(s, 200);
      final c = app.fiscalAccount.credentials!;
      expect(c.password, 'Nuova!2026x');
      expect(c.pin, '1234567890');
    });

    test('wrong formats are refused', () async {
      final (s, body) = await call(
        'PUT',
        '/api/admin/fiscal/account',
        body: {...credentials, 'pin': '1234'},
      );
      expect(s, 400);
      expect(body['error'], 'invalidPin');
      final (s2, _) = await call(
        'PUT',
        '/api/admin/fiscal/account',
        body: {...credentials, 'taxCode': 'RSSMRA80A01H501X'},
      );
      expect(s2, 400);
    });

    test('the check logs in with the provider', () async {
      await configure({
        'fiscal': {'type': 'adeOnline', 'options': <String, Object?>{}},
        'merchant': merchant,
      });
      var (_, body) = await call('POST', '/api/admin/fiscal/check');
      expect(body['ok'], isFalse, reason: 'not connected yet');
      expect(body['message'], contains('non collegato'));

      await call('PUT', '/api/admin/fiscal/account', body: credentials);
      (_, body) = await call('POST', '/api/admin/fiscal/check');
      expect(body['ok'], isTrue, reason: '$body');
      expect(body['account']['lastCheck']['ok'], isTrue);

      // The sandbox refuses the password "errata", like a wrong login.
      final c = app.fiscalAccount.credentials!;
      await expectLater(
        SandboxDcProvider().verify(
          AdeCredentials(
            taxCode: c.taxCode,
            password: 'errata',
            pin: c.pin,
            updatedAt: DateTime.now(),
          ),
          MerchantProfile.fromJson(merchant),
        ),
        throwsA(isA<FiscalException>()),
      );

      final (_, gone) = await call('DELETE', '/api/admin/fiscal/account');
      expect(gone['account']['connected'], isFalse);
    });

    test('the key file opens the store again, and only this one', () {
      final dir = Directory.systemTemp.createTempSync('fk-secrets');
      addTearDown(() => dir.deleteSync(recursive: true));
      final db = AppDatabase.open(p.join(dir.path, 'test.db'));
      addTearDown(db.close);
      SecretStore.open(db, dir.path).write('ade', {'password': 'x'});
      expect(File(p.join(dir.path, 'secret.key')).existsSync(), isTrue);
      expect(SecretStore.open(db, dir.path).read('ade'), {'password': 'x'});

      File(p.join(dir.path, 'secret.key')).deleteSync();
      final other = SecretStore.open(db, dir.path);
      expect(other.contains('ade'), isTrue);
      expect(other.read('ade'), isNull, reason: 'another key cannot open it');
    });
  });

  group('documento commerciale online', () {
    test('cashing at the till issues and prints the document', () async {
      await goLiveOnline();
      await call('PUT', '/api/admin/fiscal/account', body: credentials);

      final order = await cashAtTill(
        extra: {
          'fiscalCustomer': {'lotteryCode': 'ab12cd34'},
        },
      );
      final doc = order['fiscalDocument'];
      expect(doc['provider'], 'adeOnline');
      expect(doc['number'], matches(r'^\d{4}-\d{4}$'));
      expect(doc['printedByDevice'], isFalse);
      expect(doc['test'], isTrue, reason: 'sandbox');
      expect(doc['lotteryCode'], 'AB12CD34');
      expect(order['kitchenStatus'], 'queued');

      final printed = await jobs(order['id'] as String);
      expect(printed, hasLength(1), reason: 'the document is the ticket');
      expect(printed.single['kind'], 'fiscal');
      final text = printed.single['content'] as String;
      for (final expected in [
        'Burger Bros S.r.l.',
        'Via Roma 1',
        '20100 Milano (MI)',
        'P.IVA 01234567897',
        'DOCUMENTO COMMERCIALE',
        'di vendita o prestazione',
        'Classic Burger',
        '10%',
        'TOTALE COMPLESSIVO',
        'di cui IVA',
        'Pagamento elettronico',
        'DOCUMENTO N. ${doc['number']}',
        'Codice lotteria: AB12CD34',
        'DOCUMENTO DI PROVA',
      ]) {
        expect(text, contains(expected));
      }
      expect(text, isNot(contains('Pagamento contante')));
    });

    test('cash shows what was handed over and the change', () async {
      await goLiveOnline();
      await call('PUT', '/api/admin/fiscal/account', body: credentials);
      final order = await cashAtTill(
        method: 'cash',
        extra: {'receivedCents': 5000},
      );
      final text = (await jobs(order['id'] as String)).single['content'];
      expect(text, contains('Pagamento contante'));
      expect(text, contains('Importo pagato'));
      expect(text, contains('Resto'));
    });

    test('the lottery code needs a card payment', () async {
      await goLiveOnline();
      await call('PUT', '/api/admin/fiscal/account', body: credentials);
      final (s, body) = await call(
        'POST',
        '/api/staff/orders',
        body: {
          'lines': [
            {'productId': 'fries'},
          ],
          'payment': 'cash',
          'fiscalCustomer': {'lotteryCode': 'AB12CD34'},
        },
      );
      expect(s, 400);
      expect(body['error'], 'lotteryNeedsCard');
    });

    test('without the account the sale goes on and can be retried', () async {
      await goLiveOnline();
      final order = await cashAtTill();
      expect(order['paymentStatus'], 'paid');
      expect(order['fiscalDocument'], isNull);
      final failed = (order['history'] as List).lastWhere(
        (e) => e['type'] == 'actionFailed',
      );
      expect(failed['detail'], contains('non collegato'));

      await call('PUT', '/api/admin/fiscal/account', body: credentials);
      final (s, retried) = await call(
        'POST',
        '/api/staff/orders/${order['id']}/actions/issueFiscalDocument',
      );
      expect(s, 200);
      expect(retried['fiscalDocument']['number'], isNotNull);
      expect((await jobs(order['id'] as String)).first['kind'], 'fiscal');

      // A reprint at the till is marked as a copy.
      final (_, again) = await call(
        'POST',
        '/api/staff/orders/${order['id']}/actions/printCustomerTicket',
      );
      expect(again['fiscalDocument'], isNotNull);
      final latest = (await jobs(order['id'] as String)).first;
      expect(latest['content'], contains('COPIA - RISTAMPA'));
    });

    test('cancelling a paid order voids its document', () async {
      await goLiveOnline();
      await call('PUT', '/api/admin/fiscal/account', body: credentials);
      final order = await cashAtTill();
      final number = order['fiscalDocument']['number'];

      final (s, cancelled) = await call(
        'POST',
        '/api/staff/orders/${order['id']}/cancel',
        body: {'reason': 'errore'},
      );
      expect(s, 200);
      expect(cancelled['status'], 'cancelled');
      final voided = cancelled['fiscalVoid'];
      expect(voided['kind'], 'void');
      expect(voided['voidsNumber'], number);

      final text = (await jobs(order['id'] as String)).first['content'];
      expect(text, contains('emesso per ANNULLAMENTO'));
      expect(text, contains('Documento di riferimento'));
      expect(text, contains('N. $number del'));

      final (s2, _) = await call(
        'POST',
        '/api/staff/orders/${order['id']}/fiscal-void',
      );
      expect(s2, 409, reason: 'already voided');
    });

    test('a failed void is recorded and retried', () async {
      await goLiveOnline();
      await call('PUT', '/api/admin/fiscal/account', body: credentials);
      final order = await cashAtTill();
      await call('DELETE', '/api/admin/fiscal/account');
      final (_, cancelled) = await call(
        'POST',
        '/api/staff/orders/${order['id']}/cancel',
      );
      expect(cancelled['fiscalVoid'], isNull);
      expect((cancelled['history'] as List).last['type'], 'fiscalVoidFailed');
      await call('PUT', '/api/admin/fiscal/account', body: credentials);
      final (s, retried) = await call(
        'POST',
        '/api/staff/orders/${order['id']}/fiscal-void',
      );
      expect(s, 200);
      expect(retried['fiscalVoid']['voidsNumber'], isNotNull);
    });

    test('on the kiosk the document replaces the ticket', () async {
      await configure({
        'flow': FlowConfig.fullService.toJson(),
        'payment': {
          'type': 'demo',
          'options': {'delayMs': 0},
        },
        'fiscal': {'type': 'adeOnline', 'options': <String, Object?>{}},
        'merchant': merchant,
      });
      final (_, order) = await call(
        'POST',
        '/api/orders',
        staff: false,
        body: {
          'serviceMode': 'eatIn',
          'lines': [
            {'productId': 'fries'},
          ],
        },
      );
      final (_, paid) = await call(
        'POST',
        '/api/orders/${order['id']}/pay',
        staff: false,
      );
      expect(paid['fiscalDocument']['provider'], 'demo');
      final printed = await jobs(order['id'] as String);
      expect(printed, hasLength(1));
      expect(printed.single['content'], contains('DOCUMENTO COMMERCIALE'));
      expect(printed.single['content'], contains('DEMO'));
    });

    test('with a registratore telematico the ticket is a reminder', () async {
      await configure({
        'flow': FlowConfig.fullService.toJson(),
        'payment': {
          'type': 'demo',
          'options': {'delayMs': 0},
        },
        'fiscal': {
          'type': 'epsonRt',
          'options': {'host': '192.168.1.60'},
        },
      });
      final (_, order) = await call(
        'POST',
        '/api/orders',
        staff: false,
        body: {
          'lines': [
            {'productId': 'fries'},
          ],
        },
      );
      await call('POST', '/api/orders/${order['id']}/pay', staff: false);
      final text = (await jobs(order['id'] as String)).single['content'];
      expect(text, isNot(contains('DOCUMENTO COMMERCIALE')));
      expect(text, contains('Documento commerciale N.'));
      expect(text, contains('non è un documento commerciale'));
    });
  });
}
