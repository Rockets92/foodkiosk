import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kiosk_core/kiosk_core.dart';
import 'package:staff_app/src/api.dart';

LocalizedText tx(String it, [String? en]) =>
    LocalizedText({'it': it, 'en': ?en});

final demoMenu = Menu(
  categories: [
    Category(id: 'burger', name: tx('Panini', 'Burgers'), sortOrder: 0),
    Category(id: 'drinks', name: tx('Bibite', 'Drinks'), sortOrder: 1),
  ],
  modifierGroups: [
    ModifierGroup(
      id: 'extras',
      name: tx('Aggiunte', 'Extras'),
      maxSelect: 3,
      options: [
        ModifierOption(id: 'bacon', name: tx('Bacon'), priceDeltaCents: 100),
      ],
    ),
  ],
  products: [
    Product(
      id: 'burger',
      categoryId: 'burger',
      name: tx('Classic Burger'),
      priceCents: 650,
      allergens: const [Allergen.gluten],
      modifierGroupIds: const ['extras'],
    ),
    Product(
      id: 'cola',
      categoryId: 'drinks',
      name: tx('Cola'),
      priceCents: 280,
    ),
  ],
);

Order makeOrder(
  int number, {
  PaymentStatus payment = PaymentStatus.awaitingCounter,
  KitchenStatus kitchen = KitchenStatus.none,
  OrderStatus status = OrderStatus.open,
  List<OrderEvent> history = const [],
}) => Order(
  id: 'o$number',
  number: number,
  createdAt: DateTime.now().subtract(const Duration(minutes: 3)),
  serviceMode: ServiceMode.eatIn,
  language: 'it',
  paymentMode: PaymentMode.counter,
  status: status,
  paymentStatus: payment,
  kitchenStatus: kitchen,
  history: history,
  lines: [
    OrderLine(
      productId: 'burger',
      name: tx('Classic Burger'),
      quantity: 2,
      unitPriceCents: 650,
      vatRate: 10,
      allergens: const [Allergen.gluten],
      options: [
        OrderLineOption(
          groupId: 'extras',
          optionId: 'bacon',
          name: tx('Bacon'),
          priceDeltaCents: 100,
        ),
      ],
    ),
  ],
);

/// In-memory stand-in for the local server's staff endpoints.
class FakeServer {
  KioskSettings settings = const KioskSettings();
  Menu menu = demoMenu;
  List<Order> orders = [];
  final requests = <String>[];
  List<DiscountCode> discounts = [
    DiscountCode(
      id: 'd1',
      code: 'SCONTO10',
      type: DiscountType.percent,
      percent: 10,
      maxUses: 50,
      usedCount: 12,
      label: tx('Sconto 10%'),
    ),
    DiscountCode(
      id: 'd2',
      code: 'COLAGRATIS',
      type: DiscountType.freeProduct,
      productId: 'cola',
    ),
  ];

  /// Bodies of the orders entered at the till.
  final counterOrders = <Map<String, Object?>>[];

  /// Bodies of the payments taken on existing orders.
  final payments = <Map<String, Object?>>[];

  /// The Fisconline credentials as the staff app sent them.
  Map<String, Object?>? fiscalCredentials;

  Map<String, Object?> get fiscalStatus => {
    'device': settings.fiscal.type,
    'account': fiscalCredentials == null
        ? {'connected': false}
        : {
            'connected': true,
            'taxCode': 'RSS************U',
            'updatedAt': '2026-10-01T10:00:00Z',
            'passwordExpiresAt': '2026-12-30T10:00:00Z',
            'daysLeft': 68,
            'renewSoon': false,
            'expired': false,
          },
  };

  late final client = MockClient(_handle);

  StaffApi api(Uri server, String pin) => _FakeApi(server, pin, client);

