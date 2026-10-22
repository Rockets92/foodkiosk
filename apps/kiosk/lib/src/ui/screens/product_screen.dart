import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:kiosk_core/kiosk_core.dart';

import '../../state/cart.dart';
import '../scope.dart';
import '../theme.dart';
import '../widgets/allergens.dart';
import '../widgets/cart_flight.dart';
import '../widgets/common.dart';
import '../widgets/net_image.dart';
import '../widgets/pressable.dart';

/// Product page: big picture, description, allergens, illustrated choices
/// and quantity. Used to add a new item and to edit a cart line.
class ProductScreen extends StatefulWidget {
  final Product product;
  final int? editIndex;

  const ProductScreen({super.key, required this.product, this.editIndex});

  @override
  State<ProductScreen> createState() => _ProductScreenState();
}

class _ProductScreenState extends State<ProductScreen> {
  final _imageKey = GlobalKey();
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
    if (edit != null && edit < k.cart.length) {
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
      final box = _imageKey.currentContext?.findRenderObject() as RenderBox?;
      if (box != null && box.attached) {
        CartFlight.launch(
          context,
          from: box.localToGlobal(Offset.zero) & box.size,
          image: widget.product.imageUrl,
        );
      }
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
    final heroHeight = (size.height * 0.36).clamp(280.0, 680.0);

    return Scaffold(
      key: const ValueKey('product-sheet'),
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Container(
                  height: heroHeight,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [K.tintFor(p.categoryId), Colors.white],
                    ),
                  ),
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(60, 40, 60, 0),
                      child: Hero(
                        tag: 'product-image-${p.id}',
                        child: NetImage(p.imageUrl, key: _imageKey),
                      ),
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(40, 8, 40, 200),
                sliver: SliverList.list(
                  children: [
                    if (!p.badge.isEmpty)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: K.accent,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            t.text(p.badge),
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                    Text(
                      t.text(p.name),
                      style: KText.display.copyWith(fontSize: 52),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Text(
                          context.money(p.priceCents),
                          style: KText.h2.copyWith(color: K.primary),
                        ),
                        const SizedBox(width: 18),
                        if (k.settings.showCalories && p.kcal != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: K.background,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Text(
                              '${p.kcal} ${t('kcal')}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: K.inkSoft,
                              ),
                            ),
                          ),
                        const SizedBox(width: 12),
                        if (p.tags.isNotEmpty) DietaryBadges(p.tags),
                      ],
                    ),
                    if (!p.description.isEmpty) ...[
                      const SizedBox(height: 14),
                      Text(t.text(p.description), style: KText.body),
                    ],
                    if (k.settings.showAllergens) ...[
                      const SizedBox(height: 28),
                      _Section(
                        title: t('allergens'),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AnimatedSize(
                              duration: K.medium,
                              alignment: Alignment.topLeft,
                              child: AllergenRow(allergens),
                            ),
                            const SizedBox(height: 10),
                            Text(t('allergenDisclaimer'), style: KText.small),
                          ],
                        ),
                      ),
                    ],
                    for (final (i, g) in _groups.indexed)
                      _groupSection(g)
                          .animate()
                          .fadeIn(delay: (150 + 80 * i).ms, duration: 350.ms)
                          .slideY(begin: 0.1),
                  ],
                ),
              ),
            ],
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: RoundButton(
                key: const ValueKey('product-close'),
                icon: Icons.arrow_back_rounded,
                size: 72,
                onTap: () => Navigator.of(context).pop(),
              ),
            ),
          ),
          Positioned(left: 0, right: 0, bottom: 0, child: _footer(total)),
        ],
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
    final illustrated = g.options.every((o) => o.imageUrl != null);
    return Padding(
      padding: const EdgeInsets.only(top: 36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t.text(g.name), style: KText.h2),
                    Text(hint, style: KText.small),
                  ],
                ),
              ),
              if (g.required)
                AnimatedContainer(
                  duration: K.medium,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: ok
                        ? const Color(0xFFDDF3E4)
                        : const Color(0xFFFFE9C7),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        ok ? Icons.check_circle_rounded : Icons.error_rounded,
                        size: 20,
                        color: ok ? K.success : const Color(0xFFB86E00),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        t('required'),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: ok ? K.success : const Color(0xFFB86E00),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (illustrated)
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                for (final o in g.options)
                  _OptionCard(
                    key: ValueKey('option-${o.id}'),
                    option: o,
                    selected: _selected.contains(o.id),
                    onTap: () => _toggle(g, o),
                  ),
              ],
            )
          else
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final o in g.options)
                  _OptionChip(
                    key: ValueKey('option-${o.id}'),
                    option: o,
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
    return Container(
      padding: const EdgeInsets.fromLTRB(32, 22, 32, 34),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 30,
            offset: Offset(0, -6),
          ),
        ],
        borderRadius: BorderRadius.vertical(top: Radius.circular(K.radius)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: K.background,
              borderRadius: BorderRadius.circular(44),
            ),
            child: Row(
              children: [
                RoundButton(
                  key: const ValueKey('qty-minus'),
                  icon: Icons.remove_rounded,
                  size: 68,
                  onTap: _quantity > 1
                      ? () => setState(() => _quantity--)
                      : null,
                ),
                SizedBox(
                  width: 70,
                  child: AnimatedSwitcher(
                    duration: K.fast,
                    transitionBuilder: (c, a) =>
                        ScaleTransition(scale: a, child: c),
                    child: Text(
                      '$_quantity',
                      key: ValueKey(_quantity),
                      textAlign: TextAlign.center,
                      style: KText.h2,
                    ),
                  ),
                ),
                RoundButton(
                  key: const ValueKey('qty-plus'),
                  icon: Icons.add_rounded,
                  size: 68,
                  color: K.ink,
                  foreground: Colors.white,
                  onTap: _quantity < k.maxQuantity
                      ? () => setState(() => _quantity++)
                      : null,
                ),
              ],
            ),
          ),
          const SizedBox(width: 22),
          Expanded(
            child: KButton(
              key: const ValueKey('add-to-cart'),
              label: widget.editIndex == null ? t('add') : t('update'),
              icon: Icons.shopping_bag_rounded,
              height: 96,
              expand: true,
              onTap: _valid ? _confirm : null,
              trailing: AnimatedAmount(
                context.money(total),
                style: KText.button.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final Widget child;
  const _Section({required this.title, required this.child});

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: K.background,
      borderRadius: BorderRadius.circular(K.radius),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: KText.h3),
        const SizedBox(height: 14),
        child,
      ],
    ),
  );
}

