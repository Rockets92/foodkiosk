import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:kiosk_core/kiosk_core.dart';

import '../../state/cart.dart';
import '../../state/kiosk_controller.dart';
import '../scope.dart';
import '../screens/menu_screen.dart';
import '../theme.dart';
import 'pressable.dart';

const _green = Color(0xFF14A05A);
const _greenSoft = Color(0xFFE3F6EC);
const _amber = Color(0xFFB36B00);

/// What the coupon gives, for the customer: its label, or a description
/// built from its kind.
String couponTitle(BuildContext context, DiscountCode c) {
  final t = context.t;
  final label = t.text(c.label);
  if (label.isNotEmpty) return label;
  return switch (c.type) {
    DiscountType.percent => t('couponPercent', args: {'n': c.percent}),
    DiscountType.amount => t(
      'couponAmount',
      args: {'amount': context.money(c.amountCents)},
    ),
    DiscountType.freeProduct => t(
      'couponFree',
      args: {
        'product': switch (context.kiosk.couponProduct) {
          final p? => t.text(p.name),
          null => '',
        },
      },
    ),
  };
}

/// Customer-facing message for a coupon problem (`i18n.dart` key).
String couponProblem(BuildContext context, String key) {
  final k = context.kiosk;
  final t = context.t;
  final c = k.coupon;
  return t(
    key,
    args: {
      'amount': context.money(c?.minOrderCents ?? 0),
      'missing': context.money(
        ((c?.minOrderCents ?? 0) - k.cartTotal).clamp(0, 1 << 31),
      ),
      'product': switch (k.couponProduct) {
        final p? => t.text(p.name),
        null => '',
      },
    },
  );
}

/// A coupon-shaped card: rounded, with a half-circle notch on each side
/// and a dashed tear line.
class TicketBorder extends ShapeBorder {
  final double radius;
  final double notch;

  /// Distance of the notches from the left edge.
  final double notchAt;

  const TicketBorder({this.radius = 24, this.notch = 14, this.notchAt = 96});

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.zero;

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      getOuterPath(rect);

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    final card = Path()
      ..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(radius)));
    final x = rect.left + notchAt;
    final holes = Path()
      ..addOval(Rect.fromCircle(center: Offset(x, rect.top), radius: notch))
      ..addOval(Rect.fromCircle(center: Offset(x, rect.bottom), radius: notch));
    return Path.combine(PathOperation.difference, card, holes);
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.7)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    final x = rect.left + notchAt;
    for (var y = rect.top + notch + 8; y < rect.bottom - notch - 8; y += 14) {
      canvas.drawLine(Offset(x, y), Offset(x, y + 6), paint);
    }
  }

  @override
  ShapeBorder scale(double t) => this;
}

// -------------------------------------------------------------------------
// Cart: prompt, applied coupon, totals

/// In the checkout panel: "Have a discount code?" or the applied coupon.
class CouponEntry extends StatelessWidget {
  const CouponEntry({super.key});

  @override
  Widget build(BuildContext context) {
    final k = context.kiosk;
    if (!k.discountsEnabled) return const SizedBox.shrink();
    return AnimatedSwitcher(
      duration: K.slow,
      switchInCurve: Curves.easeOutBack,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, anim) => FadeTransition(
        opacity: anim,
        child: ScaleTransition(scale: anim, child: child),
      ),
      child: k.coupon == null
          ? const _CouponPrompt(key: ValueKey('prompt'))
          : _AppliedCoupon(key: ValueKey('applied-${k.coupon!.code}')),
    );
  }
}

class _CouponPrompt extends StatelessWidget {
  const _CouponPrompt({super.key});

