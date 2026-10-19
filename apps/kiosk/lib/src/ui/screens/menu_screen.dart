import 'package:flutter/material.dart';
import 'package:kiosk_core/kiosk_core.dart';

import '../scope.dart';
import '../widgets/allergens.dart';
import '../widgets/common.dart';
import '../widgets/net_image.dart';
import 'product_sheet.dart';

class MenuScreen extends StatelessWidget {
  const MenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final k = context.kiosk;
    return Scaffold(
      key: const ValueKey('menu'),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
              child: Row(
                children: [
                  const VenueLogo(size: 64),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      k.settings.venueName,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                  const LanguageBar(),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(width: 200, child: _CategoryRail()),
                  const VerticalDivider(width: 1),
                  const Expanded(child: _ProductGrid()),
                ],
              ),
            ),
            const _BottomBar(),
          ],
        ),
      ),
    );
  }

  static Future<void> openProduct(
    BuildContext context,
    Product p, {
    int? editIndex,
  }) {
    return Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: true,
        barrierColor: Colors.black54,
        pageBuilder: (_, _, _) => KioskScope(
          controller: context.kiosk,
          child: ProductSheet(product: p, editIndex: editIndex),
        ),
        transitionsBuilder: (_, anim, _, child) => SlideTransition(
          position: Tween(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
          child: child,
        ),
      ),
    );
  }
}

class _CategoryRail extends StatelessWidget {
  const _CategoryRail();

  @override
  Widget build(BuildContext context) {
    final k = context.kiosk;
    final t = context.t;
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      children: [
        for (final c in k.visibleCategories)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Material(
              color: c.id == k.selectedCategoryId
                  ? scheme.primaryContainer
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(20),
              child: InkWell(
                key: ValueKey('cat-${c.id}'),
                borderRadius: BorderRadius.circular(20),
                onTap: () => k.selectCategory(c.id),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      SizedBox.square(
                        dimension: 96,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: NetImage(c.imageUrl),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        t.text(c.name),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _ProductGrid extends StatelessWidget {
  const _ProductGrid();

  @override
  Widget build(BuildContext context) {
    final k = context.kiosk;
    final t = context.t;
    final category = k.visibleCategories
        .where((c) => c.id == k.selectedCategoryId)
        .firstOrNull;
    final products = k.productsInSelectedCategory;
    return LayoutBuilder(
      builder: (context, box) {
        final columns = (box.maxWidth / 280).floor().clamp(2, 5);
        return CustomScrollView(
          slivers: [
            if (category != null)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t.text(category.name),
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      if (!category.description.isEmpty)
                        Text(
                          t.text(category.description),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                    ],
                  ),
                ),
              ),
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverGrid.builder(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  childAspectRatio: 0.72,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                ),
                itemCount: products.length,
                itemBuilder: (_, i) => _ProductCard(product: products[i]),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ProductCard extends StatelessWidget {
  final Product product;
  const _ProductCard({required this.product});

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final k = context.kiosk;
    final p = product;
    return Card(
      key: ValueKey('product-${p.id}'),
      child: InkWell(
        onTap: p.soldOut ? null : () => MenuScreen.openProduct(context, p),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: NetImage(p.imageUrl)),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t.text(p.name),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.end,
                        spacing: 8,
                        children: [
                          Text(
                            context.money(p.priceCents),
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          if (k.settings.showCalories && p.kcal != null)
                            Text(
                              '${p.kcal} ${t('kcal')}',
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.black54,
                              ),
                            ),
                        ],
                      ),
                      if (p.tags.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        DietaryBadges(p.tags),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            if (p.soldOut)
              Positioned.fill(
                child: ColoredBox(
                  color: Colors.white70,
                  child: Center(
                    child: Transform.rotate(
                      angle: -0.2,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        color: Colors.black87,
                        child: Text(
                          t('soldOut').toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
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

class _BottomBar extends StatelessWidget {
  const _BottomBar();

  @override
  Widget build(BuildContext context) {
    final k = context.kiosk;
    final t = context.t;
    return Material(
      elevation: 12,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: Row(
          children: [
            OutlinedButton.icon(
              key: const ValueKey('cancel-order'),
              onPressed: () async {
                if (k.cart.isEmpty ||
                    await confirmDialog(context, t('cancelOrderQuestion'))) {
                  k.reset();
                }
              },
              icon: const Icon(Icons.close),
              label: Text(t('cancelOrder')),
            ),
            const Spacer(),
            if (k.itemCount > 0)
              Padding(
                padding: const EdgeInsets.only(right: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${k.itemCount} ${t('items')}',
                      style: const TextStyle(fontSize: 18),
                    ),
                    Text(
                      context.money(k.cartTotal),
                      key: const ValueKey('cart-total'),
                      style: const TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            FilledButton.icon(
              key: const ValueKey('view-order'),
              onPressed: k.itemCount == 0 ? null : k.openCart,
              icon: Badge.count(
                count: k.itemCount,
                isLabelVisible: k.itemCount > 0,
                child: const Icon(Icons.shopping_cart, size: 32),
              ),
              label: Text(t('viewOrder')),
            ),
          ],
        ),
      ),
    );
  }
}
