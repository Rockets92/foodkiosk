import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:kiosk_core/kiosk_core.dart';

import '../../state/cart.dart';
import '../scope.dart';
import '../theme.dart';
import '../widgets/allergens.dart';
import '../widgets/cart_flight.dart';
import '../widgets/common.dart';
import '../widgets/coupon.dart';
import '../widgets/net_image.dart';
import '../widgets/pressable.dart';
import 'product_screen.dart';

class MenuScreen extends StatelessWidget {
  const MenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final landscape = MediaQuery.sizeOf(context).aspectRatio > 1;
    return Scaffold(
      key: const ValueKey('menu'),
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            Column(
              children: [
                const _Header(),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        width: landscape ? 200 : 210,
                        child: const _CategoryRail(),
                      ),
                      const Expanded(child: _ProductArea()),
                    ],
                  ),
                ),
              ],
            ),
            const Positioned(left: 0, right: 0, bottom: 0, child: OrderBar()),
          ],
        ),
      ),
    );
  }

  /// Opens the product page; [editIndex] edits an existing cart line.
  static Future<void> openProduct(
    BuildContext context,
    Product p, {
    int? editIndex,
  }) {
    return Navigator.of(context).push(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 450),
        reverseTransitionDuration: const Duration(milliseconds: 350),
        pageBuilder: (_, _, _) =>
            ProductScreen(product: p, editIndex: editIndex),
        transitionsBuilder: (_, anim, _, child) => FadeTransition(
          opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
          child: SlideTransition(
            position: Tween(begin: const Offset(0, 0.06), end: Offset.zero)
                .animate(
                  CurvedAnimation(parent: anim, curve: Curves.easeOutCubic),
                ),
            child: child,
          ),
        ),
      ),
    );
  }

  /// Adds a product straight from its card when it needs no choices,
  /// otherwise opens it.
  static void quickAdd(BuildContext context, Product p, GlobalKey imageKey) {
    final k = context.kiosk;
    final needsChoice = p.modifierGroupIds
        .map(k.menu.modifierGroup)
        .any((g) => g != null && g.required);
    if (needsChoice) {
      openProduct(context, p);
      return;
    }
    k.addToCart(
      CartLine(productId: p.id, optionIds: defaultOptions(k.menu, p)),
    );
    final box = imageKey.currentContext?.findRenderObject() as RenderBox?;
    if (box != null) {
      CartFlight.launch(
        context,
        from: box.localToGlobal(Offset.zero) & box.size,
        image: p.imageUrl,
      );
    }
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final k = context.kiosk;
    final t = context.t;
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 18, 28, 14),
      child: Row(
        children: [
          const VenueLogo(size: 72),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  k.settings.venueName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: KText.h3.copyWith(fontWeight: FontWeight.w800),
                ),
                Pressable(
                  key: const ValueKey('change-mode'),
                  onTap: () => k.start(),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        k.serviceMode == ServiceMode.eatIn
                            ? Icons.restaurant_rounded
                            : Icons.shopping_bag_rounded,
                        size: 20,
                        color: K.red,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        t(k.serviceMode.name),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: K.red,
                        ),
                      ),
                      const Icon(Icons.expand_more_rounded, color: K.red),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (k.discountsEnabled) ...[
            const _CouponButton(),
            const SizedBox(width: 14),
          ],
          const LanguageSwitcher(),
        ],
      ),
    );
  }
}

/// "Coupon" pill in the header: opens the code sheet, or shows the code
/// already applied.
class _CouponButton extends StatelessWidget {
  const _CouponButton();

