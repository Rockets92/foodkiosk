import 'dart:convert';

import 'package:kiosk_core/kiosk_core.dart';
import 'package:kiosk_server/kiosk_server.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

const pin = '1234';

late KioskApp app;

Future<(int, dynamic)> call(
  String method,
  String path, {
  Object? body,
  bool staff = false,
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

Map<String, Object?> line(String productId, {int qty = 1}) => {
  'productId': productId,
  'quantity': qty,
};

final classic = line('classic-burger');
final fries = line('fries');

Future<(int, dynamic)> order(
  List<Map<String, Object?>> lines, {
  String? code,
  bool counter = false,
  Map<String, Object?> extra = const {},
}) => call(
  'POST',
  counter ? '/api/staff/orders' : '/api/orders',
  staff: counter,
  body: {
    'serviceMode': 'eatIn',
    'language': 'it',
    'lines': lines,
    'discountCode': ?code,
    ...extra,
  },
);

Future<Map<String, dynamic>> createCode(Map<String, Object?> json) async {
  final (s, body) = await call(
    'POST',
    '/api/admin/discounts',
    body: json,
    staff: true,
  );
  expect(s, 201, reason: '$body');
  return body as Map<String, dynamic>;
}

Future<int> usedCount(String code) async {
  final (_, body) = await call('GET', '/api/admin/discounts', staff: true);
  return (body['codes'] as List).firstWhere(
        (c) => c['code'] == code,
      )['usedCount']
      as int;
}

void main() {
  setUp(() => app = KioskApp(AppDatabase.inMemory()));
  tearDown(() => app.close());

  group('discount codes', () {
    test('demo codes are seeded and checkable from the kiosk', () async {
      final (s, body) = await call(
        'POST',
        '/api/discounts/check',
        body: {'code': ' benvenuto10 '},
      );
      expect(s, 200, reason: '$body');
      expect(body['type'], 'percent');
      expect(body['percent'], 10);
      // The kiosk never sees usage stats.
      expect(body.containsKey('usedCount'), isFalse);
    });

    test('a QR code holding a link resolves to its code', () {
      expect(
        DiscountCode.normalize('https://example.com/c?code=meno3'),
        'MENO3',
      );
      expect(
        DiscountCode.normalize('https://example.com/c/PATATINE'),
        'PATATINE',
      );
    });

    test('a percentage comes off the order total', () async {
      final (_, plain) = await order([classic, fries]);
      final (s, body) = await order([classic, fries], code: 'BENVENUTO10');
      expect(s, 201, reason: '$body');
      final subtotal = plain['totalCents'] as int;
      expect(body['subtotalCents'], subtotal);
      expect(body['discountCents'], (subtotal * 0.1).round());
      expect(body['totalCents'], subtotal - (subtotal * 0.1).round());
      expect(body['discount']['code'], 'BENVENUTO10');
      expect(await usedCount('BENVENUTO10'), 1);
    });

    test('a fixed amount needs the minimum order', () async {
      final (s, body) = await order([fries], code: 'MENO3');
      expect(s, 400);
      expect(body['error'], 'minOrderNotReached');
      final (s2, body2) = await order(
        [line('menu-classic', qty: 2)]
            .map(
              (l) => {
                ...l,
                'optionIds': ['size-m', 'side-fries', 'drink-cola'],
              },
            )
            .toList(),
        code: 'meno3',
      );
      expect(s2, 201, reason: '$body2');
      expect(body2['discountCents'], 300);
    });

    test('a free product needs the product in the order', () async {
      final (s, body) = await order([classic], code: 'PATATINE');
      expect(s, 400);
      expect(body['error'], 'freeProductMissing');
      expect(body['details']['productId'], 'fries');

      final (_, plain) = await order([fries]);
      final (s2, body2) = await order([
        classic,
        line('fries', qty: 2),
      ], code: 'PATATINE');
      expect(s2, 201, reason: '$body2');
      expect(body2['discountCents'], plain['totalCents']);
    });

    test(
      'the usage limit is enforced and cancelling gives the use back',
      () async {
        await createCode({
          'code': 'UNAVOLTA',
          'type': 'amount',
          'amountCents': 100,
          'maxUses': 1,
        });
        final (s, first) = await order([classic], code: 'UNAVOLTA');
        expect(s, 201);
        final (s2, body) = await order([classic], code: 'UNAVOLTA');
        expect(s2, 409);
        expect(body['error'], 'codeExhausted');

        await call('POST', '/api/orders/${first['id']}/cancel');
        expect(await usedCount('UNAVOLTA'), 0);
        final (s3, _) = await order([classic], code: 'UNAVOLTA');
        expect(s3, 201);
      },
    );

    test('expired, future and disabled codes are refused', () async {
      final now = DateTime.now();
      await createCode({
        'code': 'SCADUTO',
        'type': 'percent',
        'percent': 5,
        'validUntil': now.subtract(const Duration(days: 1)).toIso8601String(),
      });
      await createCode({
        'code': 'FUTURO',
        'type': 'percent',
        'percent': 5,
        'validFrom': now.add(const Duration(days: 1)).toIso8601String(),
      });
      await createCode({
        'code': 'SPENTO',
        'type': 'percent',
        'percent': 5,
        'enabled': false,
      });
      for (final (code, error) in [
        ('SCADUTO', 'codeExpired'),
        ('FUTURO', 'codeNotYetValid'),
        ('SPENTO', 'codeDisabled'),
        ('NONESISTE', 'codeNotFound'),
      ]) {
        final (_, body) = await order([classic], code: code);
        expect(body['error'], error, reason: code);
      }
    });

    test('codes are refused where the settings do not allow them', () async {
      Future<void> configure(Map<String, Object?> d) async {
        final (s, body) = await call(
          'PUT',
          '/api/admin/settings',
          staff: true,
          body: {'discounts': d},
        );
        expect(s, 200, reason: '$body');
      }

      await configure({
        'enabled': true,
        'manualEntry': false,
        'scanner': false,
        'atCounter': true,
      });
      final (_, kiosk) = await order([classic], code: 'BENVENUTO10');
      expect(kiosk['error'], 'discountsDisabled');
      final (s, _) = await order([classic], code: 'BENVENUTO10', counter: true);
      expect(s, 201);

      await configure({'enabled': false});
      final (_, off) = await order(
        [classic],
        code: 'BENVENUTO10',
        counter: true,
      );
      expect(off['error'], 'discountsDisabled');

      // Enabled but with nowhere to enter a code is a configuration error.
      final (bad, _) = await call(
        'PUT',
        '/api/admin/settings',
        staff: true,
        body: {
          'discounts': {
            'enabled': true,
            'manualEntry': false,
            'scanner': false,
            'atCounter': false,
          },
        },
      );
      expect(bad, 400);
    });

    test('codes are unique and validated', () async {
      final (s, body) = await call(
        'POST',
        '/api/admin/discounts',
        staff: true,
        body: {'code': 'benvenuto10', 'type': 'percent', 'percent': 20},
      );
      expect(s, 409);
      expect(body['error'], 'codeTaken');
      final (s2, _) = await call(
        'POST',
        '/api/admin/discounts',
        staff: true,
        body: {'code': 'NUOVO', 'type': 'percent', 'percent': 150},
      );
      expect(s2, 400);
      final (s3, _) = await call(
        'POST',
        '/api/admin/discounts',
        staff: true,
        body: {'code': 'OMAGGIO', 'type': 'freeProduct', 'productId': 'nope'},
      );
      expect(s3, 400);
    });

    test('guessing codes is throttled', () async {
      for (var i = 0; i < 10; i++) {
        final (s, _) = await call(
          'POST',
          '/api/discounts/check',
          body: {'code': 'WRONG$i'},
        );
        expect(s, 404);
      }
      final (s, body) = await call(
        'POST',
        '/api/discounts/check',
        body: {'code': 'BENVENUTO10'},
      );
      expect(s, 429);
      expect(body['error'], 'tooManyAttempts');
    });

    test('the cashier can cash an order with a code at once', () async {
      final (s, body) = await order(
        [classic],
        code: 'BENVENUTO10',
        counter: true,
        extra: {'payment': 'card'},
      );
      expect(s, 201, reason: '$body');
      expect(body['paymentStatus'], 'paid');
      expect(body['payment']['cardCents'], body['totalCents']);
    });

    test(
      'editing at the till recomputes, swaps and removes the code',
      () async {
        final (_, created) = await order([classic], code: 'BENVENUTO10');
        final id = created['id'];
        Future<Map<String, dynamic>> edit(
          List<Map<String, Object?>> lines, {
          String? code,
        }) async {
          final (s, body) = await call(
            'PUT',
            '/api/staff/orders/$id/lines',
            staff: true,
            body: {
              'serviceMode': 'eatIn',
              'lines': lines,
              'discountCode': ?code,
            },
          );
          expect(s, 200, reason: '$body');
          return body as Map<String, dynamic>;
        }

        final more = await edit([classic, classic], code: 'BENVENUTO10');
        expect(more['discountCents'], (more['subtotalCents'] * 0.1).round());
        expect(await usedCount('BENVENUTO10'), 1);

        final swapped = await edit([classic, fries], code: 'PATATINE');
        expect(swapped['discount']['code'], 'PATATINE');
        expect(await usedCount('BENVENUTO10'), 0);
        expect(await usedCount('PATATINE'), 1);

        final removed = await edit([classic, fries]);
        expect(removed['discount'], isNull);
        expect(removed['totalCents'], removed['subtotalCents']);
        expect(await usedCount('PATATINE'), 0);
      },
    );

    test('tickets, VAT and the day summary show the discount', () async {
      final (_, body) = await order(
        [classic],
        code: 'BENVENUTO10',
        counter: true,
        extra: {'payment': 'cash'},
      );
      final o = Order.fromJson((body as Map).cast());
      final text = customerTicket(o, const KioskSettings()).toPlainText(42);
      expect(text, contains('Sconto BENVENUTO10'));
      expect(text, contains('Subtotale'));
      final vat = o.vatBreakdown.values.fold(0, (a, b) => a + b);
      expect(vat, (o.totalCents - o.totalCents / 1.1).round());

      final rt = EpsonFiscalPrinter(host: 'x').buildReceipt(o);
      expect(rt, contains('printRecSubtotalAdjustment'));
      expect(
        rt,
        contains(
          'amount="${(o.discountCents / 100).toStringAsFixed(2).replaceAll('.', ',')}"',
        ),
      );

      final (_, summary) = await call('GET', '/api/staff/summary', staff: true);
      expect(summary['discountCents'], o.discountCents);
      expect(summary['discountCodes'].single['code'], 'BENVENUTO10');
    });
  });
}
