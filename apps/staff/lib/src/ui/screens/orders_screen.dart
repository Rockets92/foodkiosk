import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:kiosk_core/kiosk_core.dart';

import '../../api.dart';
import '../../session.dart';
import '../theme.dart';
import '../widgets/common.dart';

enum _Filter {
  toCollect('Da incassare'),
  open('Aperti'),
  completed('Completati'),
  cancelled('Annullati'),
  all('Tutti');

  final String label;
  const _Filter(this.label);

  bool matches(Order o) => switch (this) {
    _Filter.toCollect => o.paymentStatus == PaymentStatus.awaitingCounter,
    _Filter.open => o.status == OrderStatus.open,
    _Filter.completed => o.status == OrderStatus.completed,
    _Filter.cancelled => o.status == OrderStatus.cancelled,
    _Filter.all => true,
  };
}

/// Cashier: the day's orders, payment at the till, cancellations and
/// retries of failed actions (printer offline, fiscal device error).
class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  List<Order> _orders = [];
  bool _loading = true;
  String? _error;
  _Filter? _filter;
  String _search = '';
  String? _selectedId;
  DateTime _day = DateTime.now();
  StreamSubscription<ServerEvent>? _sub;
  Timer? _timer;

  bool get _isToday {
    final now = DateTime.now();
    return _day.year == now.year &&
        _day.month == now.month &&
        _day.day == now.day;
  }

  String get _dayKey =>
      '${_day.year.toString().padLeft(4, '0')}-'
      '${_day.month.toString().padLeft(2, '0')}-'
      '${_day.day.toString().padLeft(2, '0')}';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_sub == null) {
      _sub = context.staffRead.orderEvents.listen((_) => _load());
      _timer = Timer.periodic(const Duration(seconds: 30), (_) => _load());
      _load();
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final orders = await context.staffRead.api.orders(day: _dayKey);
      if (!mounted) return;
      setState(() {
        _orders = orders;
        _loading = false;
        _error = null;
        _filter ??= orders.any(_Filter.toCollect.matches)
            ? _Filter.toCollect
            : _Filter.all;
      });
    } on ApiError catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.message;
        });
      }
    }
  }

  Future<void> _pickDay() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _day,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      locale: const Locale('it'),
    );
    if (picked == null) return;
    setState(() {
      _day = picked;
      _loading = true;
      _selectedId = null;
      _filter = null;
    });
    await _load();
  }

  void _replace(Order updated) {
    setState(() {
      _orders = [for (final o in _orders) o.id == updated.id ? updated : o];
    });
  }

  @override
  Widget build(BuildContext context) {
    final filter = _filter ?? _Filter.all;
    final visible = [
      for (final o in _orders)
        if (filter.matches(o) &&
            (_search.isEmpty ||
                o.number.toString().contains(_search) ||
                orderNumber(o.number).contains(_search)))
          o,
    ];
    final selected = _orders.where((o) => o.id == _selectedId).firstOrNull;
    final toCollect = _orders.where(_Filter.toCollect.matches).length;

    return Scaffold(
      key: const ValueKey('orders'),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 520,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PageHeader(
                  title: 'Cassa',
                  subtitle: _isToday
                      ? 'Ordini di oggi · $toCollect da incassare'
                      : 'Ordini del ${_day.day}/${_day.month}/${_day.year}',
                  actions: [
                    OutlinedButton.icon(
                      key: const ValueKey('orders-day'),
                      onPressed: _pickDay,
                      icon: const Icon(Icons.calendar_month_rounded),
                      label: Text(
                        _isToday ? 'Oggi' : '${_day.day}/${_day.month}',
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: TextField(
                    key: const ValueKey('order-search'),
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      hintText: 'Cerca numero ordine',
                      prefixIcon: Icon(Icons.search_rounded),
                      isDense: true,
                    ),
                    onChanged: (v) => setState(() => _search = v.trim()),
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final f in _Filter.values)
                        ChoiceChip(
                          key: ValueKey('filter-${f.name}'),
                          label: Text(
                            '${f.label} '
                            '${_orders.where(f.matches).length}',
                          ),
                          selected: f == filter,
                          onSelected: (_) => setState(() => _filter = f),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Pill(
                      _error!,
                      color: S.red,
                      icon: Icons.wifi_off_rounded,
                    ),
                  ),
                Expanded(
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : visible.isEmpty
                      ? const EmptyState(
                          icon: Icons.receipt_long_rounded,
                          title: 'Nessun ordine',
                          message: 'I nuovi ordini dai totem compaiono qui.',
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(28, 4, 28, 24),
                          itemCount: visible.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 10),
                          itemBuilder: (_, i) =>
                              _OrderRow(
                                order: visible[i],
                                selected: visible[i].id == _selectedId,
                                onTap: () =>
                                    setState(() => _selectedId = visible[i].id),
                              ).animate().fadeIn(
                                duration: 250.ms,
                                delay: (20 * i.clamp(0, 10)).ms,
                              ),
                        ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(0, 24, 24, 24),
              child: selected == null
                  ? const Panel(
                      child: EmptyState(
                        icon: Icons.touch_app_rounded,
                        title: 'Seleziona un ordine',
                        message: 'Il dettaglio e le azioni compaiono qui.',
                      ),
                    )
                  : _OrderDetail(
                      key: ValueKey(selected.id),
                      order: selected,
                      onChanged: _replace,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderRow extends StatelessWidget {
  final Order order;
  final bool selected;
  final VoidCallback onTap;

  const _OrderRow({
    required this.order,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final session = context.staff;
    final (payText, payColor) = paymentStatusLabel(order.paymentStatus);
    final (kText, kColor) = kitchenStatusLabel(order.kitchenStatus);
    final cancelled = order.status == OrderStatus.cancelled;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        key: ValueKey('order-row-${order.number}'),
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: AnimatedContainer(
          duration: S.fast,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected ? S.red : S.line,
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 74,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: (cancelled ? S.muted : payColor).withValues(
                    alpha: 0.12,
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  children: [
                    Text(
                      orderNumber(order.number),
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: cancelled ? S.muted : S.ink,
                        decoration: cancelled
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                    Text(hhmm(order.createdAt), style: ST.small),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(serviceModeIcon(order.serviceMode), size: 16),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            '${serviceModeLabel(order.serviceMode)} · '
                            '${order.itemCount} art.',
                            overflow: TextOverflow.ellipsis,
                            style: ST.h3,
                          ),
                        ),
                        if (order.isDemo) ...[
                          const SizedBox(width: 6),
                          const Pill('DEMO', color: S.warning),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        if (cancelled)
                          const Pill('Annullato', color: S.red)
                        else ...[
                          Pill(payText, color: payColor),
                          if (order.kitchenStatus != KitchenStatus.none)
                            Pill(kText, color: kColor),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              Text(
                session.money(order.totalCents),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OrderDetail extends StatefulWidget {
  final Order order;
  final ValueChanged<Order> onChanged;

  const _OrderDetail({super.key, required this.order, required this.onChanged});

  @override
  State<_OrderDetail> createState() => _OrderDetailState();
}

class _OrderDetailState extends State<_OrderDetail> {
  late bool _issueFiscal = context.staffRead.settings.flow
      .actionsFor(FlowEvent.paid)
      .contains(FlowAction.issueFiscalDocument);
  bool _busy = false;

  Order get order => widget.order;

  bool get _canCollect =>
      order.status == OrderStatus.open &&
      (order.paymentStatus == PaymentStatus.awaitingCounter ||
          order.paymentStatus == PaymentStatus.awaitingKiosk ||
          order.paymentStatus == PaymentStatus.failed);

  /// Actions whose last run failed (a later success clears them).
  List<FlowAction> get _failedActions {
    final state = <FlowAction, bool>{};
    for (final e in order.history) {
      if (e.type != 'action' && e.type != 'actionFailed') continue;
      final tag = (e.detail ?? '')
          .split(':')
          .firstWhere(
            (part) => FlowAction.tryParse(part.trim()) != null,
            orElse: () => '',
          );
      final action = FlowAction.tryParse(tag.trim());
      if (action != null) state[action] = e.type == 'actionFailed';
    }
    return [
      for (final e in state.entries)
        if (e.value) e.key,
    ];
  }

  Future<void> _run(Future<Order> Function() call, String success) async {
    setState(() => _busy = true);
    final updated = await guard(context, call);
    if (!mounted) return;
    setState(() => _busy = false);
    if (updated != null) {
      widget.onChanged(updated);
      showMessage(context, success);
    }
  }

  Future<void> _collect(String method) {
    final api = context.staffRead.api;
    return _run(
      () => api.markPaid(order.id, method: method, issueFiscal: _issueFiscal),
      'Ordine ${orderNumber(order.number)} incassato',
    );
  }

  Future<void> _cancel() async {
    final ok = await confirm(
      context,
      title: 'Annullare l\'ordine ${orderNumber(order.number)}?',
      message: order.paymentStatus == PaymentStatus.paid
          ? 'L\'ordine risulta pagato: ricordati di rimborsare il cliente.'
          : 'L\'ordine sparirà dalla cucina e dallo schermo ritiro.',
      confirmLabel: 'Annulla ordine',
      destructive: true,
    );
    if (!ok || !mounted) return;
    final api = context.staffRead.api;
    await _run(
      () => api.cancelOrder(order.id, reason: 'Annullato in cassa'),
      'Ordine annullato',
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = context.staff;
    final money = session.money;
    final failed = _failedActions;
    final (payText, payColor) = paymentStatusLabel(order.paymentStatus);
    final (stText, stColor) = orderStatusLabel(order.status);

    return Panel(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 18),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: S.line)),
            ),
            child: Row(
              children: [
                Text('Ordine ${orderNumber(order.number)}', style: ST.h1),
                const SizedBox(width: 12),
                Pill(stText, color: stColor),
                const SizedBox(width: 6),
                Pill(payText, color: payColor),
                if (order.isDemo) ...[
                  const SizedBox(width: 6),
                  const Pill('DEMO', color: S.warning),
                ],
                const Spacer(),
                Icon(serviceModeIcon(order.serviceMode), color: S.inkSoft),
                const SizedBox(width: 6),
                Text(
                  '${serviceModeLabel(order.serviceMode)} · '
                  '${hhmm(order.createdAt)}',
                  style: ST.body.copyWith(color: S.inkSoft),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                if (failed.isNotEmpty) ...[
                  _FailedBox(
                    actions: failed,
                    busy: _busy,
                    onRetry: (a) {
                      final api = context.staffRead.api;
                      _run(
                        () => api.runAction(order.id, a),
                        '${flowActionLabel(a)}: eseguito di nuovo',
                      );
                    },
                  ),
                  const SizedBox(height: 18),
                ],
                for (final l in order.lines) _LineTile(line: l, money: money),
                const Divider(height: 28, color: S.line),
                for (final e in order.vatBreakdown.entries)
                  _AmountRow(
                    'di cui IVA ${_rate(e.key)}%',
                    money(e.value),
                    small: true,
                  ),
                const SizedBox(height: 4),
                _AmountRow('Totale', money(order.totalCents), big: true),
                const SizedBox(height: 18),
                _InfoGrid(order: order),
                const SizedBox(height: 22),
                const Text('Cronologia', style: ST.h3),
                const SizedBox(height: 8),
                for (final e in order.history.reversed) _HistoryTile(event: e),
              ],
            ),
          ),
          if (order.status == OrderStatus.open)
            Container(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: S.line)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_canCollect) ...[
                    SwitchListTile(
                      key: const ValueKey('issue-fiscal'),
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Emetti documento fiscale'),
                      subtitle: const Text(
                        'Disattiva se lo scontrino lo emette già la tua cassa',
                        style: ST.small,
                      ),
                      value: _issueFiscal,
                      onChanged: (v) => setState(() => _issueFiscal = v),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            key: const ValueKey('pay-cash'),
                            style: FilledButton.styleFrom(
                              backgroundColor: S.success,
                              minimumSize: const Size.fromHeight(64),
                            ),
                            onPressed: _busy ? null : () => _collect('cash'),
                            icon: const Icon(Icons.payments_rounded),
                            label: Text(
                              'Incassato in contanti · '
                              '${money(order.totalCents)}',
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton.icon(
                            key: const ValueKey('pay-card'),
                            style: FilledButton.styleFrom(
                              backgroundColor: S.info,
                              minimumSize: const Size.fromHeight(64),
                            ),
                            onPressed: _busy ? null : () => _collect('card'),
                            icon: const Icon(Icons.credit_card_rounded),
                            label: const Text('Incassato con carta'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                  ],
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      key: const ValueKey('cancel-order'),
                      style: TextButton.styleFrom(foregroundColor: S.red),
                      onPressed: _busy ? null : _cancel,
                      icon: const Icon(Icons.cancel_outlined),
                      label: const Text('Annulla ordine'),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    ).animate().fadeIn(duration: 250.ms).slideX(begin: 0.03);
  }

  static String _rate(double r) =>
      r == r.roundToDouble() ? r.toInt().toString() : r.toString();
}

class _FailedBox extends StatelessWidget {
  final List<FlowAction> actions;
  final bool busy;
  final ValueChanged<FlowAction> onRetry;

  const _FailedBox({
    required this.actions,
    required this.busy,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: S.red.withValues(alpha: 0.07),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: S.red.withValues(alpha: 0.3)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.error_outline_rounded, color: S.red),
            SizedBox(width: 8),
            Text(
              'Operazioni non riuscite',
              style: TextStyle(fontWeight: FontWeight.w700, color: S.red),
            ),
          ],
        ),
        const SizedBox(height: 8),
        for (final a in actions)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              children: [
                Expanded(child: Text(flowActionLabel(a), style: ST.body)),
                OutlinedButton.icon(
                  key: ValueKey('retry-${a.name}'),
                  onPressed: busy ? null : () => onRetry(a),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Riprova'),
                ),
              ],
            ),
          ),
      ],
    ),
  );
}

class _LineTile extends StatelessWidget {
  final OrderLine line;
  final String Function(Cents) money;
  const _LineTile({required this.line, required this.money});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: 2),
          decoration: BoxDecoration(
            color: const Color(0xFFF4F1EC),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '${line.quantity}×',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(line.name.resolve('it'), style: ST.h3),
              for (final o in line.options)
                Text(
                  o.priceDeltaCents == 0
                      ? o.name.resolve('it')
                      : '${o.name.resolve('it')} '
                            '(+${money(o.priceDeltaCents)})',
                  style: ST.small,
                ),
              if (line.note case final note? when note.isNotEmpty)
                Text(
                  '“$note”',
                  style: ST.small.copyWith(fontStyle: FontStyle.italic),
                ),
            ],
          ),
        ),
        Text(money(line.totalCents), style: ST.h3),
      ],
    ),
  );
}

class _AmountRow extends StatelessWidget {
  final String label;
  final String value;
  final bool big;
  final bool small;
  const _AmountRow(
    this.label,
    this.value, {
    this.big = false,
    this.small = false,
  });

  @override
  Widget build(BuildContext context) {
    final style = big
        ? const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)
        : small
        ? ST.small
        : ST.body;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text(value, style: style),
        ],
      ),
    );
  }
}

