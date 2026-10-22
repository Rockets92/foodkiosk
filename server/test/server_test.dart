import 'dart:convert';
import 'dart:io';

import 'package:kiosk_core/kiosk_core.dart';
import 'package:kiosk_server/kiosk_server.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

const pin = '1234';

class FailingPrinter extends TicketPrinter {
  @override
  String get type => 'broken';
  @override
  int get width => 42;
  @override
  Future<void> printTicket(Ticket ticket) async =>
      throw const SocketException('printer offline');
}

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

Future<void> configure(Map<String, Object?> patch) async {
  final (status, body) = await call(
    'PUT',
    '/api/admin/settings',
    body: patch,
    staff: true,
  );
  expect(status, 200, reason: '$body');
}

Map<String, Object?> burgerMeal({int qty = 1}) => {
  'productId': 'menu-classic',
  'quantity': qty,
  'optionIds': ['size-m', 'side-fries', 'drink-cola'],
};

Future<Map<String, dynamic>> placeOrder(
  List<Map<String, Object?>> lines, {
  String? paymentChoice,
}) async {
  final (status, body) = await call(
    'POST',
    '/api/orders',
    body: {
      'serviceMode': 'eatIn',
      'language': 'it',
      'lines': lines,
      'paymentChoice': ?paymentChoice,
    },
  );
  expect(status, 201, reason: '$body');
  return body as Map<String, dynamic>;
}

