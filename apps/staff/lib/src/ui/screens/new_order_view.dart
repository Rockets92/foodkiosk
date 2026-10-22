import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:kiosk_core/kiosk_core.dart';

import '../../api.dart';
import '../../session.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/payment_dialog.dart';
import '../widgets/scanner_listener.dart';

/// One line of the cashier's cart, priced from the menu for display (the
/// server prices it again).
class _Line {
  final Product product;
  final List<ModifierOption> options;
  int quantity;

  _Line(this.product, this.options, this.quantity);

  Cents get unitCents =>
      product.priceCents + options.fold(0, (s, o) => s + o.priceDeltaCents);

  bool sameAs(Product p, List<ModifierOption> opts) =>
      product.id == p.id &&
      options.map((o) => o.id).toSet().containsAll(opts.map((o) => o.id)) &&
      options.length == opts.length;
}

/// Cashier: enter an order for a customer at the till (or change the items
/// of an unpaid one, [editing]), then cash it or leave it to pay later.
class NewOrderView extends StatefulWidget {
  final Order? editing;
  final void Function(Order order, String message) onDone;
  final VoidCallback onCancel;

  const NewOrderView({
    super.key,
    this.editing,
    required this.onDone,
    required this.onCancel,
  });

  @override
  State<NewOrderView> createState() => _NewOrderViewState();
}

class _NewOrderViewState extends State<NewOrderView> {
  final _lines = <_Line>[];
  String? _categoryId;
  ServiceMode? _mode;
  bool _issueFiscal = true;
  bool _busy = false;