  @override
  Widget build(BuildContext context) {
    final k = context.kiosk;
    final t = context.t;
    final d = k.settings.discounts;
    final hint = !d.manualEntry
        ? t('couponScanOnly')
        : d.scanner
        ? t('couponTapOrScan')
        : t('couponTapHere');
    return Pressable(
      key: const ValueKey('coupon-open'),
      onTap: () => CouponSheet.show(context),
      pressedScale: 0.98,
      child: CustomPaint(
        painter: _DashedBorderPainter(color: K.primary.withValues(alpha: 0.45)),
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF6F2),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Row(
            children: [
              Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: K.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.local_offer_rounded,
                      color: Colors.white,
                      size: 30,
                    ),
                  )
                  .animate(onPlay: (c) => c.repeat(reverse: true))
                  .rotate(
                    begin: -0.03,
                    end: 0.03,
                    duration: 900.ms,
                    curve: Curves.easeInOut,
                  ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t('couponQuestion'), style: KText.h3),
                    Text(hint, style: KText.small.copyWith(color: K.inkSoft)),
                  ],
                ),
              ),
              if (d.scanner) ...[
                Icon(Icons.qr_code_scanner_rounded, color: K.primary, size: 34),
                const SizedBox(width: 10),
              ],
              Icon(Icons.chevron_right_rounded, color: K.primary, size: 36),
            ],
          ),
        ),
      ),
    );
  }
}

class _AppliedCoupon extends StatelessWidget {
  const _AppliedCoupon({super.key});

  @override
  Widget build(BuildContext context) {
    final k = context.kiosk;
    final t = context.t;
    final coupon = k.coupon!;
    final result = k.couponResult!;
    final ok = result.ok;
    final color = ok ? _green : _amber;
    final free = k.couponProduct;
    final card = Container(
      key: const ValueKey('coupon-applied'),
      decoration: ShapeDecoration(
        shape: const TicketBorder(notchAt: 92),
        gradient: LinearGradient(
          colors: ok
              ? const [Color(0xFF1FB86A), _green]
              : const [Color(0xFFFFB238), Color(0xFFE08A00)],
        ),
        shadows: [
          BoxShadow(
            color: color.withValues(alpha: 0.35),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(22, 14, 12, 14),
      child: Row(
        children: [
          SizedBox(
            width: 56,
            child: Icon(
              ok ? Icons.verified_rounded : Icons.info_rounded,
              color: Colors.white,
              size: 44,
            ),
          ),
          const SizedBox(width: 36),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        coupon.code,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.5,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  ok
                      ? couponTitle(context, coupon)
                      : couponProblem(
                          context,
                          result.problem == 'minOrderNotReached'
                              ? 'couponMinOrder'
                              : 'couponFreeMissing',
                        ),
                  key: const ValueKey('coupon-title'),
                  style: KText.h3.copyWith(color: Colors.white, fontSize: 21),
                ),
              ],
            ),
          ),
          if (ok)
            Text(
              '-${context.money(result.amountCents)}',
              key: const ValueKey('coupon-amount'),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 30,
                fontWeight: FontWeight.w900,
              ),
            )
          else if (result.problem == 'freeProductMissing' &&
              free != null &&
              !free.soldOut)
            Pressable(
              key: const ValueKey('coupon-add-free'),
              onTap: () => _addFree(context, free),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Text(
                  t('couponAddFree', args: {'product': t.text(free.name)}),
                  style: KText.button.copyWith(color: _amber, fontSize: 18),
                ),
              ),
            ),
          const SizedBox(width: 6),
          Pressable(
            key: const ValueKey('coupon-remove'),
            onTap: k.removeCoupon,
            pressedScale: 0.85,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.22),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.close_rounded,
                color: Colors.white,
                size: 26,
              ),
            ),
          ),
        ],
      ),
    );
    return card
        .animate(key: ValueKey(k.couponAttempt))
        .shimmer(
          delay: 350.ms,
          duration: 1100.ms,
          color: Colors.white.withValues(alpha: 0.55),
        );
  }

  void _addFree(BuildContext context, Product product) {
    final k = context.kiosk;
    final needsChoice = product.modifierGroupIds
        .map(k.menu.modifierGroup)
        .any((g) => g != null && g.required);
    if (needsChoice) {
      MenuScreen.openProduct(context, product);
    } else {
      k.addToCart(
        CartLine(
          productId: product.id,
          optionIds: defaultOptions(k.menu, product),
        ),
      );
    }
  }
}