  @override
  Widget build(BuildContext context) {
    final k = context.kiosk;
    final applied = k.coupon != null;
    return Pressable(
      key: const ValueKey('menu-coupon'),
      onTap: applied ? k.openCart : () => CouponSheet.show(context),
      child: AnimatedContainer(
        duration: K.medium,
        padding: const EdgeInsets.fromLTRB(14, 12, 20, 12),
        decoration: BoxDecoration(
          color: applied ? const Color(0xFF14A05A) : Colors.white,
          borderRadius: BorderRadius.circular(40),
          boxShadow: K.shadow,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              applied ? Icons.verified_rounded : Icons.local_offer_rounded,
              color: applied ? Colors.white : K.red,
              size: 26,
            ),
            const SizedBox(width: 8),
            Text(
              applied ? k.coupon!.code : 'Coupon',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: applied ? Colors.white : K.ink,
              ),
            ),
          ],
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
    final cats = k.visibleCategories;
    return Container(
      margin: const EdgeInsets.only(left: 16, bottom: 130),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(K.radius),
        boxShadow: K.shadow,
      ),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        itemCount: cats.length,
        itemBuilder: (_, i) {
          final c = cats[i];
          final selected = c.id == k.selectedCategoryId;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Pressable(
              key: ValueKey('cat-${c.id}'),
              onTap: () => k.selectCategory(c.id),
              child: AnimatedContainer(
                duration: K.medium,
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.fromLTRB(8, 12, 8, 14),
                decoration: BoxDecoration(
                  color: selected ? K.red : Colors.transparent,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: selected
                      ? [
                          BoxShadow(
                            color: K.red.withValues(alpha: 0.35),
                            blurRadius: 18,
                            offset: const Offset(0, 8),
                          ),
                        ]
                      : null,
                ),
                child: Column(
                  children: [
                    AnimatedScale(
                      scale: selected ? 1.08 : 1,
                      duration: K.medium,
                      curve: Curves.easeOutBack,
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          color: selected
                              ? Colors.white
                              : K.tintFor(c.id).withValues(alpha: 0.8),
                          shape: BoxShape.circle,
                        ),
                        padding: const EdgeInsets.all(12),
                        child: NetImage(c.imageUrl),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      t.text(c.name),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: selected ? Colors.white : K.ink,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ).animate().fadeIn(delay: (60 * i).ms).slideX(begin: -0.2);
        },
      ),
    );
  }
}

class _ProductArea extends StatelessWidget {
  const _ProductArea();

