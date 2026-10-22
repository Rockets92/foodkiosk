import 'dart:math';

import 'package:kiosk_core/kiosk_core.dart';

/// Sends one request to the server and returns status and decoded body.
typedef Send =
    Future<(int, Object?)> Function(String method, String path, Object? body);

/// What one simulated customer did.
class SimulatedOrder {
  final Order order;

  /// How the customer paid, in words for the console.
  final String outcome;

  const SimulatedOrder(this.order, this.outcome);
}

/// Simulated customers ordering on a totem, through the same public API
/// the kiosk app uses: for testing the cashier, kitchen and pickup screens
/// with a steady flow of orders and no one at the totem.
class CustomerSimulator {
  final Send send;
  final Random random;

  CustomerSimulator(this.send, {Random? random}) : random = random ?? Random();

  /// Reads menu and settings (staff may change them meanwhile), places a
  /// random order and, when the flow wants it, pays it on the "totem".
  Future<SimulatedOrder> placeOne() async {
    final settings = KioskSettings.fromJson(_map(await _get('/api/settings')));
    final menu = Menu.fromJson(_map(await _get('/api/menu')));
    final request = randomOrder(menu, settings);
    var order = Order.fromJson(
      _map(await _expect(201, 'POST', '/api/orders', request.toJson())),
    );
    if (order.paymentStatus != PaymentStatus.awaitingKiosk) {
      return SimulatedOrder(order, switch (order.paymentStatus) {
        PaymentStatus.awaitingCounter => 'paga in cassa',
        _ => 'senza pagamento',
      });
    }
    final (status, body) = await send(
      'POST',
      '/api/orders/${order.id}/pay',
      null,
    );
    if (status == 200) order = Order.fromJson(_map(body));
    if (order.paymentStatus == PaymentStatus.paid) {
      return SimulatedOrder(order, 'pagato al totem');
    }
    // Payment refused: like a customer, fall back to the till if allowed.
    final (s2, b2) = await send(
      'POST',
      '/api/orders/${order.id}/switch-to-counter',
      null,
    );
    if (s2 == 200) {
      return SimulatedOrder(
        Order.fromJson(_map(b2)),
        'pagamento rifiutato, paga in cassa',
      );
    }
    return SimulatedOrder(order, 'pagamento non riuscito');
  }

  /// One to four products the kiosk would offer, with valid options.
  OrderRequest randomOrder(Menu menu, KioskSettings settings) {
    final modes = settings.serviceModes.isEmpty
        ? ServiceMode.values
        : settings.serviceModes.toList();
    final mode = modes[random.nextInt(modes.length)];
    final visible = {
      for (final c in menu.categories)
        if (c.enabled && c.visibleFor(mode)) c.id,
    };
    final products = [
      for (final p in menu.products)
        if (p.enabled && !p.soldOut && visible.contains(p.categoryId)) p,
    ];
    if (products.isEmpty) {
      throw StateError('Nessun prodotto disponibile nel menu.');
    }
    final lines = <OrderRequestLine>[];
    final count = 1 + random.nextInt(4);
    for (var i = 0; i < count; i++) {
      final product = products[random.nextInt(products.length)];
      lines.add(
        OrderRequestLine(
          productId: product.id,
          quantity: random.nextInt(5) == 0 ? 2 : 1,
          optionIds: [
            for (final gid in product.modifierGroupIds)
              ..._pickOptions(menu.modifierGroup(gid)),
          ],
        ),
      );
    }
    final payment = settings.flow.paymentMode == PaymentMode.customerChoice
        ? (random.nextBool() ? PaymentMode.kiosk : PaymentMode.counter)
        : null;
    return OrderRequest(
      serviceMode: mode,
      language: random.nextInt(6) == 0 ? 'en' : 'it',
      lines: lines,
      paymentChoice: payment,
    );
  }

  List<String> _pickOptions(ModifierGroup? group) {
    if (group == null) return const [];
    final options = [
      for (final o in group.options)
        if (o.enabled) o,
    ]..shuffle(random);
    final max = group.maxSelect == 0
        ? options.length
        : min(group.maxSelect, options.length);
    final low = min(group.minSelect, max);
    // Mostly the minimum, sometimes one extra (an add-on, a sauce).
    final n = low < max && random.nextInt(3) == 0 ? low + 1 : low;
    return [for (final o in options.take(n)) o.id];
  }

  Future<Object?> _get(String path) => _expect(200, 'GET', path, null);

  Future<Object?> _expect(
    int expected,
    String method,
    String path,
    Object? body,
  ) async {
    final (status, json) = await send(method, path, body);
    if (status != expected) {
      final message = json is Map ? json['message'] ?? json['error'] : json;
      throw StateError('$method $path: $status $message');
    }
    return json;
  }

  static Map<String, Object?> _map(Object? json) =>
      (json as Map).cast<String, Object?>();
}