/// Subtotal and discount rows above the total, when a coupon applies.
class CouponTotals extends StatelessWidget {
  const CouponTotals({super.key});

  @override
  Widget build(BuildContext context) {
    final k = context.kiosk;
    final t = context.t;
    final show = k.discountCents > 0;
    return AnimatedSize(
      duration: K.medium,
      curve: Curves.easeOutCubic,
      child: !show
          ? const SizedBox(width: double.infinity)
          : Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                children: [
                  Row(
                    children: [
                      Text(t('couponSubtotal'), style: KText.body),
                      const Spacer(),
                      Text(
                        context.money(k.cartTotal),
                        style: KText.body.copyWith(
                          decoration: TextDecoration.lineThrough,
                          decorationColor: K.muted,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      const Icon(
                        Icons.local_offer_rounded,
                        color: _green,
                        size: 22,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${t('couponDiscount')} ${k.coupon!.code}',
                        style: KText.body.copyWith(
                          color: _green,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '-${context.money(k.discountCents)}',
                        key: const ValueKey('discount-row'),
                        style: KText.body.copyWith(
                          color: _green,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }
}

/// Small "Free" badge for the cart line of a free product.
class FreeBadge extends StatelessWidget {
  const FreeBadge({super.key});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: _greenSoft,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.card_giftcard_rounded, color: _green, size: 18),
        const SizedBox(width: 4),
        Text(
          context.t('couponFreeBadge').toUpperCase(),
          style: const TextStyle(
            color: _green,
            fontWeight: FontWeight.w800,
            fontSize: 14,
            letterSpacing: 1,
          ),
        ),
      ],
    ),
  ).animate().scale(curve: Curves.easeOutBack, duration: 400.ms);
}

class _DashedBorderPainter extends CustomPainter {
  final Color color;
  _DashedBorderPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(22)),
      );
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    for (final metric in path.computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += 16) {
        canvas.drawPath(metric.extractPath(d, d + 9), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter old) => old.color != color;
}

// -------------------------------------------------------------------------
// Entry sheet

/// Full-width sheet to scan or type a code, depending on what the venue
/// enabled. Closes itself with a little celebration once a code applies,
/// whether typed here or scanned on the reader.
class CouponSheet extends StatefulWidget {
  const CouponSheet({super.key});

  /// While open, the sheet shows scan results itself (no toast).
  static bool isOpen = false;

  static Future<void> show(BuildContext context) {
    final k = context.kiosk;
    k.clearCouponError();
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      constraints: const BoxConstraints(maxWidth: double.infinity),
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(40)),
      ),
      builder: (_) => const CouponSheet(),
    );
  }

  @override
  State<CouponSheet> createState() => _CouponSheetState();
}

class _CouponSheetState extends State<CouponSheet> {
  String _typed = '';
  bool _done = false;
  late final KioskController _k;
  late int _attempt;

  @override
  void initState() {
    super.initState();
    _k = context.getInheritedWidgetOfExactType<KioskScope>()!.notifier!;
    _attempt = _k.couponAttempt;
    _k.addListener(_onChange);
    CouponSheet.isOpen = true;
  }

  @override
  void dispose() {
    CouponSheet.isOpen = false;
    _k.removeListener(_onChange);
    super.dispose();
  }

  /// A code applied (typed here or scanned): celebrate, then close.
  void _onChange() {
    if (_done || _k.couponAttempt == _attempt) return;
    _attempt = _k.couponAttempt;
    if (_k.coupon != null && _k.couponErrorKey == null) {
      setState(() => _done = true);
      Future.delayed(const Duration(milliseconds: 1300), () {
        if (mounted) Navigator.of(context).pop();
      });
    }
  }