  Future<http.Response> _handle(http.Request req) async {
    final path = req.url.path;
    requests.add('${req.method} $path');
    final pin = req.headers['x-staff-pin'];
    final public = path == '/api/pickup';
    if (!public && pin != settings.adminPin) {
      return _json({'error': 'unauthorized', 'message': 'PIN'}, 401);
    }
    final body = req.body.isEmpty
        ? const <String, Object?>{}
        : (jsonDecode(req.body) as Map).cast<String, Object?>();
    final segments = req.url.pathSegments;

    PaymentInfo payment(String method) => PaymentInfo(
      provider: method,
      at: DateTime.now(),
      cashCents: body['cashCents'] as int?,
      cardCents: body['cardCents'] as int?,
      receivedCents: body['receivedCents'] as int?,
    );

    List<OrderLine> price(OrderRequest request) => [
      for (final l in request.lines)
        OrderLine(
          productId: l.productId,
          name: menu.product(l.productId)!.name,
          quantity: l.quantity,
          unitPriceCents: menu.product(l.productId)!.priceCents,
          vatRate: 10,
          options: [
            for (final id in l.optionIds)
              OrderLineOption(
                groupId: 'extras',
                optionId: id,
                name: tx(id),
                priceDeltaCents: 100,
              ),
          ],
        ),
    ];

    Order update(String id, Order Function(Order) f) {
      final i = orders.indexWhere((o) => o.id == id);
      return orders[i] = f(orders[i]);
    }

    switch ((req.method, path)) {
      case ('GET', '/api/admin/settings'):
        return _json(settings.toJson());
      case ('PUT', '/api/admin/settings'):
        settings = KioskSettings.fromJson({...settings.toJson(), ...body});
        return _json(settings.toJson());
      case ('GET', '/api/admin/menu'):
        return _json(menu.toJson());
      case ('GET', '/api/admin/flow/presets'):
        return _json({
          for (final e in FlowConfig.presets.entries) e.key: e.value.toJson(),
        });
      case ('POST', '/api/admin/flow/validate'):
        final flow = FlowConfig.fromJson(body);
        return _json({
          'valid': flow.isValid,
          'issues': [for (final i in flow.validate()) i.toJson()],
        });
      case ('GET', '/api/admin/network'):
        return _json({
          'hostname': 'CASSA-PC',
          'addresses': ['192.168.1.20'],
          'devices': [
            {
              'kind': 'totem',
              'address': '192.168.1.31',
              'since': DateTime.now().toUtc().toIso8601String(),
            },
          ],
        });
      case ('GET', '/api/admin/adapters'):
        return _json({
          'payment': ['none', 'demo'],
          'fiscal': ['none', 'demo', 'epsonRt', 'adeOnline'],
          'dcOnline': ['sandbox'],
          'printer': ['none', 'demo', 'escposNetwork', 'kiosk'],
        });
      case ('GET', '/api/admin/fiscal/account'):
        return _json(fiscalStatus);
      case ('PUT', '/api/admin/fiscal/account'):
        if ('${body['pin']}'.length != 10) {
          return _json({'error': 'invalidPin', 'message': 'PIN'}, 400);
        }
        fiscalCredentials = body;
        return _json(fiscalStatus);
      case ('DELETE', '/api/admin/fiscal/account'):
        fiscalCredentials = null;
        return _json(fiscalStatus);
      case ('POST', '/api/admin/fiscal/check'):
        return _json({
          'ok': fiscalCredentials != null,
          'message': 'Ambiente di prova: credenziali corrette',
          ...fiscalStatus,
        });
      case ('GET', '/api/staff/orders'):
        return _json({
          'orders': [for (final o in orders) o.toJson()],
        });
      case ('GET', '/api/admin/discounts'):
        return _json({
          'codes': [for (final c in discounts) c.toJson()],
        });
      case ('POST', '/api/admin/discounts'):
        final c = DiscountCode.fromJson({
          ...body,
          'id': 'd${discounts.length + 1}',
        });
        discounts = [c, ...discounts];
        return _json(c.toJson(), 201);
      case ('POST', '/api/staff/discounts/check'):
        final code = DiscountCode.normalize(body['code'] as String);
        final found = discounts.where((c) => c.code == code).firstOrNull;
        return found == null
            ? _json({
                'error': 'codeNotFound',
                'message': 'Codice inesistente',
              }, 404)
            : _json(found.toPublicJson());
      case ('POST', '/api/staff/orders'):
        counterOrders.add(body);
        final request = OrderRequest.fromJson(body);
        final lines = price(request);
        final method = body['payment'] as String?;
        final code = discounts
            .where((c) => c.code == request.discountCode)
            .firstOrNull;
        final order = Order(
          id: 'o${orders.length + 100}',
          number: orders.length + 100,
          createdAt: DateTime.now(),
          serviceMode: request.serviceMode,
          language: 'it',
          lines: lines,
          paymentMode: PaymentMode.counter,
          origin: OrderOrigin.counter,
          paymentStatus: method == null
              ? PaymentStatus.awaitingCounter
              : PaymentStatus.paid,
          payment: method == null ? null : payment(method),
          discount: code == null
              ? null
              : OrderDiscount.of(
                  code,
                  code.evaluate(lines.map((l) => l.discountable)).amountCents,
                ),
        );
        orders.add(order);
        return _json(order.toJson(), 201);
      case ('GET', '/api/kitchen/orders'):
        return _json({
          'orders': [
            for (final o in orders)
              if (o.status == OrderStatus.open &&
                  o.kitchenStatus != KitchenStatus.none &&
                  o.kitchenStatus != KitchenStatus.collected)
                o.toJson(),
          ],
        });
      case ('GET', '/api/pickup'):
        return _json({
          'preparing': [
            for (final o in orders)
              if (o.kitchenStatus == KitchenStatus.queued ||
                  o.kitchenStatus == KitchenStatus.preparing)
                o.number,
          ],
          'ready': [
            for (final o in orders)
              if (o.kitchenStatus == KitchenStatus.ready) o.number,
          ],
        });
      case ('GET', '/api/staff/summary'):
        return _json({
          'day': '2026-10-19',
          'orders': orders.length,
          'cancelled': 0,
          'demoOrders': 0,
          'paidOrders': 0,
          'revenueCents': 0,
          'averageCents': 0,
          'awaitingCounter': 0,
          'eatIn': orders.length,
          'takeAway': 0,
          'byHour': List.filled(24, 0),
          'topProducts': <Object>[],
        });
    }
    if (req.method == 'POST' &&
        segments.length == 5 &&
        segments[1] == 'kitchen') {
      final status = KitchenStatus.parse(body['status'] as String);
      return _json(
        update(segments[3], (o) => o.copyWith(kitchenStatus: status)).toJson(),
      );
    }
    if (req.method == 'PUT' && path.endsWith('/lines')) {
      final request = OrderRequest.fromJson(body);
      return _json(
        update(
          segments[3],
          (o) => o.copyWith(
            lines: price(request),
            serviceMode: request.serviceMode,
          ),
        ).toJson(),
      );
    }
    if (req.method == 'POST' && path.endsWith('/mark-paid')) {
      payments.add(body);
      return _json(
        update(
          segments[3],
          (o) => o
              .copyWith(
                paymentStatus: PaymentStatus.paid,
                payment: payment(body['method'] as String),
              )
              .withEvent('paid', detail: body['method'] as String),
        ).toJson(),
      );
    }
    if (req.method == 'POST' && path.endsWith('/cancel')) {
      return _json(
        update(
          segments[3],
          (o) => o.copyWith(status: OrderStatus.cancelled),
        ).toJson(),
      );
    }
    if (req.method == 'POST' &&
        segments.length == 6 &&
        segments[4] == 'actions') {
      return _json(
        update(
          segments[3],
          (o) => o.withEvent('action', detail: segments[5]),
        ).toJson(),
      );
    }
    if (req.method == 'PUT' && segments[2] == 'discounts') {
      final c = DiscountCode.fromJson(body);
      discounts = [for (final x in discounts) x.id == c.id ? c : x];
      return _json(c.toJson());
    }
    if (req.method == 'PATCH' && segments[2] == 'products') {
      final p = menu.product(segments[3])!;
      final next = p.copyWith(
        soldOut: body['soldOut'] as bool?,
        enabled: body['enabled'] as bool?,
      );
      menu = Menu(
        categories: menu.categories,
        modifierGroups: menu.modifierGroups,
        products: [for (final x in menu.products) x.id == p.id ? next : x],
      );
      return _json(next.toJson());
    }
    return _json({'error': 'notFound', 'message': path}, 404);
  }

  http.Response _json(Object body, [int status = 200]) => http.Response(
    jsonEncode(body),
    status,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );
}

/// No WebSocket in tests: screens fall back to their timers.
class _FakeApi extends StaffApi {
  _FakeApi(super.baseUri, super.pin, http.Client client)
    : super(client: client);

  @override
  Stream<ServerEvent> events() => const Stream.empty();

  /// No network images in widget tests.
  @override
  String? imageUrl(String? path) => null;
}
