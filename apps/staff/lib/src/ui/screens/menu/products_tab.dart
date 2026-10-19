import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:kiosk_core/kiosk_core.dart';

import '../../../session.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import 'product_editor.dart';

/// Products by category, with quick "active" / "available" switches.
class ProductsTab extends StatefulWidget {
  const ProductsTab({super.key});

  @override
  State<ProductsTab> createState() => _ProductsTabState();
}

class _ProductsTabState extends State<ProductsTab> {
  String? _category;
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final menu = context.staff.menu;
    final q = _query.trim().toLowerCase();
    final products = [
      for (final p in menu.products)
        if ((_category == null || p.categoryId == _category) &&
            (q.isEmpty ||
                p.name.values.values.any((n) => n.toLowerCase().contains(q))))
          p,
    ];
    final categoryName = {
      for (final c in menu.categories) c.id: c.name.resolve('it'),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 8, 28, 12),
          child: Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _CategoryChip(
                        label: 'Tutti (${menu.products.length})',
                        selected: _category == null,
                        onTap: () => setState(() => _category = null),
                      ),
                      for (final c in menu.categories)
                        _CategoryChip(
                          key: ValueKey('filter-${c.id}'),
                          label:
                              '${c.name.resolve('it')} '
                              '(${menu.productsIn(c.id).length})',
                          selected: _category == c.id,
                          onTap: () => setState(() => _category = c.id),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 260,
                child: TextField(
                  key: const ValueKey('product-search'),
                  onChanged: (v) => setState(() => _query = v),
                  decoration: const InputDecoration(
                    hintText: 'Cerca prodotto',
                    prefixIcon: Icon(Icons.search_rounded),
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: products.isEmpty
              ? EmptyState(
                  icon: Icons.fastfood_outlined,
                  title: q.isEmpty
                      ? 'Nessun prodotto in questa categoria'
                      : 'Nessun prodotto trovato',
                  action: FilledButton.icon(
                    onPressed: () =>
                        editProduct(context, categoryId: _category),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Nuovo prodotto'),
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.fromLTRB(28, 4, 28, 28),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 380,
                    mainAxisExtent: 200,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: products.length,
                  itemBuilder: (_, i) =>
                      _ProductTile(
                            product: products[i],
                            category: categoryName[products[i].categoryId],
                          )
                          .animate()
                          .fadeIn(delay: (20 * i.clamp(0, 15)).ms)
                          .slideY(begin: 0.06),
                ),
        ),
      ],
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _CategoryChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: S.ink,
      labelStyle: TextStyle(
        color: selected ? Colors.white : S.ink,
        fontWeight: FontWeight.w600,
      ),
      showCheckmark: false,
    ),
  );
}

class _ProductTile extends StatelessWidget {
  final Product product;
  final String? category;
  const _ProductTile({required this.product, this.category});

  Future<void> _patch(
    BuildContext context, {
    bool? enabled,
    bool? soldOut,
  }) async {
    final session = context.staffRead;
    final ok = await guard(
      context,
      () => session.api.patchProduct(
        product.id,
        enabled: enabled,
        soldOut: soldOut,
      ),
    );
    if (ok != null) await session.reloadMenu();
  }

  @override
  Widget build(BuildContext context) {
    final p = product;
    final session = context.staff;
    final dimmed = !p.enabled;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(S.radius),
      elevation: 0,
      child: InkWell(
        key: ValueKey('product-tile-${p.id}'),
        borderRadius: BorderRadius.circular(S.radius),
        onTap: () => editProduct(context, product: p),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(S.radius),
            boxShadow: S.shadow,
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Opacity(
                      opacity: dimmed ? 0.4 : 1,
                      child: ServerImage(p.imageUrl, size: 92, radius: 16),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            p.name.resolve('it'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: ST.h3.copyWith(
                              color: dimmed ? S.muted : S.ink,
                            ),
                          ),
                          if (category != null)
                            Text(
                              category!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: ST.small,
                            ),
                          const SizedBox(height: 4),
                          Text(
                            session.money(p.priceCents),
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 18,
                              color: S.red,
                            ),
                          ),
                          const SizedBox(height: 4),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Wrap(
                              spacing: 4,
                              children: [
                                if (!p.badge.isEmpty)
                                  Pill(p.badge.resolve('it'), color: S.warning),
                                if (p.soldOut)
                                  const Pill('Esaurito', color: S.red),
                                if (!p.enabled)
                                  const Pill('Nascosto', color: S.muted),
                                if (p.trackStock)
                                  Pill('Scorte: ${p.stockQty}', color: S.info),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: _MiniSwitch(
                      key: ValueKey('product-enabled-${p.id}'),
                      label: 'Attivo',
                      value: p.enabled,
                      onChanged: (v) => _patch(context, enabled: v),
                    ),
                  ),
                  Flexible(
                    child: _MiniSwitch(
                      key: ValueKey('product-available-${p.id}'),
                      label: 'Disponibile',
                      value: !p.soldOut,
                      onChanged: (v) => _patch(context, soldOut: !v),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniSwitch extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _MiniSwitch({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => InkWell(
    borderRadius: BorderRadius.circular(12),
    onTap: () => onChanged(!value),
    child: Padding(
      padding: const EdgeInsets.only(left: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: ST.small,
            ),
          ),
          Transform.scale(
            scale: 0.8,
            child: Switch(value: value, onChanged: onChanged),
          ),
        ],
      ),
    ),
  );
}
