import 'package:kiosk_core/kiosk_core.dart';

import 'adapters/printer.dart';
import 'database.dart';
import 'errors.dart';
import 'event_bus.dart';
import 'ids.dart';
import 'repositories.dart';
import 'settings_service.dart';
import 'tickets.dart';

/// Creates orders and moves them through their lifecycle, running the
/// actions the [FlowConfig] attaches to each [FlowEvent].
///
/// A failing action (printer offline, fiscal device error) never blocks
/// the order: it is recorded in the order history, and staff can run it
/// again with [runAction].
class OrderService {
  final AppDatabase _db;
  final MenuRepository _menu;
  final OrderRepository _orders;
  final PrintJobRepository _printJobs;
  final SettingsService _settings;
  final EventBus _bus;
  final DateTime Function() _clock;

  /// Orders with a kiosk payment in flight, to refuse double charges.
  final _charging = <String>{};

  OrderService(
    this._db,
    this._menu,
    this._orders,
    this._printJobs,
    this._settings,
    this._bus, {
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  KioskSettings get _s => _settings.current;

  List<Order> query({
    String? businessDay,
    int? number,
    OrderStatus? status,
    PaymentStatus? paymentStatus,
  }) => _orders.query(
    businessDay: businessDay,
    number: number,
    status: status,
    paymentStatus: paymentStatus,
  );

  Order get(String id) =>
      _orders.byId(id) ?? (throw ApiException.notFound('Order'));

  // ---------------------------------------------------------------------
  // Creation

  Future<Order> create(OrderRequest req) async {
    final s = _s;
    if (req.lines.isEmpty) {
      throw ApiException.badRequest('emptyOrder', 'The order has no items.');
    }
    if (!s.serviceModes.contains(req.serviceMode)) {
      throw ApiException.badRequest(
        'serviceModeDisabled',
        'Service mode "${req.serviceMode.name}" is not enabled.',
      );
    }
    final language = s.languages.contains(req.language)
        ? req.language
        : s.defaultLanguage;

    final paymentMode = switch (s.flow.paymentMode) {
      PaymentMode.customerChoice => switch (req.paymentChoice) {
        PaymentMode.kiosk => PaymentMode.kiosk,
        PaymentMode.counter => PaymentMode.counter,
        _ => throw ApiException.badRequest(
          'paymentChoiceRequired',
          'Choose whether to pay on the kiosk or at the counter.',
        ),
      },
      final mode => mode,
    };

    final menu = _menu.loadForKiosk();
    final lines = [
      for (final l in req.lines) _priceLine(menu, l, req.serviceMode),
    ];

    final order = _db.transaction(() {
      final now = _clock();
      if (s.enforcesStock) _takeStock(lines);
      final order = Order(
        id: newId(),
        number: _orders.nextNumber(now),
        createdAt: now,
        serviceMode: req.serviceMode,
        language: language,
        lines: lines,
        paymentMode: paymentMode,
        paymentStatus: switch (paymentMode) {
          PaymentMode.kiosk => PaymentStatus.awaitingKiosk,
          PaymentMode.counter => PaymentStatus.awaitingCounter,
          _ => PaymentStatus.notRequired,
        },
        isDemo: s.demoMode,
      ).withEvent('created', at: now);
      _orders.insert(order);
      return order;
    });
    _bus.emit(ServerEvent.orderCreated, order.toJson());
    return _complete(await _runEvent(order, FlowEvent.submitted));
  }

  OrderLine _priceLine(Menu menu, OrderRequestLine req, ServiceMode mode) {
    final product = menu.product(req.productId);
    if (product == null) {
      throw ApiException.badRequest(
        'productUnavailable',
        'Product "${req.productId}" is not available.',
        {'productId': req.productId},
      );
    }
    final category = menu.categories
        .where((c) => c.id == product.categoryId)
        .firstOrNull;
    if (category == null || !category.visibleFor(mode)) {
      throw ApiException.badRequest(
        'productUnavailable',
        'Product "${product.id}" is not available for this service mode.',
        {'productId': product.id},
      );
    }
    if (product.soldOut) {
      throw ApiException.badRequest(
        'soldOut',
        '"${product.name.resolve('it')}" is sold out.',
        {'productId': product.id},
      );
    }
    if (req.quantity < 1 || req.quantity > _s.maxQuantityPerLine) {
      throw ApiException.badRequest(
        'invalidQuantity',
        'Quantity must be between 1 and ${_s.maxQuantityPerLine}.',
      );
    }

    final chosen = <OrderLineOption>[];
    final remaining = req.optionIds.toSet();
    if (remaining.length != req.optionIds.length) {
      throw ApiException.badRequest(
        'duplicateOption',
        'An option is repeated.',
      );
    }
    for (final gid in product.modifierGroupIds) {
      final group = menu.modifierGroup(gid);
      if (group == null) continue;
      final picked = [
        for (final o in group.options)
          if (remaining.remove(o.id)) o,
      ];
      if (picked.length < group.minSelect ||
          (group.maxSelect > 0 && picked.length > group.maxSelect)) {
        throw ApiException.badRequest(
          'invalidOptions',
          'Choose between ${group.minSelect} and '
              '${group.maxSelect == 0 ? 'any number of' : group.maxSelect} '
              'options for "${group.name.resolve('it')}".',
          {'productId': product.id, 'groupId': group.id},
        );
      }
      for (final o in picked) {
        chosen.add(
          OrderLineOption(
            groupId: group.id,
            optionId: o.id,
            name: o.name,
            priceDeltaCents: o.priceDeltaCents,
          ),
        );
      }
    }
    if (remaining.isNotEmpty) {
      throw ApiException.badRequest(
        'invalidOptions',
        'Options ${remaining.join(', ')} do not belong to this product.',
        {'productId': product.id},
      );
    }
    final note = req.note?.trim();
    return OrderLine(
      productId: product.id,
      name: product.name,
      quantity: req.quantity,
      unitPriceCents: product.priceCents,
      vatRate: product.vatRate,
      options: chosen,
      allergens: menu.allergensFor(product, chosen.map((o) => o.optionId)),
      note: note == null || note.isEmpty
          ? null
          : note.substring(0, note.length.clamp(0, 140)),
    );
  }

  void _takeStock(List<OrderLine> lines) {
    final needed = <String, int>{};
    for (final l in lines) {
      needed[l.productId] = (needed[l.productId] ?? 0) + l.quantity;
    }
    for (final e in needed.entries) {
      final p = _menu.product(e.key)!;
      if (!p.trackStock) continue;
      if (p.stockQty < e.value) {
        throw ApiException.badRequest(
          'insufficientStock',
          'Only ${p.stockQty} left of "${p.name.resolve('it')}".',
          {'productId': p.id, 'available': p.stockQty},
        );
      }
      final left = p.stockQty - e.value;
      _menu.upsertProduct(p.copyWith(stockQty: left, soldOut: left == 0));
    }
    _bus.emit(ServerEvent.menuUpdated);
  }

  void _returnStock(Order order) {
    if (order.isDemo || !_s.stockTracking) return;
    for (final l in order.lines) {
      final p = _menu.product(l.productId);
      if (p == null || !p.trackStock) continue;
      _menu.upsertProduct(
        p.copyWith(stockQty: p.stockQty + l.quantity, soldOut: false),
      );
    }
    _bus.emit(ServerEvent.menuUpdated);
  }

  // ---------------------------------------------------------------------
  // Payment

  /// Charges the order on the card terminal (simulated in demo mode).
  Future<Order> payOnKiosk(String id) async {
    var order = get(id);
    if (order.status != OrderStatus.open) {
      throw ApiException.conflict('orderClosed', 'The order is closed.');
    }
    if (order.paymentStatus != PaymentStatus.awaitingKiosk &&
        order.paymentStatus != PaymentStatus.failed) {
      throw ApiException.conflict(
        'notPayableOnKiosk',
        'The order cannot be paid on the kiosk (${order.paymentStatus.name}).',
      );
    }
    if (!_charging.add(id)) {
      throw ApiException.conflict('paymentInProgress', 'Payment in progress.');
    }
    try {
      order = _save(
        order
            .copyWith(paymentStatus: PaymentStatus.processing)
            .withEvent('paymentStarted', detail: _settings.payment.type),
      );
      final result = await _settings.payment.charge(
        orderId: order.id,
        amountCents: order.totalCents,
        reference: 'ORD-${order.displayNumber}',
      );
      if (!result.approved) {
        return _save(
          order
              .copyWith(
                paymentStatus: PaymentStatus.failed,
                payment: result.info,
              )
              .withEvent('paymentFailed', detail: result.info.message),
        );
      }
      order = _save(
        order
            .copyWith(paymentStatus: PaymentStatus.paid, payment: result.info)
            .withEvent('paid', detail: result.info.provider),
      );
    } catch (e) {
      return _save(
        order
            .copyWith(paymentStatus: PaymentStatus.failed)
            .withEvent('paymentFailed', detail: '$e'),
      );
    } finally {
      _charging.remove(id);
    }
    return _complete(await _runEvent(order, FlowEvent.paid));
  }

  /// After a failed kiosk payment, the customer decides to pay at the till.
  Future<Order> switchToCounter(String id) async {
    var order = get(id);
    if (!_s.counterFallback && !_s.flow.canPayAtCounter) {
      throw ApiException.conflict(
        'counterDisabled',
        'Paying at the counter is not enabled.',
      );
    }
    if (order.status != OrderStatus.open ||
        (order.paymentStatus != PaymentStatus.awaitingKiosk &&
            order.paymentStatus != PaymentStatus.failed)) {
      throw ApiException.conflict(
        'cannotSwitch',
        'The payment method of this order can no longer be changed.',
      );
    }
    order = _save(
      order
          .copyWith(
            paymentMode: PaymentMode.counter,
            paymentStatus: PaymentStatus.awaitingCounter,
          )
          .withEvent('switchedToCounter'),
    );
    // The customer needs something to show at the till.
    if (_settings.customerPrinter.type != 'none') {
      order = await _execute(order, FlowAction.printCustomerTicket);
    }
    return order;
  }

  /// Staff confirms the payment taken at the till.
  ///
  /// [issueFiscal] = false skips the fiscal document when the cashier's own
  /// register already issued it.
  Future<Order> markPaid(
    String id, {
    String method = 'counter',
    bool issueFiscal = true,
  }) async {
    var order = get(id);
    if (order.status != OrderStatus.open) {
      throw ApiException.conflict('orderClosed', 'The order is closed.');
    }
    if (order.paymentStatus == PaymentStatus.paid ||
        order.paymentStatus == PaymentStatus.processing ||
        order.paymentStatus == PaymentStatus.notRequired) {
      throw ApiException.conflict(
        'notAwaitingPayment',
        'The order is not awaiting payment (${order.paymentStatus.name}).',
      );
    }
    order = _save(
      order
          .copyWith(
            paymentStatus: PaymentStatus.paid,
            payment: PaymentInfo(provider: method, at: _clock()),
          )
          .withEvent('paid', detail: method),
    );
    return _complete(
      await _runEvent(
        order,
        FlowEvent.paid,
        skip: {if (!issueFiscal) FlowAction.issueFiscalDocument},
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Kitchen

  List<Order> kitchenQueue() => _orders
      .query(
        status: OrderStatus.open,
        kitchenStatuses: const [
          KitchenStatus.queued,
          KitchenStatus.preparing,
          KitchenStatus.ready,
        ],
      )
      .reversed
      .toList();

  Future<Order> setKitchenStatus(String id, KitchenStatus status) async {
    var order = get(id);
    if (order.status != OrderStatus.open) {
      throw ApiException.conflict('orderClosed', 'The order is closed.');
    }
    if (order.kitchenStatus == KitchenStatus.none ||
        status == KitchenStatus.none) {
      throw ApiException.conflict(
        'notInKitchen',
        'The order has not been sent to the kitchen.',
      );
    }
    if (order.kitchenStatus == status) return order;
    order = _save(
      order.copyWith(kitchenStatus: status).withEvent('kitchen.${status.name}'),
    );
    if (status == KitchenStatus.ready) {
      order = await _runEvent(order, FlowEvent.ready);
    }
    return _complete(order);
  }

  /// Order numbers for the pickup screen: in preparation and ready.
  Map<String, List<int>> pickupBoard() {
    final today = OrderRepository.businessDay(_clock());
    final open = _orders.query(businessDay: today, status: OrderStatus.open);
    List<int> numbers(Set<KitchenStatus> statuses) => [
      for (final o in open.reversed)
        if (statuses.contains(o.kitchenStatus)) o.number,
    ];
    return {
      'preparing': numbers({KitchenStatus.queued, KitchenStatus.preparing}),
      'ready': numbers({KitchenStatus.ready}),
    };
  }

  /// Day totals for the admin panel. Cancelled orders only count in
  /// `cancelled`; revenue counts paid orders.
  Map<String, Object?> summary(String businessDay) {
    final all = _orders.query(businessDay: businessDay, limit: 100000);
    final valid = all.where((o) => o.status != OrderStatus.cancelled);
    final paid = valid.where((o) => o.paymentStatus == PaymentStatus.paid);
    final revenue = paid.fold(0, (s, o) => s + o.totalCents);
    final products = <String, ({String name, int qty, int cents})>{};
    final byHour = List.filled(24, 0);
    for (final o in valid) {
      byHour[o.createdAt.toLocal().hour]++;
      for (final l in o.lines) {
        final prev = products[l.productId];
        products[l.productId] = (
          name: l.name.resolve('it'),
          qty: (prev?.qty ?? 0) + l.quantity,
          cents: (prev?.cents ?? 0) + l.totalCents,
        );
      }
    }
    final top = products.values.toList()
      ..sort((a, b) => b.qty.compareTo(a.qty));
    return {
      'day': businessDay,
      'orders': valid.length,
      'cancelled': all.length - valid.length,
      'demoOrders': valid.where((o) => o.isDemo).length,
      'paidOrders': paid.length,
      'revenueCents': revenue,
      'averageCents': paid.isEmpty ? 0 : (revenue / paid.length).round(),
      'awaitingCounter': valid
          .where((o) => o.paymentStatus == PaymentStatus.awaitingCounter)
          .length,
      'eatIn': valid.where((o) => o.serviceMode == ServiceMode.eatIn).length,
      'takeAway': valid
          .where((o) => o.serviceMode == ServiceMode.takeAway)
          .length,
      'byHour': byHour,
      'topProducts': [
        for (final p in top.take(10))
          {'name': p.name, 'quantity': p.qty, 'totalCents': p.cents},
      ],
    };
  }

  // ---------------------------------------------------------------------
  // Cancellation and manual actions

  /// [byStaff] = false is the kiosk abandoning its own unpaid order.
  Future<Order> cancel(
    String id, {
    required bool byStaff,
    String? reason,
  }) async {
    var order = get(id);
    if (order.status != OrderStatus.open) {
      throw ApiException.conflict('orderClosed', 'The order is closed.');
    }
    if (_charging.contains(id)) {
      throw ApiException.conflict('paymentInProgress', 'Payment in progress.');
    }
    if (!byStaff &&
        (order.paymentStatus == PaymentStatus.paid ||
            order.kitchenStatus != KitchenStatus.none)) {
      throw ApiException.conflict(
        'cannotCancel',
        'The order is paid or in the kitchen; ask the staff.',
      );
    }
    final paid = order.paymentStatus == PaymentStatus.paid;
    order = _save(
      order
          .copyWith(status: OrderStatus.cancelled)
          .withEvent(
            'cancelled',
            detail: reason ?? (byStaff ? 'staff' : 'kiosk'),
          ),
    );
    if (paid) order = _save(order.withEvent('refundRequired'));
    _db.transaction(() => _returnStock(order));
    return order;
  }

  /// Runs any flow action again by hand (reprint, retry the fiscal
  /// document, resend to the kitchen).
  Future<Order> runAction(String id, FlowAction action) async {
    final order = get(id);
    if (action == FlowAction.issueFiscalDocument &&
        order.paymentStatus != PaymentStatus.paid) {
      throw ApiException.conflict(
        'notPaid',
        'The fiscal document needs a paid order.',
      );
    }
    if (action == FlowAction.issueFiscalDocument &&
        order.fiscalDocument != null) {
      throw ApiException.conflict(
        'alreadyIssued',
        'The fiscal document was already issued.',
      );
    }
    return _complete(await _execute(order, action, manual: true));
  }

  // ---------------------------------------------------------------------
  // Flow engine

  Future<Order> _runEvent(
    Order order,
    FlowEvent event, {
    Set<FlowAction> skip = const {},
  }) async {
    for (final action in _s.flow.actionsFor(event)) {
      if (skip.contains(action)) continue;
      order = await _execute(order, action);
    }
    return order;
  }

  Future<Order> _execute(
    Order order,
    FlowAction action, {
    bool manual = false,
  }) async {
    final tag = manual ? 'manual:${action.name}' : action.name;
    try {
      switch (action) {
        case FlowAction.printCustomerTicket:
          await _print(
            order,
            'customer',
            _settings.customerPrinter,
            customerTicket(order, _s),
          );
        case FlowAction.printKitchenTicket:
          await _print(
            order,
            'kitchen',
            _settings.kitchenPrinter,
            kitchenTicket(order, _s),
          );
        case FlowAction.sendToKitchenDisplay:
          if (order.kitchenStatus == KitchenStatus.none) {
            order = order.copyWith(kitchenStatus: KitchenStatus.queued);
          }
        case FlowAction.issueFiscalDocument:
          if (order.fiscalDocument == null) {
            final doc = await _settings.fiscal.issue(order);
            order = order.copyWith(fiscalDocument: doc);
          }
        case FlowAction.announceOnPickupScreen:
          _bus.emit(ServerEvent.pickupAnnounce, {
            'orderId': order.id,
            'number': order.displayNumber,
          });
      }
      return _save(order.withEvent('action', detail: tag));
    } catch (e) {
      return _save(order.withEvent('actionFailed', detail: '$tag: $e'));
    }
  }

  Future<void> _print(
    Order order,
    String kind,
    TicketPrinter printer,
    Ticket ticket,
  ) async {
    if (printer.type == 'none') {
      throw StateError('no $kind printer configured');
    }
    final text = ticket.toPlainText(printer.width);
    try {
      await printer.printTicket(ticket);
    } catch (e) {
      _printJobs.insert(
        printer: printer.type,
        kind: kind,
        orderId: order.id,
        content: text,
        status: 'failed',
        error: '$e',
      );
      rethrow;
    }
    final id = _printJobs.insert(
      printer: printer.type,
      kind: kind,
      orderId: order.id,
      content: text,
      status: 'printed',
    );
    _bus.emit(ServerEvent.printJob, {
      'id': id,
      'kind': kind,
      'orderId': order.id,
      'content': text,
    });
  }

  /// Closes the order once nothing is left to do: payment settled and the
  /// food handed over (or the kitchen display is not part of the flow).
  Order _complete(Order order) {
    if (order.status != OrderStatus.open) return order;
    final settled =
        order.paymentStatus == PaymentStatus.paid ||
        order.paymentStatus == PaymentStatus.notRequired;
    final usesKitchen =
        order.kitchenStatus != KitchenStatus.none ||
        _s.flow.rules.values.any(
          (a) => a.contains(FlowAction.sendToKitchenDisplay),
        );
    final served =
        !usesKitchen || order.kitchenStatus == KitchenStatus.collected;
    if (settled && served) {
      return _save(
        order.copyWith(status: OrderStatus.completed).withEvent('completed'),
      );
    }
    return order;
  }

  Order _save(Order order) {
    _orders.update(order);
    _bus.emit(ServerEvent.orderUpdated, order.toJson());
    return order;
  }
}