class _InfoGrid extends StatelessWidget {
  final Order order;
  const _InfoGrid({required this.order});

  @override
  Widget build(BuildContext context) {
    final p = order.payment;
    final items = <(IconData, String, String)>[
      (
        Icons.account_balance_wallet_rounded,
        'Pagamento',
        paymentModeLabel(order.paymentMode),
      ),
      if (p != null)
        (
          Icons.credit_card_rounded,
          'Incasso',
          [
            _method(p.provider),
            if (p.cardBrand != null) p.cardBrand!,
            if (p.maskedPan != null) p.maskedPan!,
            if (p.authCode != null) 'aut. ${p.authCode}',
            hhmm(p.at),
          ].join(' · '),
        ),
      if (order.fiscalDocument case final doc?)
        (Icons.receipt_rounded, 'Documento fiscale', doc.number),
      (
        Icons.soup_kitchen_rounded,
        'Cucina',
        kitchenStatusLabel(order.kitchenStatus).$1,
      ),
      (Icons.translate_rounded, 'Lingua', order.language.toUpperCase()),
    ];
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        for (final (icon, label, value) in items)
          Container(
            constraints: const BoxConstraints(minWidth: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F5F0),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 20, color: S.inkSoft),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: ST.small),
                    Text(
                      value,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }

