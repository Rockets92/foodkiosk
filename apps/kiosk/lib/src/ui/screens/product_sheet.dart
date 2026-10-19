import 'package:flutter/material.dart';
import 'package:kiosk_core/kiosk_core.dart';

import '../../state/cart.dart';
import '../scope.dart';
import '../widgets/allergens.dart';
import '../widgets/net_image.dart';

/// Product detail: photo, description, allergens, options and quantity.
/// Used both to add a new item and to edit a cart line ([editIndex]).
class ProductSheet extends StatefulWidget {
  final Product product;
  final int? editIndex;

  const ProductSheet({super.key, required this.product, this.editIndex});

  @override
  State<ProductSheet> createState() => _ProductSheetState();
}

class _ProductSheetState extends State<ProductSheet> {
  late Set<String> _selected;
  late int _quantity;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    final k = context.kiosk;
    final edit = widget.editIndex;
    if (edit != null) {
      _selected = k.cart[edit].optionIds.toSet();
      _quantity = k.cart[edit].quantity;
    } else {
      _selected = defaultOptions(k.menu, widget.product).toSet();
      _quantity = 1;
    }
  }

  List<ModifierGroup> get _groups => [
    for (final gid in widget.product.modifierGroupIds)
      if (context.kiosk.menu.modifierGroup(gid) case final g?
          when g.options.isNotEmpty)
        g,
  ];

  void _toggle(ModifierGroup group, ModifierOption option) {
    setState(() {
      final inGroup = group.options.map((o) => o.id).toSet();
      if (group.maxSelect == 1) {
        _selected.removeAll(inGroup);
        _selected.add(option.id);
      } else if (_selected.contains(option.id)) {
        _selected.remove(option.id);
      } else {
        final count = _selected.where(inGroup.contains).length;
        if (group.maxSelect == 0 || count < group.maxSelect) {
          _selected.add(option.id);
        }
      }
    });
  }

  bool get _valid => _groups.every((g) => groupSatisfied(g, _selected));

  List<String> get _orderedSelection => [
    for (final g in _groups)
      for (final o in g.options)
        if (_selected.contains(o.id)) o.id,
  ];

  void _confirm() {
    final k = context.kiosk;
    final line = CartLine(
      productId: widget.product.id,
      optionIds: _orderedSelection,
      quantity: _quantity,
    );
    if (widget.editIndex case final i?) {
      k.replaceLine(i, line);
    } else {
      k.addToCart(line);
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final k = context.kiosk;
    final t = context.t;
    final p = widget.product;
    final total = unitPrice(k.menu, p, _selected) * _quantity;
    final allergens = k.menu.allergensFor(p, _selected);
    final size = MediaQuery.sizeOf(context);

    return Align(
      alignment: Alignment.bottomCenter,
      child: Material(
        key: const ValueKey('product-sheet'),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: size.height * 0.9),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  children: [
                    Stack(
                      children: [
                        SizedBox(
                          height: (size.height * 0.28).clamp(200, 480),
                          width: double.infinity,
                          child: NetImage(p.imageUrl),
                        ),
                        Positioned(
                          top: 16,
                          right: 16,
                          child: IconButton.filledTonal(
                            iconSize: 36,
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.close),
                          ),
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.all(28),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            t.text(p.name),
                            style: Theme.of(context).textTheme.headlineMedium
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Text(
                                context.money(p.priceCents),
                                style: TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w800,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                              const SizedBox(width: 16),
                              if (k.settings.showCalories && p.kcal != null)
                                Text(
                                  '${p.kcal} ${t('kcal')}',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    color: Colors.black54,
                                  ),
                                ),
                            ],
                          ),
                          if (!p.description.isEmpty) ...[
                            const SizedBox(height: 12),
                            Text(
                              t.text(p.description),
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ],
                          if (p.tags.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            DietaryBadges(p.tags),
                          ],
                          if (k.settings.showAllergens) ...[
                            const SizedBox(height: 20),
                            Text(
                              t('allergens'),
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            AllergenChips(allergens),
                            const SizedBox(height: 6),
                            Text(
                              t('allergenDisclaimer'),
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.black54,
                              ),
                            ),
                          ],
                          for (final g in _groups) _groupSection(g),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              _footer(total),
            ],
          ),
        ),
      ),
    );
  }

  Widget _groupSection(ModifierGroup g) {
    final t = context.t;
    final hint = switch ((g.minSelect, g.maxSelect)) {
      (1, 1) => t('chooseOne'),
      (0, 0) => t('chooseAny'),
      (0, final max) => t('chooseUpTo', args: {'n': max}),
      (final min, _) => t('chooseAtLeast', args: {'n': min}),
    };
    final ok = groupSatisfied(g, _selected);
    return Padding(
      padding: const EdgeInsets.only(top: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                t.text(g.name),
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 12),
              Text(hint, style: const TextStyle(fontSize: 16)),
              const Spacer(),
              if (g.required)
                Chip(
                  label: Text(t('required')),
                  backgroundColor: ok
                      ? Colors.green.shade100
                      : Colors.orange.shade100,
                  avatar: Icon(
                    ok ? Icons.check : Icons.priority_high,
                    size: 18,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final o in g.options)
                _OptionTile(
                  key: ValueKey('option-${o.id}'),
                  label: t.text(o.name),
                  price: o.priceDeltaCents == 0
                      ? null
                      : '+${context.money(o.priceDeltaCents)}',
                  selected: _selected.contains(o.id),
                  radio: g.maxSelect == 1,
                  onTap: () => _toggle(g, o),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _footer(int total) {
    final t = context.t;
    final k = context.kiosk;
    return Material(
      elevation: 8,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 16, 28, 28),
        child: Row(
          children: [
            IconButton.outlined(
              key: const ValueKey('qty-minus'),
              iconSize: 36,
              onPressed: _quantity > 1
                  ? () => setState(() => _quantity--)
                  : null,
              icon: const Icon(Icons.remove),
            ),
            SizedBox(
              width: 72,
              child: Text(
                '$_quantity',
                key: const ValueKey('qty'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            IconButton.outlined(
              key: const ValueKey('qty-plus'),
              iconSize: 36,
              onPressed: _quantity < k.maxQuantity
                  ? () => setState(() => _quantity++)
                  : null,
              icon: const Icon(Icons.add),
            ),
            const SizedBox(width: 24),
            Expanded(
              child: FilledButton(
                key: const ValueKey('add-to-cart'),
                onPressed: _valid ? _confirm : null,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(widget.editIndex == null ? t('add') : t('update')),
                    Text(context.money(total)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  final String label;
  final String? price;
  final bool selected;
  final bool radio;
  final VoidCallback onTap;

  const _OptionTile({
    super.key,
    required this.label,
    required this.price,
    required this.selected,
    required this.radio,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        constraints: const BoxConstraints(minWidth: 200, minHeight: 72),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? scheme.primaryContainer : scheme.surface,
          border: Border.all(
            color: selected ? scheme.primary : Colors.black26,
            width: selected ? 3 : 1.5,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              radio
                  ? (selected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off)
                  : (selected
                        ? Icons.check_box
                        : Icons.check_box_outline_blank),
              color: scheme.primary,
              size: 30,
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (price != null)
                  Text(
                    price!,
                    style: const TextStyle(fontSize: 16, color: Colors.black54),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