  /// The discount code the customer gave, priced again on every change.
  DiscountCode? _coupon;
  bool _checking = false;
  final _code = TextEditingController();

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    final order = widget.editing;
    if (order == null) return;
    _mode = order.serviceMode;
    if (order.discount case final d?) {
      _coupon = DiscountCode(
        id: d.codeId,
        code: d.code,
        type: d.type,
        label: d.label,
        percent: d.percent,
        productId: d.productId,
        amountCents: d.type == DiscountType.amount ? d.amountCents : 0,
      );
    }
    final menu = context.staffRead.menu;
    for (final l in order.lines) {
      final product = menu.product(l.productId);
      if (product == null) continue;
      _lines.add(
        _Line(product, [
          for (final o in l.options)
            ?menu.modifierGroup(o.groupId)?.option(o.optionId),
        ], l.quantity),
      );
    }
  }

  List<ServiceMode> _modes(StaffSession s) =>
      s.settings.serviceModes.toList()
        ..sort((a, b) => a.index.compareTo(b.index));

  ServiceMode _currentMode(StaffSession s) {
    final modes = _modes(s);
    return _mode != null && modes.contains(_mode) ? _mode! : modes.first;
  }

  Cents get _subtotal => _lines.fold(0, (s, l) => s + l.unitCents * l.quantity);

  DiscountResult? get _discount => _coupon?.evaluate([
    for (final l in _lines)
      (
        productId: l.product.id,
        quantity: l.quantity,
        unitBaseCents: l.product.priceCents,
        totalCents: l.unitCents * l.quantity,
      ),
  ]);

  Cents get _discountCents {
    final d = _discount;
    return d != null && d.ok ? d.amountCents : 0;
  }

  Cents get _total => _subtotal - _discountCents;

  Future<void> _applyCode(String raw) async {
    final code = DiscountCode.normalize(raw);
    if (code.isEmpty || _checking) return;
    final api = context.staffRead.api;
    setState(() => _checking = true);
    final found = await guard(context, () => api.checkDiscount(code));
    if (!mounted) return;
    setState(() {
      _checking = false;
      if (found != null) {
        _coupon = found;
        _code.clear();
      }
    });
    if (found != null) showMessage(context, 'Codice ${found.code} applicato');
  }

  List<Category> _categories(Menu menu, ServiceMode mode) => [
    for (final c in [
      ...menu.categories,
    ]..sort((a, b) => a.sortOrder.compareTo(b.sortOrder)))
      if (c.enabled &&
          c.visibleFor(mode) &&
          menu.productsIn(c.id).any((p) => p.enabled))
        c,
  ];

  Future<void> _add(Product product) async {
    final session = context.staffRead;
    final groups = [
      for (final id in product.modifierGroupIds)
        if (session.menu.modifierGroup(id) case final g?)
          if (g.options.any((o) => o.enabled)) g,
    ];
    var options = <ModifierOption>[];
    if (groups.isNotEmpty) {
      final picked = await showDialog<List<ModifierOption>>(
        context: context,
        builder: (_) => StaffScope(
          session: session,
          child: _OptionsDialog(product: product, groups: groups),
        ),
      );
      if (picked == null) return;
      options = picked;
    }
    setState(() {
      final same = _lines.where((l) => l.sameAs(product, options)).firstOrNull;
      if (same != null) {
        same.quantity++;
      } else {
        _lines.add(_Line(product, options, 1));
      }
    });
  }

  OrderRequest _request(StaffSession session) => OrderRequest(
    serviceMode: _currentMode(session),
    language: widget.editing?.language ?? session.settings.defaultLanguage,
    lines: [
      for (final l in _lines)
        OrderRequestLine(
          productId: l.product.id,
          quantity: l.quantity,
          optionIds: [for (final o in l.options) o.id],
        ),
    ],
    discountCode: _discount?.ok ?? false ? _coupon!.code : null,
  );

  /// Saves the order and, with [pay], asks for the payment and cashes it.
  Future<void> _save({required bool pay}) async {
    final session = context.staffRead;
    final money = session.money;
    final total = _total;
    CounterPayment? payment;
    if (pay) {
      payment = await showPaymentDialog(context, totalCents: total);
      if (payment == null || !mounted) return;
    }
    setState(() => _busy = true);
    final editing = widget.editing;
    final order = await guard(context, () async {
      if (editing == null) {
        return session.api.createCounterOrder(
          _request(session),
          payment: payment,
          issueFiscal: _issueFiscal,
        );
      }
      final saved = await session.api.editOrderLines(
        editing.id,
        _request(session),
      );
      if (payment == null) return saved;
      return session.api.markPaid(
        saved.id,
        payment: payment,
        issueFiscal: _issueFiscal,
      );
    });
    if (!mounted) return;
    setState(() => _busy = false);
    if (order == null) return;
    final n = orderNumber(order.number);
    final change = payment?.receivedCents;
    widget.onDone(
      order,
      payment == null
          ? editing == null
                ? 'Ordine $n salvato: lo trovi tra quelli da incassare'
                : 'Ordine $n aggiornato'
          : change == null
          ? 'Ordine $n incassato'
          : 'Ordine $n incassato · resto ${money(change - order.totalCents)}',
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = context.staff;
    final settings = session.settings;
    final modes = _modes(session);
    final mode = _currentMode(session);
    final categories = _categories(session.menu, mode);
    final category =
        categories.where((c) => c.id == _categoryId).firstOrNull ??
        categories.firstOrNull;
    final products = category == null
        ? const <Product>[]
        : session.menu.productsIn(category.id).where((p) => p.enabled).toList();
    final fiscalOnPayment = settings.flow
        .actionsFor(FlowEvent.paid)
        .contains(FlowAction.issueFiscalDocument);
    final codes = settings.discounts.onCounter;

    return ScannerListener(
      enabled: codes && !_busy,
      onScan: _applyCode,
      child: Row(
        key: const ValueKey('new-order'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PageHeader(
                  title: widget.editing == null
                      ? 'Nuovo ordine'
                      : 'Ordine ${orderNumber(widget.editing!.number)}',
                  subtitle: widget.editing == null
                      ? 'Per un cliente in cassa'
                      : 'Aggiungi o togli prodotti prima di incassare',
                  actions: [
                    OutlinedButton.icon(
                      key: const ValueKey('new-order-cancel'),
                      onPressed: _busy ? null : widget.onCancel,
                      icon: const Icon(Icons.arrow_back_rounded),
                      label: const Text('Torna agli ordini'),
                    ),
                  ],
                ),
                SizedBox(
                  height: 48,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    children: [
                      for (final c in categories)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            key: ValueKey('new-order-cat-${c.id}'),
                            label: Text(c.name.resolve('it')),
                            selected: c.id == category?.id,
                            onSelected: (_) =>
                                setState(() => _categoryId = c.id),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: products.isEmpty
                      ? const EmptyState(
                          icon: Icons.restaurant_menu_rounded,
                          title: 'Nessun prodotto',
                          message: 'Aggiungi prodotti dalla sezione Menu.',
                        )
                      : GridView.builder(
                          padding: const EdgeInsets.fromLTRB(28, 8, 28, 24),
                          gridDelegate:
                              const SliverGridDelegateWithMaxCrossAxisExtent(
                                maxCrossAxisExtent: 200,
                                mainAxisExtent: 196,
                                mainAxisSpacing: 12,
                                crossAxisSpacing: 12,
                              ),
                          itemCount: products.length,
                          itemBuilder: (_, i) =>
                              _ProductTile(
                                product: products[i],
                                onTap: products[i].soldOut
                                    ? null
                                    : () => _add(products[i]),
                              ).animate().fadeIn(
                                duration: 220.ms,
                                delay: (15 * i.clamp(0, 12)).ms,
                              ),
                        ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 400,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(0, 24, 24, 24),
              child: Panel(
                padding: EdgeInsets.zero,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                      child: Text('Ordine', style: ST.h2),
                    ),
                    if (modes.length > 1)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: SegmentedButton<ServiceMode>(
                          key: const ValueKey('new-order-mode'),
                          segments: [
                            for (final m in modes)
                              ButtonSegment(
                                value: m,
                                label: Text(serviceModeLabel(m)),
                              ),
                          ],
                          selected: {mode},
                          onSelectionChanged: (s) =>
                              setState(() => _mode = s.first),
                        ),
                      ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: _lines.isEmpty
                          ? const EmptyState(
                              icon: Icons.add_shopping_cart_rounded,
                              title: 'Ordine vuoto',
                              message: 'Tocca i prodotti per aggiungerli.',
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 8,
                              ),
                              itemCount: _lines.length,
                              separatorBuilder: (_, _) => const Divider(),
                              itemBuilder: (_, i) => _CartLine(
                                key: ValueKey('new-order-line-$i'),
                                line: _lines[i],
                                money: session.money,
                                onMinus: () => setState(() {
                                  if (--_lines[i].quantity == 0) {
                                    _lines.removeAt(i);
                                  }
                                }),
                                onPlus: () => setState(() {
                                  if (_lines[i].quantity <
                                      settings.maxQuantityPerLine) {
                                    _lines[i].quantity++;
                                  }
                                }),
                              ),
                            ),
                    ),
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (codes || _coupon != null) ...[
                            _CouponBox(
                              coupon: _coupon,
                              result: _discount,
                              controller: _code,
                              checking: _checking,
                              money: session.money,
                              productName: _coupon?.productId == null
                                  ? null
                                  : session.menu
                                        .product(_coupon!.productId!)
                                        ?.name
                                        .resolve('it'),
                              onApply: () => _applyCode(_code.text),
                              onRemove: () => setState(() => _coupon = null),
                            ),
                            const SizedBox(height: 12),
                          ],
                          if (_discountCents > 0) ...[
                            _SmallRow('Subtotale', session.money(_subtotal)),
                            _SmallRow(
                              'Sconto ${_coupon!.code}',
                              '-${session.money(_discountCents)}',
                              key: const ValueKey('new-order-discount'),
                              color: S.success,
                            ),
                            const SizedBox(height: 4),
                          ],
                          Row(
                            children: [
                              const Expanded(
                                child: Text('Totale', style: ST.h2),
                              ),
                              Text(
                                session.money(_total),
                                key: const ValueKey('new-order-total'),
                                style: ST.h1,
                              ),
                            ],
                          ),
                          if (fiscalOnPayment)
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              value: _issueFiscal,
                              onChanged: (v) =>
                                  setState(() => _issueFiscal = v),
                              title: const Text('Emetti documento fiscale'),
                            ),
                          const SizedBox(height: 12),
                          FilledButton.icon(
                            key: const ValueKey('new-order-pay'),
                            style: FilledButton.styleFrom(
                              backgroundColor: S.success,
                              minimumSize: const Size.fromHeight(60),
                            ),
                            onPressed: _lines.isEmpty || _busy
                                ? null
                                : () => _save(pay: true),
                            icon: const Icon(Icons.point_of_sale_rounded),
                            label: Text(
                              widget.editing == null
                                  ? 'Incassa'
                                  : 'Salva e incassa',
                            ),
                          ),
                          const SizedBox(height: 10),
                          OutlinedButton.icon(
                            key: const ValueKey('new-order-save'),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(52),
                            ),
                            onPressed: _lines.isEmpty || _busy
                                ? null
                                : () => _save(pay: false),
                            icon: const Icon(Icons.schedule_rounded),
                            label: Text(
                              widget.editing == null
                                  ? 'Salva, incassa dopo'
                                  : 'Salva modifiche',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductTile extends StatelessWidget {
  final Product product;
  final VoidCallback? onTap;
  const _ProductTile({required this.product, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final money = context.staff.money;
    return Opacity(
      opacity: onTap == null ? 0.45 : 1,
      child: Panel(
        padding: EdgeInsets.zero,
        child: InkWell(
          key: ValueKey('new-order-product-${product.id}'),
          borderRadius: BorderRadius.circular(S.radius),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                ServerImage(product.imageUrl, size: 96, radius: 16),
                const SizedBox(height: 8),
                Text(
                  product.name.resolve('it'),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: S.ink,
                  ),
                ),
                const Spacer(),
                Text(
                  product.soldOut ? 'Esaurito' : money(product.priceCents),
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: product.soldOut ? S.muted : S.red,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CartLine extends StatelessWidget {
  final _Line line;
  final String Function(Cents) money;
  final VoidCallback onMinus;
  final VoidCallback onPlus;

  const _CartLine({
    super.key,
    required this.line,
    required this.money,
    required this.onMinus,
    required this.onPlus,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                line.product.name.resolve('it'),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              if (line.options.isNotEmpty)
                Text(
                  line.options.map((o) => o.name.resolve('it')).join(', '),
                  style: ST.small,
                ),
              Text(money(line.unitCents * line.quantity), style: ST.small),
            ],
          ),
        ),
        IconButton(
          key: const ValueKey('line-minus'),
          onPressed: onMinus,
          icon: const Icon(Icons.remove_circle_outline_rounded),
        ),
        Text(
          '${line.quantity}',
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
        ),
        IconButton(
          key: const ValueKey('line-plus'),
          onPressed: onPlus,
          icon: const Icon(Icons.add_circle_outline_rounded),
        ),
      ],
    );
  }
}

/// Picks the options of a product, respecting each group's min and max.
class _OptionsDialog extends StatefulWidget {
  final Product product;
  final List<ModifierGroup> groups;
  const _OptionsDialog({required this.product, required this.groups});

  @override
  State<_OptionsDialog> createState() => _OptionsDialogState();
}

class _OptionsDialogState extends State<_OptionsDialog> {
  late final Map<String, Set<String>> _picked = {
    for (final g in widget.groups)
      g.id: {
        for (final o in g.options)
          if (o.enabled && o.selectedByDefault) o.id,
      },
  };

  bool _valid(ModifierGroup g) {
    final n = _picked[g.id]!.length;
    return n >= g.minSelect && (g.maxSelect == 0 || n <= g.maxSelect);
  }

  void _toggle(ModifierGroup g, ModifierOption o) {
    setState(() {
      final set = _picked[g.id]!;
      if (g.maxSelect == 1) {
        set
          ..clear()
          ..add(o.id);
      } else if (!set.remove(o.id) &&
          (g.maxSelect == 0 || set.length < g.maxSelect)) {
        set.add(o.id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final money = context.staff.money;
    final ok = widget.groups.every(_valid);
    return AlertDialog(
      title: Text(widget.product.name.resolve('it'), style: ST.h2),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final g in widget.groups) ...[
                Row(
                  children: [
                    Expanded(child: Text(g.name.resolve('it'), style: ST.h3)),
                    Pill(
                      g.minSelect > 0
                          ? 'Obbligatorio'
                          : g.maxSelect > 1
                          ? 'Fino a ${g.maxSelect}'
                          : 'Facoltativo',
                      color: _valid(g) ? S.success : S.warning,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final o in g.options)
                      if (o.enabled)
                        FilterChip(
                          key: ValueKey('option-${o.id}'),
                          label: Text(
                            o.priceDeltaCents == 0
                                ? o.name.resolve('it')
                                : '${o.name.resolve('it')} '
                                      '+${money(o.priceDeltaCents)}',
                          ),
                          selected: _picked[g.id]!.contains(o.id),
                          onSelected: (_) => _toggle(g, o),
                        ),
                  ],
                ),
                const SizedBox(height: 18),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annulla'),
        ),
        FilledButton(
          key: const ValueKey('options-add'),
          onPressed: ok
              ? () => Navigator.pop(context, [
                  for (final g in widget.groups)
                    for (final o in g.options)
                      if (_picked[g.id]!.contains(o.id)) o,
                ])
              : null,
          child: const Text('Aggiungi'),
        ),
      ],
    );
  }
}

class _SmallRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _SmallRow(this.label, this.value, {super.key, this.color = S.inkSoft});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 2),
    child: Row(
      children: [
        Expanded(
          child: Text(label, style: ST.body.copyWith(color: color)),
        ),
        Text(
          value,
          style: ST.body.copyWith(color: color, fontWeight: FontWeight.w700),
        ),
      ],
    ),
  );
}

/// Discount code at the till: a field (typed, or filled by a reader) and,
/// once applied, the code with what it takes off.
class _CouponBox extends StatelessWidget {
  final DiscountCode? coupon;
  final DiscountResult? result;
  final TextEditingController controller;
  final bool checking;
  final String Function(Cents) money;
  final String? productName;
  final VoidCallback onApply;
  final VoidCallback onRemove;

  const _CouponBox({
    required this.coupon,
    required this.result,
    required this.controller,
    required this.checking,
    required this.money,
    required this.productName,
    required this.onApply,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final c = coupon;
    if (c == null) {
      return Row(
        children: [
          Expanded(
            child: TextField(
              key: const ValueKey('new-order-code'),
              controller: controller,
              textCapitalization: TextCapitalization.characters,
              onSubmitted: (_) => onApply(),
              decoration: const InputDecoration(
                isDense: true,
                hintText: 'Codice sconto',
                prefixIcon: Icon(Icons.local_offer_outlined),
              ),
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            key: const ValueKey('new-order-code-apply'),
            onPressed: checking ? null : onApply,
            child: checking
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Applica'),
          ),
        ],
      );
    }
    final ok = result?.ok ?? false;
    final color = ok ? S.success : S.warning;
    final what = switch (c.type) {
      DiscountType.percent => 'Sconto ${c.percent}%',
      DiscountType.amount => 'Sconto ${money(c.amountCents)}',
      DiscountType.freeProduct => '${productName ?? 'Prodotto'} in omaggio',
    };
    final problem = switch (result?.problem) {
      'minOrderNotReached' =>
        'Serve una spesa di almeno ${money(c.minOrderCents)}',
      'freeProductMissing' =>
        'Aggiungi ${productName ?? 'il prodotto'} all\'ordine',
      _ => null,
    };
    return Container(
      key: const ValueKey('new-order-coupon'),
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Icon(
            ok ? Icons.local_offer_rounded : Icons.info_outline_rounded,
            color: color,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  c.code,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                  ),
                ),
                Text(problem ?? what, style: ST.small),
              ],
            ),
          ),
          IconButton(
            key: const ValueKey('new-order-code-remove'),
            tooltip: 'Togli il codice',
            onPressed: onRemove,
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
    ).animate().fadeIn().scaleXY(begin: 0.95, curve: Curves.easeOutBack);
  }
}
