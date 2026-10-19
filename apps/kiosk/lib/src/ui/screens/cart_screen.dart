import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:kiosk_core/kiosk_core.dart';

import '../scope.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/pressable.dart';
import 'menu_screen.dart';

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final k = context.kiosk;
    final t = context.t;
    return Scaffold(
      key: const ValueKey('cart'),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 20, 28, 12),
              child: Row(
                children: [
                  RoundButton(
                    key: const ValueKey('cart-back'),
                    icon: Icons.arrow_back_rounded,
                    size: 72,
                    onTap: k.busy ? null : k.backToMenu,
                  ),
                  const SizedBox(width: 20),
                  Expanded(child: Text(t('yourOrder'), style: KText.h1)),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: K.shadow,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          k.serviceMode == ServiceMode.eatIn
                              ? Icons.restaurant_rounded
                              : Icons.shopping_bag_rounded,
                          color: K.red,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          t(k.serviceMode.name),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: k.cart.isEmpty
                  ? _Empty()
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(28, 12, 28, 24),
                      children: [
                        for (var i = 0; i < k.cart.length; i++)
                          _CartLineTile(
                            key: ValueKey(
                              'line-${k.cart[i].productId}-${k.cart[i].optionIds.join()}',
                            ),
                            index: i,
                          ).animate().fadeIn(delay: (60 * i).ms).slideX(begin: 0.1),
                        const SizedBox(height: 20),
                        const _Upsell(),
                      ],
                    ),
            ),
            const _CheckoutPanel(),
          ],
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.shopping_bag_outlined, size: 120, color: K.muted),
          const SizedBox(height: 12),
          Text(t('emptyCart'), style: KText.h2),
          Text(t('emptyCartHint'), style: KText.body),
        ],
      ),
    );
  }
}

class _CartLineTile extends StatelessWidget {
  final int index;
  const _CartLineTile({super.key, required this.index});