class _OptionCard extends StatelessWidget {
  final ModifierOption option;
  final bool selected;
  final VoidCallback onTap;

  const _OptionCard({
    super.key,
    required this.option,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return Pressable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: K.medium,
        curve: Curves.easeOutCubic,
        width: 210,
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
        decoration: BoxDecoration(
          color: selected ? K.primaryFaint : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: selected ? K.primary : K.line,
            width: selected ? 4 : 2,
          ),
          boxShadow: selected ? K.shadow : null,
        ),
        child: Stack(
          children: [
            Column(
              children: [
                AnimatedScale(
                  scale: selected ? 1.06 : 1,
                  duration: K.medium,
                  curve: Curves.easeOutBack,
                  child: SizedBox(
                    height: 130,
                    child: NetImage(option.imageUrl),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  t.text(option.name),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  option.priceDeltaCents == 0
                      ? ' '
                      : '+${context.money(option.priceDeltaCents)}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: K.inkSoft,
                  ),
                ),
              ],
            ),
            Positioned(
              top: 0,
              right: 0,
              child: AnimatedScale(
                scale: selected ? 1 : 0,
                duration: K.medium,
                curve: Curves.elasticOut,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: K.primary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OptionChip extends StatelessWidget {
  final ModifierOption option;
  final bool selected;
  final bool radio;
  final VoidCallback onTap;

  const _OptionChip({
    super.key,
    required this.option,
    required this.selected,
    required this.radio,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return Pressable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: K.medium,
        curve: Curves.easeOutCubic,
        constraints: const BoxConstraints(minHeight: 72),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? K.ink : Colors.white,
          borderRadius: BorderRadius.circular(36),
          border: Border.all(color: selected ? K.ink : K.line, width: 2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSwitcher(
              duration: K.fast,
              child: Icon(
                selected
                    ? Icons.check_circle_rounded
                    : (radio
                          ? Icons.radio_button_unchecked_rounded
                          : Icons.add_circle_outline_rounded),
                key: ValueKey(selected),
                color: selected ? K.accent : K.muted,
                size: 28,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              t.text(option.name),
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : K.ink,
              ),
            ),
            if (option.priceDeltaCents != 0) ...[
              const SizedBox(width: 8),
              Text(
                '+${context.money(option.priceDeltaCents)}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white70 : K.inkSoft,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