  void _key(String c) {
    _k.clearCouponError();
    if (_typed.length < 20) setState(() => _typed += c);
  }

  void _backspace() {
    _k.clearCouponError();
    if (_typed.isNotEmpty) {
      setState(() => _typed = _typed.substring(0, _typed.length - 1));
    }
  }

  @override
  Widget build(BuildContext context) {
    final k = context.kiosk;
    final t = context.t;
    final d = k.settings.discounts;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(36, 22, 36, 36),
        child: AnimatedSize(
          duration: K.medium,
          curve: Curves.easeOutCubic,
          child: _done
              ? _Success(coupon: k.coupon!)
              : Column(
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
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: Text(t('couponTitle'), style: KText.h1),
                        ),
                        RoundButton(
                          key: const ValueKey('coupon-close'),
                          icon: Icons.close_rounded,
                          size: 64,
                          onTap: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    if (d.scanner) const _ScanPanel(),
                    if (d.scanner && d.manualEntry) const _OrDivider(),
                    if (d.manualEntry) ...[
                      _CodeField(
                        text: _typed,
                        errorKey: k.couponErrorKey,
                        attempt: k.couponAttempt,
                      ),
                      const SizedBox(height: 18),
                      _Keyboard(onKey: _key, onBackspace: _backspace),
                      const SizedBox(height: 22),
                      KButton(
                        key: const ValueKey('coupon-apply'),
                        label: k.checkingCoupon
                            ? t('couponChecking')
                            : t('couponApply'),
                        icon: Icons.local_offer_rounded,
                        height: 92,
                        expand: true,
                        onTap: _typed.length < 3 || k.checkingCoupon
                            ? null
                            : () => k.applyCoupon(_typed),
                      ),
                    ] else if (k.couponErrorKey != null) ...[
                      const SizedBox(height: 18),
                      _ErrorText(k.couponErrorKey!, attempt: k.couponAttempt),
                    ],
                  ],
                ),
        ),
      ),
    );
  }
}

class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 18),
    child: Row(
      children: [
        Expanded(child: Divider(color: K.line, thickness: 2)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            context.t('couponOr').toUpperCase(),
            style: KText.small.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: 2,
            ),
          ),
        ),
        Expanded(child: Divider(color: K.line, thickness: 2)),
      ],
    ),
  );
}

