import 'package:flutter/material.dart';

import '../scope.dart';

/// Shown while the card terminal works, and after a failed payment.
class PaymentScreen extends StatelessWidget {
  const PaymentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final k = context.kiosk;
    final t = context.t;
    final order = k.order!;
    final failed = k.paymentFailed;
    return Scaffold(
      key: const ValueKey('payment'),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(48),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  t('paymentTitle'),
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 32),
                Text(t('amountToPay'), style: const TextStyle(fontSize: 24)),
                Text(
                  context.money(order.totalCents),
                  style: const TextStyle(
                    fontSize: 64,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 48),
                if (!failed) ...[
                  const SizedBox.square(
                    dimension: 120,
                    child: CircularProgressIndicator(strokeWidth: 10),
                  ),
                  const SizedBox(height: 32),
                  const Icon(Icons.contactless, size: 96),
                  const SizedBox(height: 16),
                  Text(
                    t('followTerminal'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ] else ...[
                  Icon(
                    Icons.error_outline,
                    size: 120,
                    color: Colors.red.shade700,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    t('paymentFailed'),
                    key: const ValueKey('payment-failed'),
                    style: const TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    k.canPayAtCounterInstead
                        ? t('paymentFailedHint')
                        : t(k.errorKey ?? 'errorGeneric'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 22),
                  ),
                  const SizedBox(height: 40),
                  Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    alignment: WrapAlignment.center,
                    children: [
                      FilledButton.icon(
                        key: const ValueKey('retry-payment'),
                        onPressed: k.pay,
                        icon: const Icon(Icons.refresh),
                        label: Text(t('retry')),
                      ),
                      if (k.canPayAtCounterInstead)
                        FilledButton.tonalIcon(
                          key: const ValueKey('pay-counter-instead'),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(160, 72),
                          ),
                          onPressed: k.payAtCounterInstead,
                          icon: const Icon(Icons.point_of_sale),
                          label: Text(
                            t('payCounter'),
                            style: const TextStyle(fontSize: 24),
                          ),
                        ),
                      OutlinedButton.icon(
                        key: const ValueKey('cancel-payment'),
                        onPressed: k.cancelAndReset,
                        icon: const Icon(Icons.close),
                        label: Text(t('cancelOrder')),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
