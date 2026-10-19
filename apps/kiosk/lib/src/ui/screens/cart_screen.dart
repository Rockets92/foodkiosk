import 'package:flutter/material.dart';
import 'package:kiosk_core/kiosk_core.dart';

import '../scope.dart';
import '../widgets/net_image.dart';
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
              padding: const EdgeInsets.fromLTRB(16, 16, 24, 8),
              child: Row(
                children: [
                  IconButton(
                    iconSize: 40,
                    onPressed: k.busy ? null : k.backToMenu,
                    icon: const Icon(Icons.arrow_back),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    t('yourOrder'),
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const Spacer(),
                  Chip(
                    avatar: Icon(
                      k.serviceMode == ServiceMode.eatIn
                          ? Icons.restaurant
                          : Icons.shopping_bag_outlined,
                    ),
                    label: Text(
                      t(k.serviceMode.name),
                      style: const TextStyle(fontSize: 18),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: k.cart.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.shopping_cart_outlined, size: 96),
                          Text(
                            t('emptyCart'),
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          Text(t('emptyCartHint')),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(24),
                      itemCount: k.cart.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (_, i) => _CartLineTile(index: i),
                    ),
            ),
            if (k.errorKey != null)
              Container(
                width: double.infinity,
                color: Colors.red.shade50,
                padding: const EdgeInsets.all(16),
                child: Text(
                  t(k.errorKey!),
                  key: const ValueKey('cart-error'),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 20, color: Colors.red.shade900),
                ),
              ),
            const _CheckoutBar(),
          ],
        ),
      ),
    );
  }
}

class _CartLineTile extends StatelessWidget {
  final int index;
  const _CartLineTile({required this.index});

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
    return Card(
      key: ValueKey('cart-line-$index'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            SizedBox.square(
              dimension: 96,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: NetImage(product.imageUrl),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t.text(product.name),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (optionNames.isNotEmpty)
                    Text(
                      optionNames.join(', '),
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.black54,
                      ),
                    ),
                  if (product.modifierGroupIds.isNotEmpty)
                    TextButton.icon(
                      onPressed: () => MenuScreen.openProduct(
                        context,
                        product,
                        editIndex: index,
                      ),
                      icon: const Icon(Icons.edit),
                      label: Text(t('edit')),
                    ),
                ],
              ),
            ),
            IconButton.outlined(
              key: ValueKey('line-minus-$index'),
              iconSize: 32,
              onPressed: () => k.setQuantity(index, line.quantity - 1),
              icon: Icon(
                line.quantity == 1 ? Icons.delete_outline : Icons.remove,
              ),
            ),
            SizedBox(
              width: 56,
              child: Text(
                '${line.quantity}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            IconButton.outlined(
              key: ValueKey('line-plus-$index'),
              iconSize: 32,
              onPressed: line.quantity < k.maxQuantity
                  ? () => k.setQuantity(index, line.quantity + 1)
                  : null,
              icon: const Icon(Icons.add),
            ),
            SizedBox(
              width: 130,
              child: Text(
                context.money(k.lineTotal(line)),
                textAlign: TextAlign.right,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CheckoutBar extends StatelessWidget {
  const _CheckoutBar();

  @override
  Widget build(BuildContext context) {
    final k = context.kiosk;
    final t = context.t;
    final options = k.paymentOptions;
    final disabled = k.cart.isEmpty || k.busy;

    Widget submitButton(PaymentMode? choice, String label, IconData icon) =>
        Expanded(
          child: FilledButton.icon(
            key: ValueKey('submit-${choice?.name ?? 'default'}'),
            onPressed: disabled ? null : () => k.submit(paymentChoice: choice),
            icon: Icon(icon, size: 32),
            label: Text(label),
          ),
        );

    return Material(
      elevation: 12,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Text(
                  t('total'),
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                Text(
                  context.money(k.cartTotal),
                  style: const TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (k.busy)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(width: 16),
                    Text(t('sending'), style: const TextStyle(fontSize: 22)),
                  ],
                ),
              )
            else if (options.length > 1) ...[
              Text(t('howPay'), style: const TextStyle(fontSize: 22)),
              const SizedBox(height: 12),
              Row(
                children: [
                  submitButton(
                    PaymentMode.kiosk,
                    t('payHere'),
                    Icons.credit_card,
                  ),
                  const SizedBox(width: 16),
                  submitButton(
                    PaymentMode.counter,
                    t('payCounter'),
                    Icons.point_of_sale,
                  ),
                ],
              ),
            ] else
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: k.backToMenu,
                      child: Text(t('continueOrdering')),
                    ),
                  ),
                  const SizedBox(width: 16),
                  submitButton(
                    null,
                    options.single == PaymentMode.kiosk
                        ? t('confirmAndPay')
                        : t('confirmOrder'),
                    options.single == PaymentMode.kiosk
                        ? Icons.credit_card
                        : Icons.check_circle,
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