  static String _method(String provider) => switch (provider) {
    'cash' || 'counter' => 'Contanti',
    'card' => 'Carta (POS cassa)',
    'demo' => 'POS totem (demo)',
    _ => 'POS totem ($provider)',
  };
}

class _HistoryTile extends StatelessWidget {
  final OrderEvent event;
  const _HistoryTile({required this.event});

  @override
  Widget build(BuildContext context) {
    final (label, color) = _describe(event);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 48, child: Text(hhmm(event.at), style: ST.small)),
          Container(
            margin: const EdgeInsets.only(top: 6, right: 10),
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          Expanded(child: Text(label, style: ST.body)),
        ],
      ),
    );
  }

  static (String, Color) _describe(OrderEvent e) {
    String actionName(String? detail) {
      final tag = (detail ?? '').split(':');
      for (final part in tag) {
        final a = FlowAction.tryParse(part.trim());
        if (a != null) return flowActionLabel(a);
      }
      return detail ?? '';
    }

    String errorOf(String? detail) {
      final d = detail ?? '';
      final i = d.indexOf(': ');
      return i < 0 ? d : d.substring(i + 2);
    }

    return switch (e.type) {
      'created' => ('Ordine creato', S.info),
      'paymentStarted' => ('Pagamento avviato sul totem', S.info),
      'paymentFailed' => (
        'Pagamento rifiutato${e.detail == null ? '' : ': ${e.detail}'}',
        S.red,
      ),
      'paid' => ('Pagato', S.success),
      'switchedToCounter' => ('Il cliente pagherà in cassa', S.warning),
      'action' => (actionName(e.detail), S.success),
      'actionFailed' => (
        '${actionName(e.detail)} non riuscito: ${errorOf(e.detail)}',
        S.red,
      ),
      'cancelled' => (
        'Annullato${e.detail == null ? '' : ' (${e.detail})'}',
        S.red,
      ),
      'refundRequired' => ('Da rimborsare', S.red),
      'completed' => ('Completato', S.success),
      final t when t.startsWith('kitchen.') => (
        'Cucina: ${kitchenStatusLabel(KitchenStatus.parse(t.substring(8))).$1}',
        S.info,
      ),
      _ => (e.detail == null ? e.type : '${e.type}: ${e.detail}', S.muted),
    };
  }
}
