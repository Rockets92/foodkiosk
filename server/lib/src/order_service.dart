import 'dart:typed_data';

import 'package:kiosk_core/kiosk_core.dart';

import 'adapters/fiscal.dart';
import 'adapters/printer.dart';
import 'database.dart';
import 'discount_service.dart';
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
  final DiscountService _discounts;
  final DateTime Function() _clock;

  /// Orders with a kiosk payment in flight, to refuse double charges.
  final _charging = <String>{};

  /// Tickets for the totem's own printer, by order, until the totem that
  /// placed the order collects them with the reply to its request.
  final _kioskReceipts = <String, List<Uint8List>>{};

  OrderService(
    this._db,
    this._menu,
    this._orders,
    this._printJobs,
    this._settings,
    this._bus,
    this._discounts, {
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

  /// Tickets the totem has to print for order [id]; each is handed out
  /// once.
  List<Uint8List> takeKioskReceipts(String id) =>
      _kioskReceipts.remove(id) ?? const [];

  // ---------------------------------------------------------------------
  // Creation

  /// A kiosk order, or with [origin] counter one the cashier enters for a
  /// customer at the till: always paid at the counter and, when
  /// [payMethod] is given, paid on the spot (before the "submitted"
  /// actions run, so the ticket prints as paid).
  Future<Order> create(
    OrderRequest req, {
    OrderOrigin origin = OrderOrigin.kiosk,
    String? payMethod,
    Cents? cashCents,
    Cents? cardCents,
    Cents? receivedCents,
    bool issueFiscal = true,
    FiscalCustomer fiscalCustomer = const FiscalCustomer(),
  }) async {
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

    final paymentMode = origin == OrderOrigin.counter
        ? PaymentMode.counter
        : switch (s.flow.paymentMode) {
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
    final (code, discount) = _discountFor(
      req.discountCode,
      lines,
      origin == OrderOrigin.counter
          ? DiscountChannel.counter
          : DiscountChannel.kiosk,
    );
    final payment = payMethod == null
        ? null
        : _counterPayment(
            lines.fold(0, (sum, l) => sum + l.totalCents) -
                (discount?.amountCents ?? 0),
            method: payMethod,
            cashCents: cashCents,
            cardCents: cardCents,
            receivedCents: receivedCents,
          );
    if (payment != null) _checkFiscalCustomer(fiscalCustomer, payment);

    final order = _db.transaction(() {
      final now = _clock();
      if (s.enforcesStock) _takeStock(lines);
      if (code != null) _discounts.claim(code);
      final order =
          Order(
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
            origin: origin,
            discount: discount,
            fiscalCustomer: payment == null
                ? const FiscalCustomer()
                : fiscalCustomer,
          ).withEvent(
            origin == OrderOrigin.counter ? 'createdAtCounter' : 'created',
            at: now,
          );
      _orders.insert(order);
      return order;
    });
    _bus.emit(ServerEvent.orderCreated, order.toJson());
    if (payment == null) {
      return _complete(await _runEvent(order, FlowEvent.submitted));
    }
    var paid = _save(
      order
          .copyWith(paymentStatus: PaymentStatus.paid, payment: payment)
          .withEvent('paid', detail: payMethod),
    );
    final submitted = s.flow.actionsFor(FlowEvent.submitted);
    // Paid on the spot: the fiscal document comes first so that, when the
    // suite prints it, it is the customer's only ticket.
    if (issueFiscal &&
        s.flow
            .actionsFor(FlowEvent.paid)
            .contains(FlowAction.issueFiscalDocument)) {
      paid = await _execute(paid, FlowAction.issueFiscalDocument);
    }
    final documentPrinted = _printedOwnDocument(paid);
    paid = await _runEvent(
      paid,
      FlowEvent.submitted,
      skip: {if (documentPrinted) FlowAction.printCustomerTicket},
    );
    paid = await _runEvent(
      paid,
      FlowEvent.paid,
      skip: {
        FlowAction.issueFiscalDocument,
        if (documentPrinted ||
            submitted.contains(FlowAction.printCustomerTicket))
          FlowAction.printCustomerTicket,
      },
    );
    return _complete(paid);
  }

  /// The code entered with the order and what it takes off [lines];
  /// (null, null) without a code.
  (DiscountCode?, OrderDiscount?) _discountFor(
    String? raw,
    List<OrderLine> lines,
    DiscountChannel channel,
  ) {
    if (raw == null || raw.trim().isEmpty) return (null, null);
    final code = _discounts.lookup(raw, channel: channel);
    return (code, _discounts.apply(code, lines));
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
    Cents? cashCents,
    Cents? cardCents,
    Cents? receivedCents,
    bool issueFiscal = true,
    FiscalCustomer fiscalCustomer = const FiscalCustomer(),
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
    final payment = _counterPayment(
      order.totalCents,
      method: method,
      cashCents: cashCents,
      cardCents: cardCents,
      receivedCents: receivedCents,
    );
    _checkFiscalCustomer(fiscalCustomer, payment);
    order = _save(
      order
          .copyWith(
            paymentStatus: PaymentStatus.paid,
            payment: payment,
            fiscalCustomer: fiscalCustomer,
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

  /// A payment taken at the till: `cash` (with the cash handed over, to
  /// work out the change), `card`, or `mixed` (part cash, part card).
  PaymentInfo _counterPayment(
    Cents total, {
    required String method,
    Cents? cashCents,
    Cents? cardCents,
    Cents? receivedCents,
  }) {
    Never bad(String code, String message) =>
        throw ApiException.badRequest(code, message);
    final (cash, card) = switch (method) {
      'cash' => (total, null),
      'card' => (null, total),
      'mixed' => (cashCents, cardCents),
      _ => (null, null),
    };
    if (method == 'mixed') {
      if (cash == null || card == null || cash <= 0 || card <= 0) {
        bad('invalidSplit', 'A mixed payment needs a cash and a card part.');
      }
      if (cash + card != total) {
        bad('invalidSplit', 'Cash and card parts must add up to the total.');
      }
    }
    if (receivedCents != null && (cash == null || receivedCents < cash)) {
      bad('notEnoughCash', 'The cash received is less than the amount due.');
    }
    return PaymentInfo(
      provider: method,
      at: _clock(),
      cashCents: cash,
      cardCents: card,
      receivedCents: receivedCents,
    );
  }

  /// The lottery code and the buyer's tax code asked for at the till.
  void _checkFiscalCustomer(FiscalCustomer c, PaymentInfo payment) {
    final errors = c.validate();
    if (errors.isNotEmpty) {
      throw ApiException.badRequest('invalidFiscalCustomer', errors.first);
    }
    // The receipts lottery only takes electronic payments.
    if (c.lotteryCode != null &&
        payment.provider != 'card' &&
        (payment.cardCents ?? 0) == 0) {
      throw ApiException.badRequest(
        'lotteryNeedsCard',
        'The lottery code needs a payment made, at least in part, by card.',
      );
    }
  }

  /// Changes the items of an order still waiting at the till and not yet
  /// in the kitchen (the customer adds a drink when paying).
  Future<Order> editLines(String id, OrderRequest req) async {
    var order = get(id);
    if (order.status != OrderStatus.open ||
        order.paymentStatus != PaymentStatus.awaitingCounter ||
        order.kitchenStatus != KitchenStatus.none) {
      throw ApiException.conflict(
        'notEditable',
        'Only unpaid orders not yet in the kitchen can be changed.',
      );
    }
    if (req.lines.isEmpty) {
      throw ApiException.badRequest('emptyOrder', 'The order has no items.');
    }
    final mode = req.serviceMode;
    final menu = _menu.loadForKiosk();
    final lines = [for (final l in req.lines) _priceLine(menu, l, mode)];
    final previous = order.discount;
    final raw = req.discountCode == null
        ? null
        : DiscountCode.normalize(req.discountCode!);
    // The code already on the order keeps its use even if it has since
    // run out or been disabled; only its amount follows the new items.
    final DiscountCode? code;
    final OrderDiscount? discount;
    if (raw == null || raw.isEmpty) {
      (code, discount) = (null, null);
    } else if (previous != null && previous.code == raw) {
      final kept = _discounts.repository.byId(previous.codeId);
      code = null;
      discount = kept == null
          ? _reprice(previous, lines)
          : OrderDiscount.of(kept, _discounts.apply(kept, lines).amountCents);
    } else {
      (code, discount) = _discountFor(raw, lines, DiscountChannel.counter);
    }
    order = _db.transaction(() {
      _returnStock(order);
      if (_s.enforcesStock) _takeStock(lines);
      final codeChanged = previous?.code != discount?.code;
      if (codeChanged && previous != null) {
        _discounts.release(previous.codeId);
      }
      if (code != null) _discounts.claim(code);
      final edited = order
          .copyWith(serviceMode: mode, lines: lines)
          .withDiscount(discount)
          .withEvent(
            'edited',
            at: _clock(),
            detail: !codeChanged
                ? null
                : discount == null
                ? 'discountRemoved'
                : 'discount:${discount.code}',
          );
      _orders.update(edited);
      return edited;
    });
    _bus.emit(ServerEvent.orderUpdated, order.toJson());
    return order;
  }

  /// A discount whose code was deleted: same kind, recomputed by hand.
  OrderDiscount _reprice(OrderDiscount d, List<OrderLine> lines) {
    final code = DiscountCode(
      id: d.codeId,
      code: d.code,
      type: d.type,
      percent: d.percent,
      productId: d.productId,
      amountCents: d.type == DiscountType.amount ? d.amountCents : 0,
    );
    return _discounts.apply(code, lines);
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
    Cents cashOf(Order o) =>
        o.payment?.cashCents ??
        (o.payment?.provider == 'cash' ? o.totalCents : 0);
    final cash = paid.fold(0, (s, o) => s + cashOf(o));
    final discounted = paid.where((o) => o.discount != null);
    final codes = <String, ({int uses, int cents})>{};
    for (final o in discounted) {
      final prev = codes[o.discount!.code];
      codes[o.discount!.code] = (
        uses: (prev?.uses ?? 0) + 1,
        cents: (prev?.cents ?? 0) + o.discountCents,
      );
    }
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
      'cashCents': cash,
      'cardCents': revenue - cash,
      'orders': valid.length,
      'cancelled': all.length - valid.length,
      'demoOrders': valid.where((o) => o.isDemo).length,
      'paidOrders': paid.length,
      'revenueCents': revenue,
      'averageCents': paid.isEmpty ? 0 : (revenue / paid.length).round(),
      'discountCents': discounted.fold<int>(0, (s, o) => s + o.discountCents),
      'discountedOrders': discounted.length,
      'discountCodes': [
        for (final e in codes.entries)
          {'code': e.key, 'uses': e.value.uses, 'totalCents': e.value.cents},
      ],
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
    final discount = order.discount;
    _db.transaction(() {
      _returnStock(order);
      if (discount != null) _discounts.release(discount.codeId);
    });
    if (order.fiscalDocument != null) order = await _voidFiscal(order);
    return order;
  }

  /// Voids the fiscal document of a cancelled order again, after a failure
  /// (provider offline, credentials expired).
  Future<Order> retryFiscalVoid(String id) async {
    final order = get(id);
    if (order.status != OrderStatus.cancelled || order.fiscalDocument == null) {
      throw ApiException.conflict(
        'nothingToVoid',
        'Only cancelled orders with a fiscal document can be voided.',
      );
    }
    if (order.fiscalVoid != null) {
      throw ApiException.conflict(
        'alreadyVoided',
        'The fiscal document was already voided.',
      );
    }
    return _voidFiscal(order);
  }

  /// Issues the "documento commerciale di annullo" and, when the device
  /// does not print it, prints it at the till. A failure is recorded and
  /// can be retried with [retryFiscalVoid].
  Future<Order> _voidFiscal(Order order) async {
    final sale = order.fiscalDocument!;
    try {
      final device = sale.provider == 'demo'
          ? DemoFiscalDevice(printsDocument: sale.printedByDevice)
          : _settings.fiscal;
      if (device.type != sale.provider) {
        throw FiscalException(
          'Il documento è stato emesso con un altro dispositivo '
          '(${sale.provider}): annullalo da lì',
        );
      }
      final doc = await device.voidDocument(order);
      order = _save(
        order
            .copyWith(fiscalVoid: doc)
            .withEvent('fiscalVoided', detail: doc.number),
      );
      if (!doc.printedByDevice) {
        await _print(
          order,
          'fiscal',
          _settings.counterPrinter,
          voidCommercialDocument(order, _s),
        );
      }
    } catch (e) {
      order = _save(order.withEvent('fiscalVoidFailed', detail: '$e'));
    }
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
    final actions = [..._s.flow.actionsFor(event)];
    // The fiscal document comes first: when the suite prints it, it is the
    // customer's ticket, and the plain ticket is not printed as well.
    if (actions.remove(FlowAction.issueFiscalDocument)) {
      actions.insert(0, FlowAction.issueFiscalDocument);
    }
    var documentPrinted = false;
    for (final action in actions) {
      if (skip.contains(action)) continue;
      if (action == FlowAction.printCustomerTicket && documentPrinted) continue;
      final hadDocument = order.fiscalDocument != null;
      order = await _execute(order, action);
      if (action == FlowAction.issueFiscalDocument && !hadDocument) {
        documentPrinted = _printedOwnDocument(order);
      }
    }
    return order;
  }

  /// The suite has just printed the order's documento commerciale: the
  /// last action, issuing it, succeeded print included.
  bool _printedOwnDocument(Order order) =>
      order.fiscalDocument?.printedByDevice == false &&
      order.history.lastOrNull?.type == 'action' &&
      order.history.last.detail == FlowAction.issueFiscalDocument.name;

  /// The totem's own printer only serves the totem while it waits for the
  /// reply: reprints asked by staff and orders entered at the till come out
  /// at the till.
  TicketPrinter _customerPrinter(Order order, {bool manual = false}) {
    final printer = _settings.customerPrinter;
    return printer is KioskReceiptPrinter &&
            (manual || order.origin != OrderOrigin.kiosk)
        ? _settings.counterPrinter
        : printer;
  }

  /// Fiscal documents of orders paid at the till come out at the till.
  TicketPrinter _fiscalPrinter(Order order) =>
      order.paymentMode == PaymentMode.counter
      ? _settings.counterPrinter
      : _customerPrinter(order);

  Future<Order> _execute(
    Order order,
    FlowAction action, {
    bool manual = false,
  }) async {
    final tag = manual ? 'manual:${action.name}' : action.name;
    try {
      switch (action) {
        case FlowAction.printCustomerTicket:
          if (order.fiscalDocument case final doc? when !doc.printedByDevice) {
            // Reprint of the documento commerciale, at the till when asked
            // by the staff.
            final printed = _printJobs
                .recent(orderId: order.id)
                .any((j) => j.kind == 'fiscal' && j.status == 'printed');
            await _print(
              order,
              'fiscal',
              manual ? _settings.counterPrinter : _fiscalPrinter(order),
              customerTicket(order, _s, reprint: printed),
            );
          } else {
            await _print(
              order,
              'customer',
              _customerPrinter(order, manual: manual),
              customerTicket(order, _s),
            );
          }
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
            // Saved before printing: a printer failure must not lose it.
            order = _save(
              order
                  .copyWith(fiscalDocument: doc)
                  .withEvent('fiscalIssued', detail: doc.number),
            );
            if (!doc.printedByDevice) {
              await _print(
                order,
                'fiscal',
                _fiscalPrinter(order),
                commercialDocument(order, _s),
              );
            }
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
      if (printer is KioskReceiptPrinter) {
        (_kioskReceipts[order.id] ??= []).add(printer.encode(ticket));
        // Never collected (the totem lost the reply): oldest dropped.
        while (_kioskReceipts.length > 50) {
          _kioskReceipts.remove(_kioskReceipts.keys.first);
        }
      } else {
        await printer.printTicket(ticket);
      }
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