/// "Scan your coupon": a phone with a QR code sliding over the reader
/// while a laser line sweeps it.
class _ScanPanel extends StatelessWidget {
  const _ScanPanel();

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final k = context.kiosk;
    return Container(
      key: const ValueKey('coupon-scan'),
      height: 240,
      padding: const EdgeInsets.fromLTRB(28, 0, 28, 0),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2B2B33), K.ink],
        ),
        borderRadius: BorderRadius.circular(K.radius),
      ),
      child: Row(
        children: [
          const SizedBox(width: 220, height: 240, child: _ScanAnimation()),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t('couponScanTitle'),
                  style: KText.h2.copyWith(color: Colors.white),
                ),
                const SizedBox(height: 8),
                Text(
                  t('couponScanHint'),
                  style: KText.body.copyWith(color: Colors.white70),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Icon(
                          Icons.keyboard_double_arrow_down_rounded,
                          color: K.accent,
                          size: 38,
                        )
                        .animate(onPlay: (c) => c.repeat(reverse: true))
                        .moveY(begin: -4, end: 8, duration: 650.ms),
                    if (k.checkingCoupon) ...[
                      const SizedBox(width: 14),
                      SizedBox.square(
                        dimension: 26,
                        child: CircularProgressIndicator(
                          strokeWidth: 3.5,
                          color: K.accent,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ScanAnimation extends StatefulWidget {
  const _ScanAnimation();

  @override
  State<_ScanAnimation> createState() => _ScanAnimationState();
}

class _ScanAnimationState extends State<_ScanAnimation>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (_, _) => CustomPaint(painter: _ScanPainter(_c.value)),
  );
}

class _ScanPainter extends CustomPainter {
  final double t;
  _ScanPainter(this.t);

  // A fixed fake QR pattern.
  static final _bits = List.generate(49, (i) => Random(i * 7 + 3).nextBool());

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    // Reader window at the bottom, glowing.
    final reader = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(cx, size.height - 30),
        width: 170,
        height: 34,
      ),
      const Radius.circular(12),
    );
    canvas.drawRRect(reader, Paint()..color = const Color(0xFF3E3E48));
    final glow = 0.5 + 0.5 * sin(t * 2 * pi * 2);
    canvas.drawRRect(
      reader.deflate(8),
      Paint()
        ..color = K.primary.withValues(alpha: 0.5 + 0.5 * glow)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );

    // The phone comes down, holds over the reader, then goes back up.
    final down = Curves.easeOutCubic.transform((t / 0.35).clamp(0, 1));
    final up = Curves.easeInCubic.transform(((t - 0.8) / 0.2).clamp(0, 1));
    final y = 18 + 40 * down - 40 * up;
    final phone = RRect.fromRectAndRadius(
      Rect.fromLTWH(cx - 58, y, 116, 150),
      const Radius.circular(18),
    );
    canvas.drawRRect(phone, Paint()..color = Colors.white);
    final screen = phone.deflate(8);
    canvas.drawRRect(screen, Paint()..color = const Color(0xFFFFF6E0));

    // QR code on the screen.
    const cells = 7;
    const cell = 10.0;
    final origin = Offset(cx - cells * cell / 2, y + 30);
    final ink = Paint()..color = K.ink;
    for (var i = 0; i < cells * cells; i++) {
      final r = i ~/ cells, c = i % cells;
      final finder = (r < 2 && c < 2) || (r < 2 && c > 4) || (r > 4 && c < 2);
      if (finder || _bits[i]) {
        canvas.drawRect(
          Rect.fromLTWH(
            origin.dx + c * cell,
            origin.dy + r * cell,
            cell - 1,
            cell - 1,
          ),
          ink,
        );
      }
    }

    // Laser sweep while the phone is over the reader.
    final scanning = t > 0.35 && t < 0.8;
    if (scanning) {
      final s = ((t - 0.35) / 0.45);
      final ly = origin.dy + (sin(s * pi * 3) * 0.5 + 0.5) * cells * cell;
      canvas.drawLine(
        Offset(origin.dx - 14, ly),
        Offset(origin.dx + cells * cell + 14, ly),
        Paint()
          ..color = K.primary
          ..strokeWidth = 4
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
      );
    }
    // A green check once read.
    if (t > 0.7 && t < 0.86) {
      final a = ((t - 0.7) / 0.05).clamp(0.0, 1.0);
      canvas.drawCircle(
        Offset(cx + 52, y + 8),
        18,
        Paint()..color = _green.withValues(alpha: a),
      );
      final p = Paint()
        ..color = Colors.white.withValues(alpha: a)
        ..strokeWidth = 4
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      canvas.drawPath(
        Path()
          ..moveTo(cx + 44, y + 8)
          ..lineTo(cx + 50, y + 14)
          ..lineTo(cx + 61, y + 2),
        p,
      );
    }
  }

  @override
  bool shouldRepaint(_ScanPainter old) => old.t != t;
}

class _CodeField extends StatelessWidget {
  final String text;
  final String? errorKey;
  final int attempt;
  const _CodeField({
    required this.text,
    required this.errorKey,
    required this.attempt,
  });