  @override
  Widget build(BuildContext context) {
    final k = context.kiosk;
    final t = context.t;
    final category = k.visibleCategories
        .where((c) => c.id == k.selectedCategoryId)
        .firstOrNull;
    if (category == null) return const SizedBox();
    final products = k.productsInSelectedCategory;
    final promo = products
        .where((p) => !p.badge.isEmpty && !p.soldOut)
        .firstOrNull;
    return LayoutBuilder(
      builder: (context, box) {
        final columns = (box.maxWidth / 290).floor().clamp(2, 5);
        return CustomScrollView(
          key: PageStorageKey('cat-${category.id}'),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 6, 24, 0),
              sliver: SliverToBoxAdapter(
                child:
                    Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (promo != null) _PromoBanner(product: promo),
                            const SizedBox(height: 8),
                            Text(t.text(category.name), style: KText.h1),
                            if (!category.description.isEmpty)
                              Text(
                                t.text(category.description),
                                style: KText.body,
                              ),
                          ],
                        )
                        .animate(key: ValueKey('head-${category.id}-${t.lang}'))
                        .fadeIn(duration: 300.ms)
                        .slideY(begin: 0.08),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 170),
              sliver: SliverGrid.builder(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  childAspectRatio: 0.66,
                  mainAxisSpacing: 22,
                  crossAxisSpacing: 22,
                ),
                itemCount: products.length,
                itemBuilder: (_, i) => ProductCard(product: products[i])
                    .animate(key: ValueKey('${category.id}-${products[i].id}'))
                    .fadeIn(delay: (50 * i).ms, duration: 350.ms)
                    .slideY(begin: 0.15, curve: Curves.easeOutCubic)
                    .scaleXY(begin: 0.95, curve: Curves.easeOutCubic),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _PromoBanner extends StatelessWidget {
  final Product product;
  const _PromoBanner({required this.product});

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return Pressable(
      key: ValueKey('promo-${product.id}'),
      onTap: () => MenuScreen.openProduct(context, product),
      child:
          Container(
                height: 250,
                margin: const EdgeInsets.only(bottom: 18),
                decoration: BoxDecoration(
                  gradient: K.heroGradient,
                  borderRadius: BorderRadius.circular(K.radius),
                  boxShadow: K.shadow,
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  children: [
                    Positioned(
                      right: -60,
                      top: -60,
                      child: Container(
                        width: 360,
                        height: 360,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    Positioned(
                      right: 10,
                      top: 0,
                      bottom: 0,
                      width: 280,
                      child: NetImage(product.imageUrl)
                          .animate(onPlay: (c) => c.repeat(reverse: true))
                          .moveY(
                            begin: -6,
                            end: 6,
                            duration: 1800.ms,
                            curve: Curves.easeInOut,
                          ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(32, 28, 300, 28),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: K.yellow,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              t.text(product.badge).toUpperCase(),
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                                color: K.ink,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            t.text(product.name),
                            maxLines: 2,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 34,
                              height: 1.05,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Text(
                                context.money(product.priceCents),
                                style: const TextStyle(
                                  color: K.yellow,
                                  fontSize: 28,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(width: 16),
                              const Icon(
                                Icons.arrow_forward_rounded,
                                color: Colors.white,
                                size: 30,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              )
              .animate(onPlay: (c) => c.repeat())
              .shimmer(
                delay: 3.seconds,
                duration: 1500.ms,
                color: Colors.white24,
              ),
    );
  }
}

class ProductCard extends StatefulWidget {
  final Product product;
  const ProductCard({super.key, required this.product});

  @override
  State<ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<ProductCard> {
  final _imageKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final k = context.kiosk;
    final p = widget.product;
    final count = k.cart
        .where((l) => l.productId == p.id)
        .fold(0, (s, l) => s + l.quantity);
    return Pressable(
      key: ValueKey('product-${p.id}'),
      onTap: p.soldOut ? null : () => MenuScreen.openProduct(context, p),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(K.radius),
          boxShadow: K.shadow,
          border: count > 0 ? Border.all(color: K.red, width: 3) : null,
        ),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 14, 10, 0),
                    child: ColorFiltered(
                      colorFilter: p.soldOut
                          ? const ColorFilter.matrix([
                              0.33, 0.33, 0.33, 0, 0, //
                              0.33, 0.33, 0.33, 0, 0,
                              0.33, 0.33, 0.33, 0, 0,
                              0, 0, 0, 0.5, 0,
                            ])
                          : const ColorFilter.mode(
                              Colors.transparent,
                              BlendMode.dst,
                            ),
                      child: Hero(
                        tag: 'product-image-${p.id}',
                        child: ImageDisc(
                          key: _imageKey,
                          image: p.imageUrl,
                          color: K.tintFor(p.categoryId),
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 8, 14, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Fixed-height text block so every card in a row
                      // gets the same image size.
                      SizedBox(
                        height: 48,
                        child: Align(
                          alignment: Alignment.bottomLeft,
                          child: Text(
                            t.text(p.name),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 20,
                              height: 1.15,
                              fontWeight: FontWeight.w700,
                              color: K.ink,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(
                        height: 54,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 2),
                            if (k.settings.showCalories && p.kcal != null)
                              Text(
                                '${p.kcal} ${t('kcal')}',
                                style: KText.small,
                              ),
                            if (p.tags.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                physics: const NeverScrollableScrollPhysics(),
                                child: DietaryBadges(p.tags),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              context.money(p.priceCents),
                              style: KText.price,
                            ),
                          ),
                          if (!p.soldOut)
                            RoundButton(
                              key: ValueKey('quick-add-${p.id}'),
                              icon: Icons.add_rounded,
                              size: 54,
                              color: K.red,
                              foreground: Colors.white,
                              onTap: () =>
                                  MenuScreen.quickAdd(context, p, _imageKey),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (!p.badge.isEmpty && !p.soldOut)
              Positioned(
                top: 14,
                left: 14,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: K.yellow,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    t.text(p.badge),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: K.ink,
                    ),
                  ),
                ),
              ),
            if (count > 0)
              Positioned(
                top: 12,
                right: 12,
                child:
                    Container(
                          width: 40,
                          height: 40,
                          alignment: Alignment.center,
                          decoration: const BoxDecoration(
                            color: K.red,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '$count',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 18,
                            ),
                          ),
                        )
                        .animate(key: ValueKey(count))
                        .scale(duration: 400.ms, curve: Curves.elasticOut),
              ),
            if (p.soldOut)
              Positioned.fill(
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: K.ink,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      t('soldOut').toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
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

/// Floating order summary at the bottom of the menu. It is the landing
/// spot of the "fly to cart" animation.
class OrderBar extends StatefulWidget {
  const OrderBar({super.key});

  @override
  State<OrderBar> createState() => _OrderBarState();
}

class _OrderBarState extends State<OrderBar>
    with SingleTickerProviderStateMixin {
  late final _bump = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 500),
  );

  @override
  void initState() {
    super.initState();
    CartFlight.landed.addListener(_onLanded);
  }

  void _onLanded() => _bump.forward(from: 0);

  @override
  void dispose() {
    CartFlight.landed.removeListener(_onLanded);
    _bump.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final k = context.kiosk;
    final t = context.t;
    final empty = k.itemCount == 0;
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [K.background.withValues(alpha: 0), K.background],
          stops: const [0, 0.35],
        ),
      ),
      child: Row(
        children: [
          RoundButton(
            key: const ValueKey('cancel-order'),
            icon: Icons.close_rounded,
            size: 84,
            onTap: () async {
              if (k.cart.isEmpty ||
                  await confirmDialog(context, t('cancelOrderQuestion'))) {
                k.reset();
              }
            },
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Pressable(
              key: const ValueKey('view-order'),
              onTap: empty ? null : k.openCart,
              pressedScale: 0.98,
              child: AnimatedContainer(
                duration: K.medium,
                curve: Curves.easeOutCubic,
                height: 96,
                padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
                decoration: BoxDecoration(
                  color: empty ? Colors.white : K.ink,
                  borderRadius: BorderRadius.circular(48),
                  boxShadow: K.shadowStrong,
                ),
                child: Row(
                  children: [
                    AnimatedBuilder(
                      animation: _bump,
                      builder: (_, child) => Transform.scale(
                        scale:
                            1 +
                            0.35 *
                                Curves.elasticOut
                                    .transform(_bump.value)
                                    .clamp(0, 1) *
                                (1 - _bump.value),
                        child: child,
                      ),
                      child: Badge(
                        isLabelVisible: !empty,
                        backgroundColor: K.red,
                        offset: const Offset(-8, -8),
                        label: Text(
                          '${k.itemCount}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        child: Container(
                          key: CartFlight.targetKey,
                          width: 72,
                          height: 72,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: empty ? K.background : K.yellow,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.shopping_bag_rounded,
                            size: 38,
                            color: empty ? K.muted : K.ink,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 18),
                    Expanded(
                      child: empty
                          ? Text(
                              t('emptyCartHint'),
                              style: KText.body.copyWith(color: K.muted),
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      t('yourOrder'),
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    if (k.discountCents > 0) ...[
                                      const SizedBox(width: 10),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF14A05A),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Text(
                                          '-${context.money(k.discountCents)}',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ).animate().scale(
                                        curve: Curves.easeOutBack,
                                      ),
                                    ],
                                  ],
                                ),
                                AnimatedAmount(
                                  context.money(k.payableTotal),
                                  key: const ValueKey('cart-total'),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 30,
                                    fontWeight: FontWeight.w900,
                                    height: 1.1,
                                  ),
                                ),
                              ],
                            ),
                    ),
                    if (!empty)
                      Container(
                        height: 76,
                        padding: const EdgeInsets.symmetric(horizontal: 28),
                        decoration: BoxDecoration(
                          color: K.yellow,
                          borderRadius: BorderRadius.circular(38),
                        ),
                        child: Row(
                          children: [
                            Text(
                              t('viewOrder'),
                              style: KText.button.copyWith(color: K.ink),
                            ),
                            const SizedBox(width: 8),
                            const Icon(
                              Icons.arrow_forward_rounded,
                              color: K.ink,
                              size: 30,
                            ),
                          ],
                        ),
                      ).animate().fadeIn().slideX(begin: 0.3),
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
