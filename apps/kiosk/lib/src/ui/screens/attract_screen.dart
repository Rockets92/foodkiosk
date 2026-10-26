import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:kiosk_core/kiosk_core.dart';

import '../../i18n.dart';
import '../holiday/decor.dart';
import '../scope.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/net_image.dart';

/// Idle screen: a rotating sunburst with the featured products cycling
/// through, and a pulsing call to action. Any touch starts an order.
class AttractScreen extends StatefulWidget {
  const AttractScreen({super.key});

  @override
  State<AttractScreen> createState() => _AttractScreenState();
}

class _AttractScreenState extends State<AttractScreen>
    with SingleTickerProviderStateMixin {
  late final _spin = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 60),
  )..repeat();
  Timer? _timer;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (mounted) setState(() => _index++);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _spin.dispose();
    super.dispose();
  }

  List<Product> _featured(Menu menu) {
    final withBadge = menu.products.where(
      (p) => !p.badge.isEmpty && !p.soldOut,
    );
    final firsts = [
      for (final c in menu.categories)
        ...menu.productsIn(c.id).where((p) => !p.soldOut).take(1),
    ];
    return {...withBadge, ...firsts}.take(6).toList();
  }

  @override
  Widget build(BuildContext context) {
    final k = context.kiosk;
    final langs = k.settings.languages;
    final t = Strings(langs[_index % langs.length]);
    final featured = _featured(k.menu);
    final product = featured.isEmpty
        ? null
        : featured[_index % featured.length];
    String money(int c) => formatCents(c, symbol: k.settings.currencySymbol);
    final holiday = K.holiday;

    return GestureDetector(
      key: const ValueKey('attract'),
      behavior: HitTestBehavior.opaque,
      onTap: k.start,
      child: Material(
        type: MaterialType.transparency,
        child: DecoratedBox(
          decoration: BoxDecoration(gradient: K.heroGradient),
          child: Stack(
            fit: StackFit.expand,
            children: [
              AnimatedBuilder(
                animation: _spin,
                builder: (_, _) => CustomPaint(
                  painter: _SunburstPainter(_spin.value * 2 * pi),
                ),
              ),
              if (holiday != null)
                HolidayScene(
                  key: ValueKey('holiday-${holiday.id}'),
                  theme: holiday,
                ),
              SafeArea(
                child: Column(
                  children: [
                    SizedBox(height: holiday == null ? 48 : 130),
                    const VenueLogo(size: 150).animate().scale(
                      duration: 700.ms,
                      curve: Curves.elasticOut,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      k.settings.venueName.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 30,
                        letterSpacing: 6,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (holiday != null) ...[
                      const SizedBox(height: 22),
                      HolidayGreeting(
                        theme: holiday,
                        text: holidayGreeting(t, holiday),
                      ),
                    ],
                    Expanded(
                      child: product == null
                          ? const SizedBox()
                          : AnimatedSwitcher(
                              duration: const Duration(milliseconds: 700),
                              switchInCurve: Curves.easeOutBack,
                              transitionBuilder: (child, anim) =>
                                  FadeTransition(
                                    opacity: anim,
                                    child: ScaleTransition(
                                      scale: Tween(
                                        begin: 0.85,
                                        end: 1.0,
                                      ).animate(anim),
                                      child: child,
                                    ),
                                  ),
                              child: _Featured(
                                key: ValueKey('${product.id}-${t.lang}'),
                                product: product,
                                t: t,
                                price: money(product.priceCents),
                              ),
                            ),
                    ),
                    _Cta(text: t('touchToOrder')),
                    if (k.discountsEnabled && k.settings.discounts.scanner)
                      Padding(
                        padding: const EdgeInsets.only(top: 26),
                        child: Container(
                          key: const ValueKey('attract-scan'),
                          padding: const EdgeInsets.fromLTRB(16, 10, 24, 10),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(color: Colors.white38),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                    Icons.qr_code_scanner_rounded,
                                    color: K.accent,
                                    size: 30,
                                  )
                                  .animate(onPlay: (c) => c.repeat())
                                  .shimmer(
                                    duration: 1600.ms,
                                    color: Colors.white,
                                  ),
                              const SizedBox(width: 10),
                              Text(
                                t('couponScanStart'),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    // Holiday artwork stands on the ground below the button.
                    SizedBox(height: holiday == null ? 56 : 150),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Featured extends StatelessWidget {
  final Product product;
  final Strings t;
  final String price;

  const _Featured({
    super.key,
    required this.product,
    required this.t,
    required this.price,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Flexible(
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 560,
                height: 560,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Colors.white.withValues(alpha: 0.28),
                      Colors.white.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
              SizedBox.square(dimension: 560, child: NetImage(product.imageUrl))
                  .animate(onPlay: (c) => c.repeat(reverse: true))
                  .moveY(
                    begin: -10,
                    end: 10,
                    duration: 2.seconds,
                    curve: Curves.easeInOut,
                  ),
              if (!product.badge.isEmpty)
                Positioned(
                  top: 40,
                  right: 40,
                  child: Transform.rotate(
                    angle: 0.2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 22,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: K.accent,
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: K.shadowStrong,
                      ),
                      child: Text(
                        t.text(product.badge).toUpperCase(),
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: K.ink,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        Text(
          t.text(product.name),
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 58,
            fontWeight: FontWeight.w900,
            height: 1.05,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(30),
          ),
          child: Text(
            price,
            style: TextStyle(
              color: K.accent,
              fontSize: 34,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }
}

class _Cta extends StatelessWidget {
  final String text;
  const _Cta({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
          padding: const EdgeInsets.symmetric(horizontal: 56, vertical: 30),
          decoration: BoxDecoration(
            color: K.accent,
            borderRadius: BorderRadius.circular(60),
            boxShadow: const [
              BoxShadow(
                color: Color(0x55000000),
                blurRadius: 30,
                offset: Offset(0, 14),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.touch_app_rounded, size: 50, color: K.ink)
                  .animate(onPlay: (c) => c.repeat())
                  .moveY(
                    begin: 0,
                    end: -8,
                    duration: 500.ms,
                    curve: Curves.easeOut,
                  )
                  .then()
                  .moveY(
                    begin: -8,
                    end: 0,
                    duration: 500.ms,
                    curve: Curves.easeIn,
                  ),
              const SizedBox(width: 18),
              AnimatedSwitcher(
                duration: K.medium,
                child: Text(
                  text,
                  key: ValueKey(text),
                  style: const TextStyle(
                    fontSize: 42,
                    fontWeight: FontWeight.w900,
                    color: K.ink,
                  ),
                ),
              ),
            ],
          ),
        )
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .scaleXY(
          begin: 1,
          end: 1.06,
          duration: 1100.ms,
          curve: Curves.easeInOut,
        )
        .animate(onPlay: (c) => c.repeat())
        .shimmer(delay: 1500.ms, duration: 1400.ms, color: Colors.white54);
  }
}

class _SunburstPainter extends CustomPainter {
  final double angle;
  _SunburstPainter(this.angle);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.45);
    final radius = size.longestSide;
    const rays = 24;
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.06);
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle);
    for (var i = 0; i < rays; i += 2) {
      final a1 = i * 2 * pi / rays;
      final a2 = (i + 1) * 2 * pi / rays;
      canvas.drawPath(
        Path()
          ..moveTo(0, 0)
          ..lineTo(cos(a1) * radius, sin(a1) * radius)
          ..lineTo(cos(a2) * radius, sin(a2) * radius)
          ..close(),
        paint,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_SunburstPainter old) => old.angle != angle;
}
