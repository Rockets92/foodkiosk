import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../scope.dart';
import '../theme.dart';
import '../widgets/net_image.dart';
import '../widgets/pressable.dart';

/// Card payment: points the customer to the terminal, then shows the
/// way forward if the payment fails.
class PaymentScreen extends StatelessWidget {
  const PaymentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final k = context.kiosk;
    final t = context.t;
    final order = k.order;
    // Already reset (cancelled) while this screen fades out.
    if (order == null) return const SizedBox.shrink();
    final failed = k.paymentFailed;
    return Scaffold(
      key: const ValueKey('payment'),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(48),
          child: Column(
            children: [
              const Spacer(),
              Text(
                t('amountToPay'),
                style: KText.h3.copyWith(color: K.inkSoft),
              ),
              Text(
                context.money(order.totalCents),
                style: KText.display.copyWith(fontSize: 96),
              ),
              const SizedBox(height: 40),
              AnimatedSwitcher(
                duration: K.slow,
                switchInCurve: Curves.easeOutBack,
                child: failed
                    ? _Failed(key: const ValueKey('f'))
                    : const _Waiting(),
              ),
              const Spacer(flex: 2),
            ],
          ),
        ),
      ),
    );
  }
}

class _Waiting extends StatelessWidget {
  const _Waiting();

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return Column(
      children: [
        SizedBox(
          width: 520,
          height: 520,
          child: Stack(
            alignment: Alignment.center,
            children: [
              for (var i = 0; i < 3; i++)
                Container(
                      width: 300,
                      height: 300,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: K.red.withValues(alpha: 0.5),
                          width: 6,
                        ),
                      ),
                    )
                    .animate(onPlay: (c) => c.repeat())
                    .scaleXY(
                      begin: 0.8,
                      end: 1.7,
                      delay: (i * 600).ms,
                      duration: 1800.ms,
                      curve: Curves.easeOut,
                    )
                    .fadeOut(delay: (i * 600).ms, duration: 1800.ms),
              const Illustration('pos', size: 380)
                  .animate(onPlay: (c) => c.repeat(reverse: true))
                  .rotate(begin: -0.01, end: 0.01, duration: 1200.ms),
            ],
          ),
        ),
        Text(t('followTerminal'), textAlign: TextAlign.center, style: KText.h1),
        const SizedBox(height: 28),
        const Icon(
              Icons.keyboard_double_arrow_down_rounded,
              size: 96,
              color: K.red,
            )
            .animate(onPlay: (c) => c.repeat(reverse: true))
            .moveY(
              begin: -10,
              end: 14,
              duration: 700.ms,
              curve: Curves.easeInOut,
            ),
        Text(t('posBelow'), style: KText.h3.copyWith(color: K.red)),
      ],
    );
  }
}

class _Failed extends StatelessWidget {
  const _Failed({super.key});

  @override
  Widget build(BuildContext context) {
    final k = context.kiosk;
    final t = context.t;
    return Column(
      children: [
        Container(
          width: 200,
          height: 200,
          decoration: const BoxDecoration(
            color: Color(0xFFFFE9E5),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.credit_card_off_rounded,
            size: 110,
            color: K.red,
          ),
        ).animate().shake(hz: 5, duration: 600.ms),
        const SizedBox(height: 28),
        Text(
          t('paymentFailed'),
          key: const ValueKey('payment-failed'),
          style: KText.h1,
        ),
        const SizedBox(height: 10),
        Text(
          k.canPayAtCounterInstead
              ? t('paymentFailedHint')
              : t(k.errorKey ?? 'errorGeneric'),
          textAlign: TextAlign.center,
          style: KText.body.copyWith(fontSize: 24),
        ),
        const SizedBox(height: 44),
        SizedBox(
          width: 640,
          child: Column(
            children: [
              KButton(
                key: const ValueKey('retry-payment'),
                label: t('retry'),
                icon: Icons.refresh_rounded,
                height: 96,
                expand: true,
                onTap: k.pay,
              ),
              if (k.canPayAtCounterInstead) ...[
                const SizedBox(height: 16),
                KButton(
                  key: const ValueKey('pay-counter-instead'),
                  label: t('payCounter'),
                  icon: Icons.point_of_sale_rounded,
                  color: K.ink,
                  height: 96,
                  expand: true,
                  onTap: k.payAtCounterInstead,
                ),
              ],
              const SizedBox(height: 16),
              KButton.secondary(
                key: const ValueKey('cancel-payment'),
                label: t('cancelOrder'),
                icon: Icons.close_rounded,
                height: 88,
                expand: true,
                onTap: k.cancelAndReset,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