  @override
  Widget build(BuildContext context) {
    final k = context.kiosk;
    final t = context.t;
    final line = k.cart[index];
    final product = k.menu.product(line.productId);
    if (product == null) return const SizedBox.shrink();
    final optionNames = [
      for (final gid in product.modifierGroupIds)
        if (k.menu.modifierGroup(gid) case final g?)
          for (final o in g.options)
            if (line.optionIds.contains(o.id)) t.text(o.name),
    ];
    return Container(
      key: ValueKey('cart-line-$index'),
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(K.radius),
        boxShadow: K.shadow,
      ),
      child: Row(
        children: [
          SizedBox.square(
            dimension: 120,
            child: ImageDisc(
              image: product.imageUrl,
              color: K.tintFor(product.categoryId),
              padding: 10,
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.text(product.name), style: KText.h3),
                if (optionNames.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      optionNames.join(' · '),
                      style: KText.small.copyWith(color: K.inkSoft),
                    ),
                  ),
                if (product.modifierGroupIds.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Pressable(
                      onTap: () => MenuScreen.openProduct(
                        context,
                        product,
                        editIndex: index,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.edit_rounded,
                            size: 20,
                            color: K.red,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            t('edit'),
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: K.red,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 10),
                AnimatedAmount(
                  context.money(k.lineTotal(line)),
                  style: KText.price,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: K.background,
              borderRadius: BorderRadius.circular(40),
            ),
            child: Row(
              children: [
                RoundButton(
                  key: ValueKey('line-minus-$index'),
                  icon: line.quantity == 1
                      ? Icons.delete_outline_rounded
                      : Icons.remove_rounded,
                  size: 60,
                  onTap: () => k.setQuantity(index, line.quantity - 1),
                ),
                SizedBox(
                  width: 52,
                  child: Text(
                    '${line.quantity}',
                    textAlign: TextAlign.center,
                    style: KText.h3,
                  ),
                ),
                RoundButton(
                  key: ValueKey('line-plus-$index'),
                  icon: Icons.add_rounded,
                  size: 60,
                  color: K.ink,
                  foreground: Colors.white,
                  onTap: line.quantity < k.maxQuantity
                      ? () => k.setQuantity(index, line.quantity + 1)
                      : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// "Complete your meal": products from categories the customer has not
/// picked from yet, one tap to add.
class _Upsell extends StatelessWidget {
  const _Upsell();

  @override
  Widget build(BuildContext context) {
    final k = context.kiosk;
    final t = context.t;
    final inCart = {
      for (final l in k.cart) k.menu.product(l.productId)?.categoryId,
    };
    final suggestions = [
      for (final c in k.visibleCategories.reversed)
        if (!inCart.contains(c.id))
          ...k.menu.productsIn(c.id).where((p) => !p.soldOut).take(2),
    ].take(6).toList();
    if (suggestions.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.auto_awesome_rounded, color: K.red),
            const SizedBox(width: 8),
            Text(t('upsellTitle'), style: KText.h2),
          ],
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 300,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            itemCount: suggestions.length,
            separatorBuilder: (_, _) => const SizedBox(width: 18),
            itemBuilder: (_, i) => SizedBox(
              width: 220,
              child: ProductCard(product: suggestions[i]),
            ).animate().fadeIn(delay: (250 + 70 * i).ms).slideX(begin: 0.2),
          ),
        ),
      ],
    );
  }
}

class _CheckoutPanel extends StatelessWidget {
  const _CheckoutPanel();

  @override
  Widget build(BuildContext context) {
    final k = context.kiosk;
    final t = context.t;
    final options = k.paymentOptions;
    final disabled = k.cart.isEmpty || k.busy;
    final pay = options.length == 1 && options.single == PaymentMode.kiosk;

    return Container(
      padding: const EdgeInsets.fromLTRB(32, 26, 32, 34),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(36)),
        boxShadow: [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 30,
            offset: Offset(0, -6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (k.errorKey != null)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 18),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFFE9E5),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_rounded, color: K.red),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      t(k.errorKey!),
                      key: const ValueKey('cart-error'),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: K.redDark,
                      ),
                    ),
                  ),
                ],
              ),
            ).animate().shake(hz: 4, duration: 400.ms),
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${k.itemCount} ${t('items')}', style: KText.small),
                  Text(t('total'), style: KText.h3),
                ],
              ),
              const Spacer(),
              AnimatedAmount(
                context.money(k.cartTotal),
                style: KText.display.copyWith(fontSize: 52),
              ),
            ],
          ),
          const SizedBox(height: 22),
          if (k.busy)
            SizedBox(
              height: 96,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox.square(
                    dimension: 40,
                    child: CircularProgressIndicator(
                      strokeWidth: 5,
                      color: K.red,
                    ),
                  ),
                  const SizedBox(width: 20),
                  Text(t('sending'), style: KText.h3),
                ],
              ),
            )
          else
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: KButton.secondary(
                    label: t('continueOrdering'),
                    height: 96,
                    expand: true,
                    onTap: k.backToMenu,
                  ),
                ),
                const SizedBox(width: 18),
                Expanded(
                  flex: 3,
                  child: KButton(
                    key: const ValueKey('submit-default'),
                    label: options.length > 1
                        ? t('checkout')
                        : pay
                        ? t('confirmAndPay')
                        : t('confirmOrder'),
                    icon: pay || options.length > 1
                        ? Icons.credit_card_rounded
                        : Icons.check_circle_rounded,
                    height: 96,
                    expand: true,
                    onTap: disabled
                        ? null
                        : () => options.length > 1
                              ? _choosePayment(context)
                              : k.submit(),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Future<void> _choosePayment(BuildContext context) async {
    final k = context.kiosk;
    final t = context.t;
    final choice = await showModalBottomSheet<PaymentMode>(
      context: context,
      // Material caps sheets at 640px; use the full kiosk width.
      constraints: const BoxConstraints(maxWidth: double.infinity),
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(40)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(36, 30, 36, 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60,
              height: 6,
              decoration: BoxDecoration(
                color: K.line,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(height: 24),
            Text(t('howPay'), style: KText.h1),
            const SizedBox(height: 28),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _PayOption(
                      key: const ValueKey('submit-kiosk'),
                      icon: Icons.contactless_rounded,
                      label: t('payHere'),
                      sub: t('payHereSub'),
                      color: K.red,
                      onTap: () => Navigator.pop(ctx, PaymentMode.kiosk),
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: _PayOption(
                      key: const ValueKey('submit-counter'),
                      icon: Icons.point_of_sale_rounded,
                      label: t('payCounter'),
                      sub: t('payCounterSub'),
                      color: K.ink,
                      onTap: () => Navigator.pop(ctx, PaymentMode.counter),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    if (choice != null) await k.submit(paymentChoice: choice);
  }
}

class _PayOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sub;
  final Color color;
  final VoidCallback onTap;

  const _PayOption({
    super.key,
    required this.icon,
    required this.label,
    required this.sub,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Pressable(
    onTap: onTap,
    child: Container(
      constraints: const BoxConstraints(minHeight: 280),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(K.radius),
        boxShadow: K.shadowStrong,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.white, size: 96),
          const SizedBox(height: 16),
          Text(
            label,
            textAlign: TextAlign.center,
            style: KText.h2.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 4),
          Text(
            sub,
            textAlign: TextAlign.center,
            style: KText.body.copyWith(color: Colors.white70),
          ),
        ],
      ),
    ),
  );
}