  @override
  Widget build(BuildContext context) {
    final error = errorKey != null;
    final field = AnimatedContainer(
      duration: K.fast,
      height: 104,
      padding: const EdgeInsets.symmetric(horizontal: 28),
      decoration: BoxDecoration(
        color: K.background,
        borderRadius: BorderRadius.circular(K.radius),
        border: Border.all(color: error ? K.danger : K.line, width: 3),
      ),
      child: Row(
        children: [
          Icon(
            Icons.local_offer_rounded,
            color: error ? K.danger : K.muted,
            size: 36,
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    text,
                    key: const ValueKey('coupon-typed'),
                    maxLines: 1,
                    overflow: TextOverflow.visible,
                    style: const TextStyle(
                      fontSize: 46,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 6,
                      color: K.ink,
                    ),
                  ),
                ),
                Container(width: 4, height: 52, color: K.primary)
                    .animate(onPlay: (c) => c.repeat(reverse: true))
                    .fade(begin: 1, end: 0, duration: 520.ms),
              ],
            ),
          ),
        ],
      ),
    );
    return Column(
      children: [
        error
            ? field
                  .animate(key: ValueKey(attempt))
                  .shake(hz: 5, duration: 450.ms)
            : field,
        if (error) ...[
          const SizedBox(height: 10),
          _ErrorText(errorKey!, attempt: attempt),
        ],
      ],
    );
  }
}

class _ErrorText extends StatelessWidget {
  final String errorKey;
  final int attempt;
  const _ErrorText(this.errorKey, {required this.attempt});

  @override
  Widget build(BuildContext context) => Row(
    key: const ValueKey('coupon-error'),
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      const Icon(Icons.error_rounded, color: K.danger),
      const SizedBox(width: 8),
      Flexible(
        child: Text(
          couponProblem(context, errorKey),
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: K.dangerDark,
          ),
        ),
      ),
    ],
  ).animate(key: ValueKey(attempt)).fadeIn().slideY(begin: -0.3);
}

/// Big on-screen keyboard: digits and letters, as on the totem there is
/// no physical keyboard.
class _Keyboard extends StatelessWidget {
  final ValueChanged<String> onKey;
  final VoidCallback onBackspace;
  const _Keyboard({required this.onKey, required this.onBackspace});

  static const _rows = ['1234567890', 'QWERTYUIOP', 'ASDFGHJKL', 'ZXCVBNM'];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final (i, row) in _rows.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (final c in row.split(''))
                  _Key(
                    key: ValueKey('kb-$c'),
                    onTap: () => onKey(c),
                    child: Text(c),
                  ),
                if (i == _rows.length - 1) ...[
                  _Key(
                    key: const ValueKey('kb--'),
                    onTap: () => onKey('-'),
                    child: const Text('-'),
                  ),
                  _Key(
                    key: const ValueKey('kb-back'),
                    onTap: onBackspace,
                    width: 170,
                    dark: true,
                    child: const Icon(
                      Icons.backspace_rounded,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _Key extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;
  final double width;
  final bool dark;
  const _Key({
    super.key,
    required this.child,
    required this.onTap,
    this.width = 86,
    this.dark = false,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 5),
    child: Pressable(
      onTap: onTap,
      pressedScale: 0.86,
      child: Container(
        width: width,
        height: 80,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: dark ? K.ink : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: dark ? null : Border.all(color: K.line, width: 2),
          boxShadow: const [
            BoxShadow(
              color: Color(0x14000000),
              blurRadius: 0,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: DefaultTextStyle(
          style: const TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w800,
            color: K.ink,
            fontFamily: 'Poppins',
          ),
          child: child,
        ),
      ),
    ),
  );
}

class _Success extends StatelessWidget {
  final DiscountCode coupon;
  const _Success({required this.coupon});

  @override
  Widget build(BuildContext context) {
    final k = context.kiosk;
    final t = context.t;
    return SizedBox(
      key: const ValueKey('coupon-success'),
      width: double.infinity,
      height: 420,
      child: Stack(
        alignment: Alignment.center,
        children: [
          for (var i = 0; i < 12; i++)
            Transform.rotate(
              angle: i * pi / 6,
              child:
                  Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: [K.accent, K.primary, _green][i % 3],
                          shape: BoxShape.circle,
                        ),
                      )
                      .animate()
                      .moveY(
                        begin: 0,
                        end: -170,
                        duration: 700.ms,
                        curve: Curves.easeOutCubic,
                      )
                      .fadeOut(delay: 400.ms, duration: 400.ms),
            ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 150,
                height: 150,
                decoration: const BoxDecoration(
                  color: _green,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: Colors.white,
                  size: 100,
                ),
              ).animate().scale(
                begin: const Offset(0.2, 0.2),
                curve: Curves.elasticOut,
                duration: 900.ms,
              ),
              const SizedBox(height: 24),
              Text(
                t('couponApplied'),
                style: KText.h1,
              ).animate().fadeIn(delay: 150.ms).slideY(begin: 0.4),
              const SizedBox(height: 6),
              Text(
                couponTitle(context, coupon),
                style: KText.h3.copyWith(color: _green),
              ).animate().fadeIn(delay: 300.ms),
              if (k.discountCents > 0)
                Text(
                  t(
                    'couponSaved',
                    args: {'amount': context.money(k.discountCents)},
                  ),
                  style: KText.body,
                ).animate().fadeIn(delay: 420.ms),
            ],
          ),
        ],
      ),
    );
  }
}