void main() {
  setUp(() {
    final registry = AdapterRegistry()
      ..printer['broken'] = (_) => FailingPrinter();
    app = KioskApp(AppDatabase.inMemory(), registry: registry);
  });
  tearDown(() => app.close());

  group('menu', () {
    test('demo menu is served with allergens and placeholders', () async {
      final (status, body) = await call('GET', '/api/menu');
      expect(status, 200);
      final menu = Menu.fromJson((body as Map).cast());
      expect(menu.categories, hasLength(5));
      final burger = menu.product('classic-burger')!;
      expect(burger.allergens, contains(Allergen.gluten));
      expect(burger.imageUrl, startsWith('/media/placeholder/'));
    });

    test('disabled products disappear from the kiosk menu', () async {
      final (s, _) = await call(
        'PATCH',
        '/api/admin/products/brownie',
        body: {'enabled': false},
        staff: true,
      );
      expect(s, 200);
      final (_, body) = await call('GET', '/api/menu');
      expect(Menu.fromJson((body as Map).cast()).product('brownie'), isNull);
    });

    test('a product needs an existing category', () async {
      final (status, body) = await call(
        'POST',
        '/api/admin/products',
        body: {
          'name': {'it': 'Test'},
          'categoryId': 'nope',
          'priceCents': 100,
        },
        staff: true,
      );
      expect(status, 400);
      expect(body['error'], 'unknownCategory');
    });

    test('placeholder images are generated', () async {
      final res = await app.handler(
        Request(
          'GET',
          Uri.parse('http://localhost/media/placeholder/Logo.svg'),
        ),
      );
      expect(res.statusCode, 200);
      expect(await res.readAsString(), contains('<svg'));
    });
  });

  group('orders', () {
    test('prices come from the server menu, not the client', () async {
      final order = await placeOrder([
        {...burgerMeal(qty: 2), 'unitPriceCents': 1},
        {
          'productId': 'fries',
          'optionIds': ['sauce-mayo'],
        },
      ]);
      expect(order['totalCents'], 990 * 2 + 300 + 30);
      expect(order['number'], 1);
      final next = await placeOrder([burgerMeal()]);
      expect(next['number'], 2);
    });

    test('required option groups are enforced', () async {
      final (status, body) = await call(
        'POST',
        '/api/orders',
        body: {
          'serviceMode': 'eatIn',
          'lines': [
            {
              'productId': 'menu-classic',
              'optionIds': ['size-m'],
            },
          ],
        },
      );
      expect(status, 400);
      expect(body['error'], 'invalidOptions');
    });

    test('options of another product are rejected', () async {
      final (status, body) = await call(
        'POST',
        '/api/orders',
        body: {
          'serviceMode': 'eatIn',
          'lines': [
            {
              'productId': 'water',
              'optionIds': ['extra-bacon'],
            },
          ],
        },
      );
      expect(status, 400);
      expect(body['error'], 'invalidOptions');
    });

    test('sold out products cannot be ordered', () async {
      await call(
        'PATCH',
        '/api/kitchen/products/water',
        body: {'soldOut': true},
        staff: true,
      );
      final (status, body) = await call(
        'POST',
        '/api/orders',
        body: {
          'serviceMode': 'eatIn',
          'lines': [
            {'productId': 'water'},
          ],
        },
      );
      expect(status, 400);
      expect(body['error'], 'soldOut');
    });
  });

  group('flows', () {
    test('order only: ticket for the till, closed when paid', () async {
      await configure({'flow': FlowConfig.orderOnly.toJson()});
      final order = await placeOrder([burgerMeal()]);
      expect(order['paymentStatus'], 'awaitingCounter');
      expect(order['kitchenStatus'], 'none');

      final (_, jobs) = await call('GET', '/api/staff/print-jobs', staff: true);
      expect(jobs['jobs'], hasLength(1));
      expect(jobs['jobs'][0]['content'], contains('Paga in cassa'));

      final (s, paid) = await call(
        'POST',
        '/api/staff/orders/${order['id']}/mark-paid',
        staff: true,
      );
      expect(s, 200);
      expect(paid['status'], 'completed');
    });

    test('pay at counter, kitchen after payment, pickup when ready', () async {
      final order = await placeOrder([burgerMeal()]);
      final id = order['id'];
      var (_, queue) = await call('GET', '/api/kitchen/orders', staff: true);
      expect(queue['orders'], isEmpty);

      await call('POST', '/api/staff/orders/$id/mark-paid', staff: true);
      (_, queue) = await call('GET', '/api/kitchen/orders', staff: true);
      expect(queue['orders'], hasLength(1));

      final events = <String>[];
      final sub = app.bus.stream.listen((e) => events.add(e.type));
      await call(
        'POST',
        '/api/kitchen/orders/$id/status',
        body: {'status': 'ready'},
        staff: true,
      );
      final (_, done) = await call(
        'POST',
        '/api/kitchen/orders/$id/status',
        body: {'status': 'collected'},
        staff: true,
      );
      await sub.cancel();
      expect(events, contains(ServerEvent.pickupAnnounce));
      expect(done['status'], 'completed');
    });

    test('full service in demo mode: simulated payment and receipt', () async {
      await configure({
        'flow': FlowConfig.fullService.toJson(),
        'payment': {
          'type': 'demo',
          'options': {'delayMs': 0},
        },
      });
      final order = await placeOrder([burgerMeal()]);
      expect(order['paymentStatus'], 'awaitingKiosk');
      expect(order['isDemo'], isTrue);

      final (s, paid) = await call('POST', '/api/orders/${order['id']}/pay');
      expect(s, 200);
      expect(paid['paymentStatus'], 'paid');
      expect(paid['kitchenStatus'], 'queued');
      expect(paid['fiscalDocument']['number'], startsWith('DEMO-'));

      final (s2, _) = await call('POST', '/api/orders/${order['id']}/pay');
      expect(s2, 409, reason: 'no double charge');
    });

    test('the cashier enters and cashes an order at the till', () async {
      await configure({
        'flow': FlowConfig.fullService.toJson(),
        'payment': {
          'type': 'demo',
          'options': {'delayMs': 0},
        },
      });
      final (s, order) = await call(
        'POST',
        '/api/staff/orders',
        body: {
          'serviceMode': 'takeAway',
          'lines': [burgerMeal()],
          'payment': 'cash',
        },
        staff: true,
      );
      expect(s, 201, reason: '$order');
      expect(order['origin'], 'counter');
      expect(order['paymentMode'], 'counter');
      expect(order['paymentStatus'], 'paid');
      expect(order['payment']['provider'], 'cash');
      expect(order['kitchenStatus'], 'queued');
      expect(order['fiscalDocument']['number'], startsWith('DEMO-'));
      final (_, jobs) = await call(
        'GET',
        '/api/staff/print-jobs?orderId=${order['id']}',
        staff: true,
      );
      expect(jobs['jobs'], hasLength(1), reason: 'one paid ticket');
      expect(jobs['jobs'][0]['content'], isNot(contains('Paga in cassa')));

      final (s2, _) = await call(
        'POST',
        '/api/staff/orders',
        body: {
          'lines': [burgerMeal()],
        },
      );
      expect(s2, 401, reason: 'needs the staff PIN');
    });

    test('declined payment can fall back to the counter', () async {
      await configure({
        'flow': FlowConfig.fullService.toJson(),
        'payment': {
          'type': 'demo',
          'options': {'delayMs': 0, 'declineCentsSuffix': '90'},
        },
      });
      final order = await placeOrder([burgerMeal()]); // 9,90 -> declined
      final id = order['id'];
      final (_, failed) = await call('POST', '/api/orders/$id/pay');
      expect(failed['paymentStatus'], 'failed');

      final (s, switched) = await call(
        'POST',
        '/api/orders/$id/switch-to-counter',
      );
      expect(s, 200);
      expect(switched['paymentStatus'], 'awaitingCounter');

      final (_, paid) = await call(
        'POST',
        '/api/staff/orders/$id/mark-paid',
        body: {'issueFiscal': false},
        staff: true,
      );
      expect(paid['paymentStatus'], 'paid');
      expect(paid['fiscalDocument'], isNull);
      expect(paid['kitchenStatus'], 'queued');
    });

    test('no payment: straight to the kitchen', () async {
      await configure({
        'flow': {
          'paymentMode': 'none',
          'rules': {
            'submitted': ['sendToKitchenDisplay'],
          },
        },
      });
      final order = await placeOrder([burgerMeal()]);
      expect(order['paymentStatus'], 'notRequired');
      expect(order['kitchenStatus'], 'queued');
      final (s, _) = await call('POST', '/api/orders/${order['id']}/pay');
      expect(s, 409);
    });

    test('customer choice needs the choice', () async {
      await configure({
        'flow': {
          'paymentMode': 'customerChoice',
          'rules': {
            'submitted': ['printCustomerTicket'],
            'paid': ['sendToKitchenDisplay'],
          },
        },
      });
      final (status, body) = await call(
        'POST',
        '/api/orders',
        body: {
          'serviceMode': 'eatIn',
          'lines': [burgerMeal()],
        },
      );
      expect(status, 400);
      expect(body['error'], 'paymentChoiceRequired');
      final order = await placeOrder([burgerMeal()], paymentChoice: 'kiosk');
      expect(order['paymentStatus'], 'awaitingKiosk');
    });

    test(
      'a broken printer never blocks the order, and can be retried',
      () async {
        await configure({
          'customerPrinter': {'type': 'broken'},
        });
        final order = await placeOrder([burgerMeal()]);
        final history = (order['history'] as List).map((e) => e['type']);
        expect(history, contains('actionFailed'));

        await configure({
          'customerPrinter': {'type': 'demo'},
        });
        final (s, retried) = await call(
          'POST',
          '/api/staff/orders/${order['id']}/actions/printCustomerTicket',
          staff: true,
        );
        expect(s, 200);
        expect(
          (retried['history'] as List).last['detail'],
          'manual:printCustomerTicket',
        );
      },
    );

    test('invalid flows are refused', () async {
      final (status, body) = await call(
        'PUT',
        '/api/admin/settings',
        body: {
          'flow': {
            'paymentMode': 'counter',
            'rules': {
              'submitted': ['issueFiscalDocument'],
            },
          },
        },
        staff: true,
      );
      expect(status, 400);
      expect(body['error'], 'invalidSettings');
    });
  });

  group('stock', () {
    Future<void> trackWater(int qty) => call(
      'PUT',
      '/api/admin/products/water',
      body: {
        ...app.menu.fullMenu().product('water')!.toJson(),
        'trackStock': true,
        'stockQty': qty,
      },
      staff: true,
    );

    test('is enforced in production and restored on cancel', () async {
      await configure({
        'demoMode': false,
        'stockTracking': true,
        'flow': FlowConfig.orderOnly.toJson(),
      });
      await trackWater(2);
      final order = await placeOrder([
        {'productId': 'water', 'quantity': 2},
      ]);
      expect(app.menu.fullMenu().product('water')!.soldOut, isTrue);

      final (status, body) = await call(
        'POST',
        '/api/orders',
        body: {
          'serviceMode': 'eatIn',
          'lines': [
            {'productId': 'water'},
          ],
        },
      );
      expect(status, 400);
      expect(body['error'], 'soldOut');

      await call('POST', '/api/orders/${order['id']}/cancel');
      final water = app.menu.fullMenu().product('water')!;
      expect(water.stockQty, 2);
      expect(water.soldOut, isFalse);
    });

    test('is ignored in demo mode', () async {
      await configure({'stockTracking': true});
      await trackWater(0);
      await placeOrder([
        {'productId': 'water', 'quantity': 3},
      ]);
      expect(app.menu.fullMenu().product('water')!.stockQty, 0);
    });
  });

  group('security', () {
    test('staff endpoints need the PIN', () async {
      final (s1, _) = await call('GET', '/api/kitchen/orders');
      expect(s1, 401);
      final (s2, _) = await call('GET', '/api/admin/settings');
      expect(s2, 401);
      final (s3, body) = await call('GET', '/api/settings');
      expect(s3, 200);
      expect((body as Map).containsKey('adminPin'), isFalse);
    });

    test('the kiosk cannot cancel a paid order', () async {
      final order = await placeOrder([burgerMeal()]);
      await call(
        'POST',
        '/api/staff/orders/${order['id']}/mark-paid',
        staff: true,
      );
      final (s, body) = await call('POST', '/api/orders/${order['id']}/cancel');
      expect(s, 409);
      expect(body['error'], 'cannotCancel');
    });
  });

  test('ESC/POS encoding maps € and accented letters to PC858', () {
    final bytes = EscPosEncoder(42).encode(const Ticket([TicketText('è 1€')]));
    expect(bytes, containsAllInOrder([0x8a, 0x20, 0x31, 0xd5]));
  });

  group('staff screens', () {
    test('pickup board follows the kitchen', () async {
      final order = await placeOrder([burgerMeal()]);
      final id = order['id'];
      await call('POST', '/api/staff/orders/$id/mark-paid', staff: true);
      var (_, board) = await call('GET', '/api/pickup');
      expect(board, {
        'preparing': [order['number']],
        'ready': <int>[],
      });
      await call(
        'POST',
        '/api/kitchen/orders/$id/status',
        body: {'status': 'ready'},
        staff: true,
      );
      (_, board) = await call('GET', '/api/pickup');
      expect(board['ready'], [order['number']]);
    });

    test('day summary counts paid revenue and top products', () async {
      final a = await placeOrder([burgerMeal(qty: 2)]);
      final b = await placeOrder([burgerMeal()]);
      await call('POST', '/api/staff/orders/${a['id']}/mark-paid', staff: true);
      await call('POST', '/api/staff/orders/${b['id']}/cancel', staff: true);
      final (status, body) = await call(
        'GET',
        '/api/staff/summary',
        staff: true,
      );
      expect(status, 200);
      expect(body['orders'], 1);
      expect(body['cancelled'], 1);
      expect(body['revenueCents'], a['totalCents']);
      expect(body['topProducts'][0]['quantity'], 2);
    });

    test('till payments: change, mixed, and the cash/card split', () async {
      final a = await placeOrder([burgerMeal()]);
      final total = a['totalCents'] as int;
      var (s, body) = await call(
        'POST',
        '/api/staff/orders/${a['id']}/mark-paid',
        body: {'method': 'cash', 'receivedCents': total - 1},
        staff: true,
      );
      expect(s, 400);
      expect(body['error'], 'notEnoughCash');
      (s, body) = await call(
        'POST',
        '/api/staff/orders/${a['id']}/mark-paid',
        body: {'method': 'mixed', 'cashCents': 100, 'cardCents': 100},
        staff: true,
      );
      expect(body['error'], 'invalidSplit');
      (s, body) = await call(
        'POST',
        '/api/staff/orders/${a['id']}/mark-paid',
        body: {
          'method': 'mixed',
          'cashCents': 500,
          'cardCents': total - 500,
          'receivedCents': 1000,
        },
        staff: true,
      );
      expect(s, 200, reason: '$body');
      expect(body['payment']['cashCents'], 500);
      expect(body['payment']['receivedCents'], 1000);

      final (s2, b) = await call(
        'POST',
        '/api/staff/orders',
        body: {
          'lines': [burgerMeal()],
          'payment': 'cash',
          'receivedCents': 5000,
        },
        staff: true,
      );
      expect(s2, 201);
      expect(b['payment']['cashCents'], total);

      final (_, summary) = await call('GET', '/api/staff/summary', staff: true);
      expect(summary['cashCents'], 500 + total);
      expect(summary['cardCents'], total - 500);
    });

    test('items can be added to an unpaid order before the kitchen', () async {
      await configure({'flow': FlowConfig.orderOnly.toJson()});
      final a = await placeOrder([burgerMeal()]);
      final (s, edited) = await call(
        'PUT',
        '/api/staff/orders/${a['id']}/lines',
        body: {
          'serviceMode': 'takeAway',
          'lines': [
            burgerMeal(),
            {'productId': 'water'},
          ],
        },
        staff: true,
      );
      expect(s, 200, reason: '$edited');
      expect(edited['lines'], hasLength(2));
      expect(edited['serviceMode'], 'takeAway');
      expect(edited['totalCents'], greaterThan(a['totalCents'] as int));

      await call('POST', '/api/staff/orders/${a['id']}/mark-paid', staff: true);
      final (s2, _) = await call(
        'PUT',
        '/api/staff/orders/${a['id']}/lines',
        body: {
          'lines': [burgerMeal()],
        },
        staff: true,
      );
      expect(s2, 409, reason: 'paid orders are final');
    });

    test('photos are uploaded to the media folder', () async {
      final dir = Directory.systemTemp.createTempSync('media');
      addTearDown(() => dir.deleteSync(recursive: true));
      await app.close();
      app = KioskApp(AppDatabase.inMemory(), mediaDir: dir.path);
      final res = await app.handler(
        Request(
          'POST',
          Uri.parse('http://localhost/api/admin/media?name=My Burger.PNG'),
          body: [1, 2, 3],
          headers: {'x-staff-pin': pin},
        ),
      );
      expect(res.statusCode, 201);
      final url = jsonDecode(await res.readAsString())['url'] as String;
      expect(url, matches(RegExp(r'^/media/my-burger-[a-z0-9]+\.png$')));
      expect(File('${dir.path}/${url.substring(7)}').readAsBytesSync(), [
        1,
        2,
        3,
      ]);
      final bad = await app.handler(
        Request(
          'POST',
          Uri.parse('http://localhost/api/admin/media?name=virus.exe'),
          body: [1],
          headers: {'x-staff-pin': pin},
        ),
      );
      expect(bad.statusCode, 400);
    });
  });

  group('Epson RT fiscal printer', () {
    late HttpServer device;
    late List<String> received;
    var reply = '';

    setUp(() async {
      received = [];
      device = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      device.listen((req) async {
        received.add('${req.uri}\n${await utf8.decodeStream(req)}');
        req.response
          ..headers.contentType = ContentType('text', 'xml')
          ..write(reply)
          ..close();
      });
    });
    tearDown(() => device.close(force: true));

    Order paidOrder([PaymentInfo? payment]) => Order(
      id: 'o1',
      number: 7,
      createdAt: DateTime(2026, 10, 19),
      serviceMode: ServiceMode.eatIn,
      language: 'it',
      paymentMode: PaymentMode.kiosk,
      status: OrderStatus.open,
      paymentStatus: PaymentStatus.paid,
      kitchenStatus: KitchenStatus.none,
      payment:
          payment ?? PaymentInfo(provider: 'card', at: DateTime(2026, 10, 19)),
      lines: const [
        OrderLine(
          productId: 'b',
          name: LocalizedText({'it': 'Panino & patatine'}),
          quantity: 2,
          unitPriceCents: 650,
          vatRate: 10,
          options: [
            OrderLineOption(
              groupId: 'x',
              optionId: 'bacon',
              name: LocalizedText({'it': 'Bacon'}),
              priceDeltaCents: 100,
            ),
          ],
        ),
      ],
    );

    test('sends the sale and reads the receipt number', () async {
      reply =
          '<soapenv:Envelope><soapenv:Body><response success="true" '
          'code="" status="2"><addInfo><fiscalReceiptNumber>12'
          '</fiscalReceiptNumber><zRepNumber>41</zRepNumber></addInfo>'
          '</response></soapenv:Body></soapenv:Envelope>';
      final rt = EpsonFiscalPrinter.fromOptions({
        'host': '127.0.0.1',
        'port': device.port,
        'departments': {'10': 3},
      });
      final doc = await rt.issue(paidOrder());
      expect(doc.number, '0042-0012');
      final sent = received.single;
      expect(sent, contains('/cgi-bin/fpmate.cgi?devid=local_printer'));
      expect(
        sent,
        contains(
          'description="Panino &amp; patatine" quantity="2" '
          'unitPrice="6,50" department="3"',
        ),
      );
      expect(sent, contains('unitPrice="1,00"'));
      expect(sent, contains('payment="15,00" paymentType="2"'));
    });

    test('a mixed payment is sent as two totals', () async {
      reply = '<response success="true" code="" status="2"/>';
      final rt = EpsonFiscalPrinter(host: '127.0.0.1', port: device.port);
      await rt.issue(
        paidOrder(
          PaymentInfo(
            provider: 'mixed',
            at: DateTime(2026, 10, 19),
            cashCents: 500,
            cardCents: 1000,
            receivedCents: 2000,
          ),
        ),
      );
      final sent = received.single;
      expect(sent, contains('payment="20,00" paymentType="0" index="1"'));
      expect(sent, contains('payment="10,00" paymentType="2" index="2"'));
    });

    test('a refused receipt is an error', () async {
      reply = '<response success="false" code="EPTR_REC_EMPTY" status="0"/>';
      final rt = EpsonFiscalPrinter(host: '127.0.0.1', port: device.port);
      expect(
        rt.issue(paidOrder()),
        throwsA(
          isA<FiscalException>().having(
            (e) => e.message,
            'message',
            contains('EPTR_REC_EMPTY'),
          ),
        ),
      );
    });
  });
}
