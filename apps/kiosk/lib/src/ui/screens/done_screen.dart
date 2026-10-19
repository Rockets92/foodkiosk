import 'dart:async';

import 'package:flutter/material.dart';
import 'package:kiosk_core/kiosk_core.dart';

import '../scope.dart';
import '../theme.dart';

/// Order number and what to do next; returns to the attract screen alone.
class DoneScreen extends StatefulWidget {
  final Duration autoReset;
  const DoneScreen({super.key, this.autoReset = const Duration(seconds: 20)});

  @override
  State<DoneScreen> createState() => _DoneScreenState();
}

class _DoneScreenState extends State<DoneScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(widget.autoReset, () {
      if (mounted) context.kiosk.reset();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final k = context.kiosk;
    final t = context.t;
    final order = k.order!;
    final usesKitchen = k.settings.flow.rules.values.any(
      (a) => a.contains(FlowAction.sendToKitchenDisplay),
    );
    final message = switch (order.paymentStatus) {
      PaymentStatus.awaitingCounter => t('doneCounter'),
      PaymentStatus.paid => t('donePaid'),
      _ => t('doneNoPayment'),
    };
    return Scaffold(
      key: const ValueKey('done'),
      backgroundColor: brandPrimary,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(48),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 120),
                const SizedBox(height: 16),
                Text(
                  t('thankYou'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 56,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 48),
                Text(
                  t('orderNumber'),
                  style: const TextStyle(color: Colors.white, fontSize: 28),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 64,
                    vertical: 24,
                  ),
                  decoration: BoxDecoration(
                    color: brandAccent,
                    borderRadius: BorderRadius.circular(32),
                  ),
                  child: Text(
                    order.displayNumber,
                    key: const ValueKey('order-number'),
                    style: const TextStyle(
                      fontSize: 140,
                      fontWeight: FontWeight.w900,
                      height: 1,
                    ),
                  ),
                ),
                const SizedBox(height: 48),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (usesKitchen) ...[
                  const SizedBox(height: 12),
                  Text(
                    t('doneKitchen'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 24),
                  ),
                ],
                const SizedBox(height: 64),
                FilledButton(
                  key: const ValueKey('new-order'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: brandPrimary,
                  ),
                  onPressed: k.reset,
                  child: Text(t('newOrder')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