// -------------------------------------------------------------------------
// Toast for scans outside the sheet

/// A banner sliding down from the top when a code is scanned anywhere
/// (menu, start screen): green when applied, red when refused.
class CouponToast extends StatefulWidget {
  const CouponToast({super.key});

  @override
  State<CouponToast> createState() => _CouponToastState();
}

class _CouponToastState extends State<CouponToast> {
  int _seen = 0;
  bool _visible = false;
  int _shown = 0;
  bool _bound = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final k = KioskScope.of(context);
    if (!_bound) {
      _bound = true;
      _seen = k.couponAttempt;
    }
    if (k.couponAttempt != _seen) {
      _seen = k.couponAttempt;
      // The sheet shows its own result.
      if (!CouponSheet.isOpen) _show();
    }
  }

  /// Kept in the tree only while showing or sliding away.
  bool _onstage = false;

  void _show() {
    final id = ++_shown;
    _visible = true;
    _onstage = true;
    Future.delayed(const Duration(milliseconds: 2800), () {
      if (mounted && id == _shown) setState(() => _visible = false);
    });
    Future.delayed(const Duration(milliseconds: 3500), () {
      if (mounted && id == _shown) setState(() => _onstage = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final k = context.kiosk;
    final t = context.t;
    final ok = k.couponErrorKey == null && k.coupon != null;
    final text = ok
        ? t('couponAppliedToast', args: {'code': k.coupon!.code})
        : k.couponErrorKey == null
        ? ''
        : couponProblem(context, k.couponErrorKey!);
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Offstage(
        offstage: !_onstage,
        child: IgnorePointer(
          ignoring: !_visible,
          child: AnimatedSlide(
            duration: K.slow,
            curve: _visible ? Curves.easeOutBack : Curves.easeIn,
            offset: _visible ? Offset.zero : const Offset(0, -1.6),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(40, 44, 40, 0),
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    key: const ValueKey('coupon-toast'),
                    padding: const EdgeInsets.fromLTRB(20, 16, 26, 16),
                    decoration: BoxDecoration(
                      color: ok ? _green : K.danger,
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: K.shadowStrong,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            ok
                                ? Icons.local_offer_rounded
                                : Icons.close_rounded,
                            color: ok ? _green : K.danger,
                            size: 32,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                text,
                                style: KText.h3.copyWith(color: Colors.white),
                              ),
                              if (ok)
                                Text(
                                  couponTitle(context, k.coupon!),
                                  style: KText.body.copyWith(
                                    color: Colors.white.withValues(alpha: 0.85),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
