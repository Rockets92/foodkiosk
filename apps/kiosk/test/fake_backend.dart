import 'dart:async';
import 'dart:typed_data';

import 'package:kiosk_app/src/api/kiosk_backend.dart';
import 'package:kiosk_core/kiosk_core.dart';

LocalizedText tx(String it, String en) => LocalizedText({'it': it, 'en': en});

final testMenu = Menu(
  categories: [
    Category(id: 'burger', name: tx('Panini', 'Burgers'), sortOrder: 0),
    Category(id: 'drinks', name: tx('Bibite', 'Drinks'), sortOrder: 1),
  ],
  modifierGroups: [
    ModifierGroup(
      id: 'size',
      name: tx('Formato', 'Size'),
      minSelect: 1,
      maxSelect: 1,
      options: [
        ModifierOption(
          id: 'm',
          name: tx('Medio', 'Medium'),
          selectedByDefault: true,
        ),
        ModifierOption(
          id: 'l',
          name: tx('Grande', 'Large'),
          priceDeltaCents: 80,
        ),
      ],
    ),
    ModifierGroup(
      id: 'side',
      name: tx('Contorno', 'Side'),
      minSelect: 1,
      maxSelect: 1,
      options: [
        ModifierOption(id: 'fries', name: tx('Patatine', 'Fries')),
        ModifierOption(id: 'salad', name: tx('Insalata', 'Salad')),
      ],
    ),
    ModifierGroup(
      id: 'extras',
      name: tx('Aggiunte', 'Extras'),
      maxSelect: 0,
      options: [
        ModifierOption(
          id: 'bacon',
          name: tx('Bacon', 'Bacon'),
          priceDeltaCents: 100,
        ),
        ModifierOption(
          id: 'cheese',
          name: tx('Formaggio', 'Cheese'),
          priceDeltaCents: 50,
          allergens: [Allergen.milk],
        ),
      ],
    ),
  ],
  products: [
    Product(
      id: 'burger',
      categoryId: 'burger',
      name: tx('Classic Burger', 'Classic Burger'),
      priceCents: 650,
      allergens: [Allergen.gluten],
      kcal: 600,
      modifierGroupIds: ['extras'],
    ),
    Product(
      id: 'meal',
      categoryId: 'burger',
      name: tx('Menu Burger', 'Burger Meal'),
      priceCents: 990,
      modifierGroupIds: ['size', 'side'],
    ),
    Product(
      id: 'cola',
      categoryId: 'drinks',
      name: tx('Cola', 'Cola'),
      priceCents: 280,
    ),
    Product(
      id: 'water',
      categoryId: 'drinks',
      name: tx('Acqua', 'Water'),
      priceCents: 150,
      soldOut: true,
    ),
  ],
);

final testDiscounts = [
  DiscountCode(
    id: 'd1',
    code: 'SCONTO10',
    type: DiscountType.percent,
    percent: 10,
    label: tx('Sconto 10%', '10% off'),
  ),
  DiscountCode(
    id: 'd2',
    code: 'COLAGRATIS',
    type: DiscountType.freeProduct,
    productId: 'cola',
  ),
  DiscountCode(
    id: 'd3',
    code: 'MENO5',
    type: DiscountType.amount,
    amountCents: 500,
    minOrderCents: 2000,
  ),
];

/// In-memory server used by the widget tests.
class FakeBackend extends KioskBackend {
  KioskSettings settingsValue;
  Menu menuValue;

  /// Result of the next kiosk payments, in order; approve when empty.
  final List<bool> paymentResults = [];
  final List<OrderRequest> requests = [];
  final List<String> cancelled = [];

  /// Tickets the fake server leaves for the totem's printer with each
  /// order it creates or gets paid.
  List<Uint8List> receiptsPerReply = const [];
  final _receipts = <String, List<Uint8List>>{};

  Order _withReceipts(Order order) {
    (_receipts[order.id] ??= []).addAll(receiptsPerReply);
    return order;
  }

  @override
  List<Uint8List> takeReceipts(String orderId) =>
      _receipts.remove(orderId) ?? const [];

  /// Codes the fake server knows.
  final Map<String, DiscountCode> discounts = {
    for (final c in testDiscounts) c.code: c,
  };
  final _orders = <String, Order>{};
  int _number = 0;

  FakeBackend({KioskSettings? settings, Menu? menu})
    : settingsValue = settings ?? const KioskSettings(),
      menuValue = menu ?? testMenu;

  @override
  Uri get baseUri => Uri.parse('http://fake/');

  @override
  String? imageUrl(String? path) => null;

  @override
  Future<KioskSettings> settings() async => settingsValue;

  @override
  Future<Menu> menu() async => menuValue;

  @override
  Future<Order> createOrder(OrderRequest request) async {
    requests.add(request);
    final mode = settingsValue.flow.paymentMode == PaymentMode.customerChoice
        ? request.paymentChoice!
        : settingsValue.flow.paymentMode;
    final lines = [
      for (final l in request.lines)
        () {
          final p = menuValue.product(l.productId)!;
          return OrderLine(
            productId: p.id,
            name: p.name,
            quantity: l.quantity,
            unitPriceCents: p.priceCents,
            options: [
              for (final gid in p.modifierGroupIds)
                for (final o in menuValue.modifierGroup(gid)!.options)
                  if (l.optionIds.contains(o.id))
                    OrderLineOption(
                      groupId: gid,
                      optionId: o.id,
                      name: o.name,
                      priceDeltaCents: o.priceDeltaCents,
                    ),
            ],
          );
        }(),
    ];
    final order = Order(
      id: 'o${++_number}',
      number: _number,
      createdAt: DateTime(2026),
      serviceMode: request.serviceMode,
      language: request.language,
      lines: lines,
      paymentMode: mode,
      paymentStatus: switch (mode) {
        PaymentMode.kiosk => PaymentStatus.awaitingKiosk,
        PaymentMode.counter => PaymentStatus.awaitingCounter,
        _ => PaymentStatus.notRequired,
      },
      isDemo: settingsValue.demoMode,
      discount: switch (discounts[request.discountCode]) {
        final c? => OrderDiscount.of(
          c,
          c.evaluate(lines.map((l) => l.discountable)).amountCents,
        ),
        null => null,
      },
    );
    return _withReceipts(_orders[order.id] = order);
  }

  @override
  Future<Order> order(String id) async => _orders[id]!;

  @override
  Future<Order> pay(String orderId) async {
    final ok = paymentResults.isEmpty ? true : paymentResults.removeAt(0);
    return _withReceipts(
      _orders[orderId] = _orders[orderId]!.copyWith(
        paymentStatus: ok ? PaymentStatus.paid : PaymentStatus.failed,
      ),
    );
  }

  @override
  Future<Order> switchToCounter(String orderId) async =>
      _orders[orderId] = _orders[orderId]!.copyWith(
        paymentMode: PaymentMode.counter,
        paymentStatus: PaymentStatus.awaitingCounter,
      );

  @override
  Future<Order> cancel(String orderId) async {
    cancelled.add(orderId);
    return _orders[orderId] = _orders[orderId]!.copyWith(
      status: OrderStatus.cancelled,
    );
  }

  @override
  Future<DiscountCode> checkDiscount(String code) async =>
      discounts[code] ??
      (throw BackendException(404, 'codeNotFound', 'Unknown code'));

  @override
  Future<bool> verifyStaffPin(String pin) async => pin == '1234';

  @override
  Stream<ServerEvent> events() => const Stream.empty();
}
