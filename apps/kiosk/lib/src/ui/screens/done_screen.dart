import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:kiosk_core/kiosk_core.dart';

import '../holiday/decor.dart';
import '../scope.dart';
import '../theme.dart';
import '../widgets/pressable.dart';

/// Order number with a celebration, then back to the attract screen.
class DoneScreen extends StatefulWidget {
  final Duration autoReset;
  const DoneScreen({super.key, this.autoReset = const Duration(seconds: 20)});

  @override
  State<DoneScreen> createState() => _DoneScreenState();
}

class _DoneScreenState extends State<DoneScreen>
    with SingleTickerProviderStateMixin {
  late final _countdown =
      AnimationController(vsync: this, duration: widget.autoReset)
        ..forward().whenComplete(() {
          if (mounted) context.kiosk.reset();
        });

  // Kept so the screen can still draw while it fades out after a reset.
  Order? _order;

  @override
  void dispose() {
    _countdown.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final k = context.kiosk;
    final t = context.t;
    final order = _order = k.order ?? _order!;
    final usesKitchen = k.settings.flow.rules.values.any(
      (a) => a.contains(FlowAction.sendToKitchenDisplay),
    );
    final message = switch (order.paymentStatus) {
      PaymentStatus.awaitingCounter => t('doneCounter'),
      PaymentStatus.paid => t('donePaid'),
      _ => t('doneNoPayment'),
    };
    final holiday = K.holiday;
    return Scaffold(
      key: const ValueKey('done'),
      body: DecoratedBox(
        decoration: BoxDecoration(gradient: K.heroGradient),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (holiday != null)
              HolidayScene(
                key: ValueKey('holiday-${holiday.id}'),
                theme: holiday,
              ),
            const _Confetti(),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(48),
                child: Column(
                  children: [
                    const Spacer(),
                    Container(
                          width: 150,
                          height: 150,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check_rounded,
                            size: 110,
                            color: K.success,
                          ),
                        )
                        .animate()
                        .scale(duration: 700.ms, curve: Curves.elasticOut)
                        .then()
                        .shimmer(duration: 900.ms),
                    const SizedBox(height: 24),
                    Text(
                      t('thankYou'),
                      style: KText.display.copyWith(
                        color: Colors.white,
                        fontSize: 80,
                      ),
                    ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.3),
                    if (holiday != null) ...[
                      const SizedBox(height: 14),
                      HolidayGreeting(
                        theme: holiday,
                        text: holidayGreeting(t, holiday),
                      ),
                    ],
                    const SizedBox(height: 40),
                    _Ticket(order: order, label: t('orderNumber')),
                    const SizedBox(height: 44),
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: KText.h2.copyWith(color: Colors.white),
                    ).animate().fadeIn(delay: 1100.ms),
                    if (usesKitchen) ...[
                      const SizedBox(height: 10),
                      Text(
                        t('doneKitchen'),
                        textAlign: TextAlign.center,
                        style: KText.h3.copyWith(
                          color: Colors.white70,
                          fontWeight: FontWeight.w500,
                        ),
                      ).animate().fadeIn(delay: 1300.ms),
                    ],
                    const Spacer(),
                    _NewOrderButton(
                      countdown: _countdown,
                      label: t('newOrder'),
                    ),
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

/// The order number on a receipt that slides out of a printer slot.
class _Ticket extends StatelessWidget {
  final Order order;
  final String label;
  const _Ticket({required this.order, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 560,
          height: 26,
          decoration: BoxDecoration(
            color: K.ink,
            borderRadius: BorderRadius.circular(13),
          ),
        ),
        ClipRect(
          child:
              Container(
                width: 480,
                padding: const EdgeInsets.fromLTRB(32, 26, 32, 34),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(
                    bottom: Radius.circular(20),
                  ),
                  boxShadow: K.shadowStrong,
                ),
                child: Column(
                  children: [
                    Text(
                      label.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 20,
                        letterSpacing: 2,
                        fontWeight: FontWeight.w700,
                        color: K.inkSoft,
                      ),
                    ),
                    Text(
                      order.displayNumber,
                      key: const ValueKey('order-number'),
                      style: const TextStyle(
                        fontSize: 160,
                        height: 1.05,
                        fontWeight: FontWeight.w900,
                        color: K.ink,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: List.generate(
                        22,
                        (i) => Expanded(
                          child: Container(
                            height: 3,
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            color: K.line,
                          ),
                        ),
                      ),
                    ),
                    if (order.discountCents > 0) ...[
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.local_offer_rounded,
                            color: Color(0xFF14A05A),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            context.t(
                              'couponSaved',
                              args: {
                                'amount': context.money(order.discountCents),
                              },
                            ),
                            key: const ValueKey('done-saved'),
                            style: KText.h3.copyWith(
                              color: const Color(0xFF14A05A),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ).animate().slideY(
                begin: -1,
                end: 0,
                delay: 400.ms,
                duration: 900.ms,
                curve: Curves.easeOutCubic,
              ),
        ),
      ],
    );
  }
}

class _NewOrderButton extends StatelessWidget {
  final AnimationController countdown;
  final String label;
  const _NewOrderButton({required this.countdown, required this.label});

  @override
  Widget build(BuildContext context) {
    return Pressable(
      key: const ValueKey('new-order'),
      onTap: context.kiosk.reset,
      child: Container(
        height: 96,
        padding: const EdgeInsets.fromLTRB(16, 0, 36, 0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(48),
          boxShadow: K.shadowStrong,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox.square(
              dimension: 64,
              child: AnimatedBuilder(
                animation: countdown,
                builder: (_, _) => Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: 1 - countdown.value,
                      strokeWidth: 6,
                      color: K.primary,
                      backgroundColor: K.line,
                    ),
                    Text(
                      '${((1 - countdown.value) * countdown.duration!.inSeconds).ceil()}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 18),
            Text(label, style: KText.button.copyWith(color: K.primary)),
          ],
        ),
      ),
    );
  }
}

class _Confetti extends StatefulWidget {
  const _Confetti();

  @override
  State<_Confetti> createState() => _ConfettiState();
}

class _ConfettiState extends State<_Confetti>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3200),
  )..forward();
  final _pieces = List.generate(90, (i) => _Piece(Random(i)));

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: AnimatedBuilder(
      animation: _c,
      builder: (_, _) =>
          CustomPaint(painter: _ConfettiPainter(_pieces, _c.value)),
    ),
  );
}

class _Piece {
  final double x, speed, drift, spin, size, delay;
  final Color color;
  _Piece(Random r)
    : x = r.nextDouble(),
      speed = 0.7 + r.nextDouble() * 0.6,
      drift = (r.nextDouble() - 0.5) * 0.25,
      spin = r.nextDouble() * 8,
      size = 10 + r.nextDouble() * 14,
      delay = r.nextDouble() * 0.3,
      color = [
        K.accent,
        Colors.white,
        Color(0xFFFF8F1F),
        Color(0xFF7CC94A),
      ][r.nextInt(4)];
}

class _ConfettiPainter extends CustomPainter {
  final List<_Piece> pieces;
  final double t;
  _ConfettiPainter(this.pieces, this.t);

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in pieces) {
      final local = ((t - p.delay) / (1 - p.delay)).clamp(0.0, 1.0);
      if (local <= 0 || local >= 1) continue;
      final y = -40 + local * p.speed * (size.height + 80);
      final x = (p.x + p.drift * local) * size.width;
      final paint = Paint()..color = p.color.withValues(alpha: 1 - local * 0.6);
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(p.spin * local * pi);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset.zero,
            width: p.size,
            height: p.size * 0.5,
          ),
          const Radius.circular(3),
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.t != t;
}
