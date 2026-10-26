import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:kiosk_core/kiosk_core.dart';

import '../../i18n.dart';
import '../theme.dart';
import 'particles.dart';

/// One of the [HolidayArt] pictures.
class HolidayArtwork extends StatelessWidget {
  final String svg;
  final double? width;
  final double? height;
  const HolidayArtwork(this.svg, {super.key, this.width, this.height});

  @override
  Widget build(BuildContext context) =>
      SvgPicture.string(svg, width: width, height: height, fit: BoxFit.contain);
}

/// "Buon Natale!" and the like, in the customer's language.
String holidayGreeting(Strings t, HolidayTheme theme, [DateTime? now]) {
  final today = now ?? DateTime.now();
  // From late December the toast is already for the coming year.
  final year = today.month == 12 ? today.year + 1 : today.year;
  return t('holiday.${theme.id}', args: {'year': year});
}

/// Festive pill with the greeting, for the hero screens.
class HolidayGreeting extends StatelessWidget {
  final HolidayTheme theme;
  final String text;
  const HolidayGreeting({super.key, required this.theme, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
          key: const ValueKey('holiday-greeting'),
          padding: const EdgeInsets.fromLTRB(14, 8, 26, 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(40),
            boxShadow: const [
              BoxShadow(
                color: Color(0x40000000),
                blurRadius: 24,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox.square(
                dimension: 46,
                child: HolidayArtwork(HolidayArt.hero(theme.id)),
              ),
              const SizedBox(width: 12),
              AnimatedSwitcher(
                duration: K.medium,
                child: Text(
                  text,
                  key: ValueKey(text),
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    color: K.primary,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ],
          ),
        )
        .animate()
        .scale(
          begin: const Offset(0.6, 0.6),
          duration: 700.ms,
          curve: Curves.elasticOut,
        )
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .rotate(begin: -0.008, end: 0.008, duration: 1600.ms);
  }
}

/// What the venue logo wears for the holiday: a hat, bunny ears, a flower.
/// Sizes and offsets are fractions of the logo size.
class LogoAccessory extends StatelessWidget {
  final HolidayTheme theme;
  final double size;
  const LogoAccessory({super.key, required this.theme, required this.size});

  /// Ears stand behind the logo, everything else sits on it.
  static bool behind(HolidayTheme theme) => theme.id == 'easter';

  @override
  Widget build(BuildContext context) {
    final (left, top, width, angle) = switch (theme.id) {
      'christmas' => (0.22, -0.5, 0.95, 0.28),
      'halloween' => (0.1, -0.62, 0.95, 0.2),
      'newYear' => (0.44, -0.66, 0.68, 0.42),
      'carnival' => (0.06, -0.6, 0.92, 0.12),
      'easter' => (0.1, -0.58, 0.8, 0.0),
      'valentine' => (0.66, -0.12, 0.44, 0.3),
      'summer' => (-0.1, -0.14, 0.5, -0.3),
      _ => (0.6, -0.2, 0.4, 0.0),
    };
    Widget art = Transform.rotate(
      angle: angle,
      child: HolidayArtwork(
        HolidayArt.accessory(theme.id),
        width: width * size,
        height: width * size * (theme.id == 'newYear' ? 1.25 : 1),
      ),
    );
    if (theme.id == 'valentine') {
      art = art
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .scaleXY(
            begin: 1,
            end: 1.15,
            duration: 600.ms,
            curve: Curves.easeInOut,
          );
    }
    return Positioned(
      left: left * size,
      top: top * size,
      child: IgnorePointer(child: art),
    );
  }
}

/// Repaints [painter] on every frame with the seconds elapsed.
class _Ticking extends StatefulWidget {
  final CustomPainter Function(ValueNotifier<double> time) painter;
  const _Ticking({required this.painter});

  @override
  State<_Ticking> createState() => _TickingState();
}

class _TickingState extends State<_Ticking>
    with SingleTickerProviderStateMixin {
  final _time = ValueNotifier(0.0);
  late final Ticker _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((e) => _time.value = e.inMicroseconds / 1e6)
      ..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _time.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: CustomPaint(size: Size.infinite, painter: widget.painter(_time)),
  );
}

/// A string of lights, pennants, hearts or tinsel hanging across the top.
class HolidayGarland extends StatelessWidget {
  final HolidayTheme theme;
  final double height;

  /// Hung on a light page rather than a coloured hero.
  final bool onLight;
  const HolidayGarland({
    super.key,
    required this.theme,
    this.height = 90,
    this.onLight = false,
  });

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: SizedBox(
      height: height,
      width: double.infinity,
      child: _Ticking(
        painter: (time) => _GarlandPainter(theme.id, onLight, time),
      ),
    ),
  );
}

class _GarlandPainter extends CustomPainter {
  final String kind;
  final bool onLight;
  final ValueNotifier<double> time;
  _GarlandPainter(this.kind, this.onLight, this.time) : super(repaint: time);

  List<Color> get _colors => switch (kind) {
    'christmas' => const [
      Color(0xFFFF4A5E),
      Color(0xFFFFD34D),
      Color(0xFF4ADE80),
      Color(0xFF60A5FA),
      Color(0xFFFF9F43),
    ],
    'halloween' => const [
      Color(0xFFFF8A1C),
      Color(0xFF2B1640),
      Color(0xFF8B48C6),
      Color(0xFF7ED957),
    ],
    'valentine' => [
      const Color(0xFFE0194A),
      const Color(0xFFFF8FAB),
      onLight ? const Color(0xFFFFC6D5) : const Color(0xFFFFFFFF),
    ],
    'carnival' => const [
      Color(0xFFF03F8C),
      Color(0xFFFFD23F),
      Color(0xFF2EC4B6),
      Color(0xFF8E3FD1),
      Color(0xFFFF8A1C),
    ],
    'easter' => const [
      Color(0xFFB9A2F0),
      Color(0xFFFFE07A),
      Color(0xFF8FD9B6),
      Color(0xFFFFB3CE),
      Color(0xFF9AD0F5),
    ],
    'newYear' => const [Color(0xFFF5C451), Color(0xFFDDE3EE)],
    'summer' => [
      const Color(0xFFFF5D73),
      const Color(0xFFFFD166),
      const Color(0xFF14B8C4),
      onLight ? const Color(0xFF7FD3E8) : const Color(0xFFFFFFFF),
      const Color(0xFFFF9F43),
    ],
    _ => const [Colors.white],
  };

  @override
  void paint(Canvas canvas, Size size) {
    final t = time.value;
    final spans = max(2, (size.width / 380).round());
    final span = size.width / spans;
    final sag = size.height * 0.42;
    final wire = Paint()
      ..color = kind == 'christmas'
          ? const Color(0xFF1F4D2B)
          : kind == 'newYear'
          ? const Color(0xFFF5C451)
          : onLight
          ? const Color(0x661B1B1F)
          : const Color(0xCCFFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = kind == 'newYear' ? 3 : 2.5;
    var index = 0;
    for (var s = 0; s < spans; s++) {
      final x0 = s * span;
      final path = Path()
        ..moveTo(x0, 4)
        ..quadraticBezierTo(x0 + span / 2, 4 + sag * 2, x0 + span, 4);
      if (kind == 'newYear') _tinsel(canvas, path, t);
      canvas.drawPath(path, wire);
      final metric = path.computeMetrics().first;
      final step = kind == 'christmas' ? 48.0 : 58.0;
      final count = (metric.length / step).floor();
      for (var i = 1; i < count; i++) {
        final pos = metric.getTangentForOffset(i * metric.length / count)!;
        _item(canvas, pos.position, index++, t);
      }
    }
  }

  void _tinsel(Canvas canvas, Path path, double t) {
    final metric = path.computeMetrics().first;
    for (var d = 0.0; d < metric.length; d += 7) {
      final p = metric.getTangentForOffset(d)!.position;
      final shine = 0.5 + 0.5 * sin(t * 3 + d * 0.15);
      canvas.drawCircle(
        p,
        5,
        Paint()
          ..color = Color.lerp(
            const Color(0xFFE9A825),
            const Color(0xFFFFF2C2),
            shine,
          )!,
      );
    }
  }

  void _item(Canvas canvas, Offset p, int i, double t) {
    final colors = _colors;
    final color = colors[i % colors.length];
    final sway = sin(t * 1.6 + i * 0.9) * 0.12;
    canvas.save();
    canvas.translate(p.dx, p.dy);
    canvas.rotate(sway);
    switch (kind) {
      case 'christmas':
        final lit = sin(t * 2.2 + i * 1.7) > -0.35;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(-4.5, 0, 9, 9),
            const Radius.circular(2),
          ),
          Paint()..color = const Color(0xFF2A3B2E),
        );
        final bulb = Rect.fromCenter(
          center: const Offset(0, 21),
          width: 16,
          height: 24,
        );
        if (lit) {
          canvas.drawCircle(
            const Offset(0, 21),
            22,
            Paint()
              ..color = color.withValues(alpha: 0.45)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
          );
        }
        canvas.drawOval(
          bulb,
          Paint()..color = lit ? color : Color.lerp(color, Colors.black, 0.45)!,
        );
        canvas.drawOval(
          Rect.fromCenter(center: const Offset(-3, 16), width: 4, height: 8),
          Paint()..color = Colors.white.withValues(alpha: lit ? 0.75 : 0.25),
        );
      case 'valentine':
        canvas.drawLine(
          Offset.zero,
          const Offset(0, 8),
          Paint()
            ..color = onLight
                ? const Color(0x661B1B1F)
                : const Color(0xCCFFFFFF)
            ..strokeWidth = 2,
        );
        canvas.translate(0, 22);
        canvas.drawPath(heartPath(14), Paint()..color = color);
      case 'newYear':
        final star = i.isEven;
        canvas.drawLine(
          Offset.zero,
          const Offset(0, 14),
          Paint()
            ..color = const Color(0xFFF5C451)
            ..strokeWidth = 1.5,
        );
        canvas.translate(0, 26);
        canvas.rotate(t * 0.8 + i);
        final paint = Paint()..color = star ? const Color(0xFFFFE08A) : color;
        if (star) {
          canvas.drawPath(_star(12, 5), paint);
        } else {
          canvas.drawCircle(Offset.zero, 9, paint);
          canvas.drawCircle(
            const Offset(-3, -3),
            3,
            Paint()..color = Colors.white.withValues(alpha: 0.8),
          );
        }
      default:
        final flag = Path()
          ..moveTo(-17, 0)
          ..lineTo(17, 0)
          ..lineTo(0, 40)
          ..close();
        canvas.drawPath(
          flag.shift(const Offset(1.5, 3)),
          Paint()..color = const Color(0x22000000),
        );
        canvas.drawPath(flag, Paint()..color = color);
        canvas.drawPath(
          Path()
            ..moveTo(-17, 0)
            ..lineTo(17, 0)
            ..lineTo(15, 5)
            ..lineTo(-15, 5)
            ..close(),
          Paint()..color = Colors.white.withValues(alpha: 0.35),
        );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_GarlandPainter old) =>
      old.kind != kind || old.onLight != onLight;
}

Path _star(double r, int points) {
  final path = Path();
  for (var i = 0; i < points * 2; i++) {
    final rr = i.isEven ? r : r * 0.45;
    final a = -pi / 2 + i * pi / points;
    final p = Offset(cos(a) * rr, sin(a) * rr);
    i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
  }
  return path..close();
}

/// Full-screen decorations for the coloured hero screens (attract, order
/// confirmation): sky elements, the ground, artwork in the bottom corners
/// and the ambient animation. Sits behind the content.
class HolidayScene extends StatelessWidget {
  final HolidayTheme theme;

  /// Leaves the garland out, for screens with their own header.
  final bool garland;

  /// For the light pages: lighter animation and no sky.
  final bool onLight;
  const HolidayScene({
    super.key,
    required this.theme,
    this.garland = true,
    this.onLight = false,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (!onLight) ..._sky(),
          HolidayParticles(
            theme: theme,
            onLight: onLight,
            density: onLight ? 0.7 : 1,
          ),
          ..._ground(),
          ..._corners(),
          if (garland)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: HolidayGarland(theme: theme, onLight: onLight),
            ),
        ],
      ),
    );
  }

  List<Widget> _sky() => switch (theme.id) {
    'halloween' => [
      Positioned(
        left: -30,
        top: 150,
        child: Container(
          width: 230,
          height: 230,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [Color(0xFFFFF6D6), Color(0xFFFFE7A0)],
            ),
            boxShadow: [
              BoxShadow(
                color: Color(0x66FFE7A0),
                blurRadius: 90,
                spreadRadius: 30,
              ),
            ],
          ),
          child: CustomPaint(painter: _CratersPainter()),
        ),
      ),
    ],
    'summer' => [
      Positioned(
        right: 30,
        top: 120,
        width: 240,
        height: 240,
        child: Stack(
          fit: StackFit.expand,
          children: [
            const HolidayArtwork(
              HolidayArt.sunRays,
            ).animate(onPlay: (c) => c.repeat()).rotate(duration: 24.seconds),
            const Padding(
              padding: EdgeInsets.all(16),
              child: HolidayArtwork(HolidayArt.sunFace),
            ),
          ],
        ),
      ),
    ],
    _ => const [],
  };

  Widget _band(double height, Widget child) =>
      Positioned(left: 0, right: 0, bottom: 0, height: height, child: child);

  List<Widget> _ground() => switch (theme.id) {
    'halloween' => [_band(300, CustomPaint(painter: _GraveyardPainter()))],
    'christmas' => [_band(210, CustomPaint(painter: _SnowBankPainter()))],
    'newYear' => [
      _band(340, _Ticking(painter: (time) => _SkylinePainter(time))),
    ],
    'easter' => [_band(200, _Ticking(painter: (time) => _GrassPainter(time)))],
    'summer' => [_band(230, _Ticking(painter: (time) => _WavesPainter(time)))],
    _ => const [],
  };

  List<Widget> _corners() {
    Widget bob(Widget w, {double by = 12, int ms = 2200, int delay = 0}) => w
        .animate(delay: delay.ms, onPlay: (c) => c.repeat(reverse: true))
        .moveY(begin: -by, end: by, duration: ms.ms, curve: Curves.easeInOut);

    Widget sway(Widget w, {double by = 0.015, int ms = 2600}) => w
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .rotate(
          begin: -by,
          end: by,
          duration: ms.ms,
          curve: Curves.easeInOut,
          alignment: Alignment.bottomCenter,
        );

    return switch (theme.id) {
      'halloween' => [
        Positioned(left: 4, bottom: 26, child: _GlowingPumpkin(size: 230)),
        Positioned(
          right: 14,
          bottom: 22,
          child: _GlowingPumpkin(size: 170, delay: 700),
        ),
        Positioned(
          right: 40,
          bottom: 300,
          child: bob(
            const HolidayArtwork(HolidayArt.ghost, width: 170)
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .fade(begin: 0.95, end: 0.55, duration: 2400.ms)
                .moveX(begin: -10, end: 10, duration: 3100.ms),
            by: 18,
            ms: 1900,
          ),
        ),
        const Positioned(right: 150, top: 0, child: _Spider()),
      ],
      'christmas' => [
        Positioned(
          left: 4,
          bottom: 44,
          child: sway(
            const HolidayArtwork(HolidayArt.tree, width: 230),
            by: 0.015,
          ),
        ),
        Positioned(
          right: 8,
          bottom: 50,
          child: const HolidayArtwork(HolidayArt.gifts, width: 220)
              .animate(onPlay: (c) => c.repeat())
              .shake(hz: 3, rotation: 0.03, delay: 2.seconds, duration: 600.ms)
              .then(delay: 2.seconds),
        ),
      ],
      'newYear' => [
        Positioned(
          left: 10,
          bottom: 50,
          child: const HolidayArtwork(HolidayArt.toast, width: 220)
              .animate(onPlay: (c) => c.repeat())
              .rotate(
                begin: 0,
                end: 0.012,
                duration: 260.ms,
                delay: 1600.ms,
                alignment: Alignment.bottomCenter,
              )
              .then()
              .rotate(begin: 0, end: -0.012, duration: 300.ms),
        ),
        Positioned(
          right: 110,
          bottom: 210,
          child: bob(
            HolidayArtwork(HolidayArt.balloon('#F5C451'), width: 100),
            ms: 2100,
          ),
        ),
        Positioned(
          right: 20,
          bottom: 150,
          child: bob(
            HolidayArtwork(HolidayArt.balloon('#DDE3EE'), width: 112),
            ms: 2500,
            delay: 400,
          ),
        ),
      ],
      'valentine' => [
        Positioned(
          left: 24,
          bottom: 210,
          child: bob(
            const HolidayArtwork(HolidayArt.heartBalloon, width: 130),
            ms: 2300,
          ),
        ),
        Positioned(
          left: 140,
          bottom: 320,
          child: bob(
            const HolidayArtwork(HolidayArt.heartBalloon, width: 96),
            ms: 2700,
            delay: 600,
          ),
        ),
        Positioned(
          right: 14,
          bottom: 40,
          child: const HolidayArtwork(HolidayArt.loveLetter, width: 220)
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .rotate(begin: -0.012, end: 0.01, duration: 1800.ms),
        ),
        Positioned(
          left: 30,
          bottom: 40,
          child: const HolidayArtwork(HolidayArt.heart, width: 130)
              .animate(onPlay: (c) => c.repeat())
              .scaleXY(begin: 1, end: 1.12, duration: 160.ms)
              .then()
              .scaleXY(begin: 1, end: 1 / 1.12, duration: 200.ms)
              .then()
              .scaleXY(begin: 1, end: 1.1, duration: 160.ms)
              .then()
              .scaleXY(begin: 1, end: 1 / 1.1, duration: 300.ms)
              .then(delay: 900.ms),
        ),
      ],
      'carnival' => [
        Positioned(
          left: 6,
          bottom: 40,
          child: bob(
            const HolidayArtwork(HolidayArt.mask, width: 240)
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .rotate(begin: -0.02, end: 0.015, duration: 2600.ms),
            by: 10,
          ),
        ),
        for (final (i, (color, right, bottom, w)) in [
          ('#FFD23F', 140.0, 170.0, 96.0),
          ('#2EC4B6', 66.0, 240.0, 106.0),
          ('#F03F8C', 14.0, 120.0, 114.0),
        ].indexed)
          Positioned(
            right: right,
            bottom: bottom,
            child: bob(
              HolidayArtwork(HolidayArt.balloon(color), width: w),
              ms: 2000 + i * 350,
              delay: i * 300,
            ),
          ),
      ],
      'easter' => [
        Positioned(
          left: 4,
          bottom: 52,
          child: HolidayArtwork(HolidayArt.eggs[0], width: 104),
        ),
        Positioned(
          left: 90,
          bottom: 40,
          child: HolidayArtwork(HolidayArt.eggs[2], width: 86),
        ),
        Positioned(
          left: 60,
          bottom: 150,
          child: const HolidayArtwork(HolidayArt.chick, width: 120)
              .animate(onPlay: (c) => c.repeat())
              .moveY(begin: 0, end: -18, duration: 220.ms, delay: 1800.ms)
              .then()
              .moveY(
                begin: 0,
                end: 18,
                duration: 300.ms,
                curve: Curves.bounceOut,
              ),
        ),
        Positioned(
          right: 10,
          bottom: 0,
          child: ClipRect(
            child: SizedBox(
              width: 230,
              height: 300,
              child:
                  const Align(
                        alignment: Alignment.bottomCenter,
                        child: HolidayArtwork(HolidayArt.bunny, width: 220),
                      )
                      .animate(onPlay: (c) => c.repeat())
                      .moveY(
                        begin: 160,
                        end: 0,
                        duration: 700.ms,
                        curve: Curves.easeOutBack,
                      )
                      .then(delay: 2800.ms)
                      .moveY(
                        begin: 0,
                        end: 160,
                        duration: 500.ms,
                        curve: Curves.easeIn,
                      )
                      .then(delay: 900.ms),
            ),
          ),
        ),
      ],
      'summer' => [
        Positioned(
          left: -16,
          bottom: 70,
          child: sway(
            const HolidayArtwork(HolidayArt.palm, width: 250),
            by: 0.012,
            ms: 3200,
          ),
        ),
        Positioned(
          right: 40,
          bottom: 60,
          child: const HolidayArtwork(HolidayArt.beachBall, width: 120)
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .custom(
                duration: 650.ms,
                curve: Curves.easeOutQuad,
                builder: (_, v, child) => Transform.translate(
                  offset: Offset(0, -130 * v),
                  child: Transform.rotate(angle: v * 2.2, child: child),
                ),
              ),
        ),
        Positioned(
          right: 150,
          bottom: 50,
          child: sway(
            const HolidayArtwork(HolidayArt.iceCream, width: 76),
            by: 0.025,
          ),
        ),
      ],
      _ => const [],
    };
  }
}

/// A jack-o'-lantern whose candle flickers.
class _GlowingPumpkin extends StatelessWidget {
  final double size;
  final int delay;
  const _GlowingPumpkin({required this.size, this.delay = 0});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
                width: size * 0.9,
                height: size * 0.9,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [Color(0x99FFB81C), Color(0x00FFB81C)],
                  ),
                ),
              )
              .animate(delay: delay.ms, onPlay: (c) => c.repeat(reverse: true))
              .fade(begin: 0.45, end: 1, duration: 180.ms)
              .then()
              .fade(begin: 1, end: 0.7, duration: 420.ms)
              .scaleXY(begin: 1, end: 1.08, duration: 600.ms),
          HolidayArtwork(HolidayArt.pumpkin, width: size),
        ],
      ),
    );
  }
}

/// A spider going up and down its thread.
class _Spider extends StatelessWidget {
  const _Spider();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 60,
      height: 420,
      child: _Ticking(painter: (time) => _SpiderPainter(time)),
    );
  }
}

class _SpiderPainter extends CustomPainter {
  final ValueNotifier<double> time;
  _SpiderPainter(this.time) : super(repaint: time);

  @override
  void paint(Canvas canvas, Size size) {
    final t = time.value;
    final drop = 200 + sin(t * 0.9) * 110 + sin(t * 2.3) * 12;
    final x = size.width / 2;
    canvas.drawLine(
      Offset(x, 0),
      Offset(x, drop - 14),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.6)
        ..strokeWidth = 1.5,
    );
    canvas.save();
    canvas.translate(x, drop);
    canvas.rotate(sin(t * 1.7) * 0.15);
    final body = Paint()..color = const Color(0xFF15091F);
    final legs = Paint()
      ..color = const Color(0xFF15091F)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    final wiggle = sin(t * 8) * 3;
    for (final side in [-1.0, 1.0]) {
      for (var i = 0; i < 4; i++) {
        final y = -6.0 + i * 5;
        canvas.drawPath(
          Path()
            ..moveTo(0, y)
            ..quadraticBezierTo(
              side * 16,
              y - 12 + (i.isEven ? wiggle : -wiggle),
              side * (22 + i * 1.5),
              y + 8 + i * 2,
            ),
          legs,
        );
      }
    }
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(0, 6), width: 24, height: 28),
      body,
    );
    canvas.drawCircle(const Offset(0, -10), 9, body);
    final eye = Paint()..color = Colors.white;
    canvas.drawCircle(const Offset(-3.5, -11), 3, eye);
    canvas.drawCircle(const Offset(3.5, -11), 3, eye);
    final pupil = Paint()..color = Colors.black;
    canvas.drawCircle(const Offset(-3, -10.5), 1.4, pupil);
    canvas.drawCircle(const Offset(4, -10.5), 1.4, pupil);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_SpiderPainter old) => false;
}

class _CratersPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0x1FB08A3A);
    for (final (x, y, r) in [
      (0.32, 0.36, 0.11),
      (0.62, 0.3, 0.07),
      (0.55, 0.62, 0.13),
      (0.28, 0.66, 0.06),
    ]) {
      canvas.drawCircle(
        Offset(x * size.width, y * size.height),
        r * size.width,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_CratersPainter old) => false;
}

class _GraveyardPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final far = Paint()..color = const Color(0x661A0A2A);
    canvas.drawPath(
      Path()
        ..moveTo(0, h * 0.45)
        ..quadraticBezierTo(w * 0.3, h * 0.15, w * 0.62, h * 0.42)
        ..quadraticBezierTo(w * 0.85, h * 0.6, w, h * 0.35)
        ..lineTo(w, h)
        ..lineTo(0, h)
        ..close(),
      far,
    );
    final near = Paint()..color = const Color(0xFF1A0A2A);
    // Tombstones and a fence on the far hill.
    for (final (x, tw, th, tilt) in [
      (0.36, 46.0, 70.0, -0.08),
      (0.47, 38.0, 56.0, 0.1),
      (0.7, 50.0, 76.0, 0.05),
    ]) {
      canvas.save();
      canvas.translate(x * w, h * 0.5);
      canvas.rotate(tilt);
      canvas.drawRRect(
        RRect.fromRectAndCorners(
          Rect.fromLTWH(-tw / 2, -th, tw, th + 30),
          topLeft: Radius.circular(tw / 2),
          topRight: Radius.circular(tw / 2),
        ),
        Paint()..color = const Color(0xFF2B1640),
      );
      canvas.drawLine(
        Offset(0, -th + 16),
        Offset(0, -th + 40),
        Paint()
          ..color = const Color(0x55FFFFFF)
          ..strokeWidth = 4,
      );
      canvas.drawLine(
        Offset(-9, -th + 24),
        Offset(9, -th + 24),
        Paint()
          ..color = const Color(0x55FFFFFF)
          ..strokeWidth = 4,
      );
      canvas.restore();
    }
    canvas.drawPath(
      Path()
        ..moveTo(0, h * 0.72)
        ..quadraticBezierTo(w * 0.25, h * 0.55, w * 0.5, h * 0.7)
        ..quadraticBezierTo(w * 0.78, h * 0.85, w, h * 0.62)
        ..lineTo(w, h)
        ..lineTo(0, h)
        ..close(),
      near,
    );
  }

  @override
  bool shouldRepaint(_GraveyardPainter old) => false;
}

class _SnowBankPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    canvas.drawPath(
      Path()
        ..moveTo(0, h * 0.35)
        ..quadraticBezierTo(w * 0.2, h * 0.05, w * 0.42, h * 0.32)
        ..quadraticBezierTo(w * 0.62, h * 0.55, w * 0.8, h * 0.2)
        ..quadraticBezierTo(w * 0.92, h * 0.02, w, h * 0.22)
        ..lineTo(w, h)
        ..lineTo(0, h)
        ..close(),
      Paint()..color = const Color(0xFFDCE7F5),
    );
    canvas.drawPath(
      Path()
        ..moveTo(0, h * 0.55)
        ..quadraticBezierTo(w * 0.3, h * 0.3, w * 0.55, h * 0.56)
        ..quadraticBezierTo(w * 0.8, h * 0.78, w, h * 0.5)
        ..lineTo(w, h)
        ..lineTo(0, h)
        ..close(),
      Paint()..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(_SnowBankPainter old) => false;
}

class _SkylinePainter extends CustomPainter {
  final ValueNotifier<double> time;
  _SkylinePainter(this.time) : super(repaint: time);

  @override
  void paint(Canvas canvas, Size size) {
    final t = time.value;
    final w = size.width, h = size.height;
    final r = Random(42);
    var x = -10.0;
    final building = Paint()..color = const Color(0xFF0A1027);
    while (x < w) {
      final bw = 70 + r.nextDouble() * 90;
      final bh = h * (0.35 + r.nextDouble() * 0.55);
      final rect = Rect.fromLTWH(x, h - bh, bw, bh);
      canvas.drawRect(rect, building);
      for (var wy = rect.top + 18; wy < h - 20; wy += 28) {
        for (var wx = rect.left + 14; wx < rect.right - 18; wx += 24) {
          final seed = (wx * 7 + wy * 13).floor();
          final on = (seed % 5) != 0 && sin(t * 0.3 + seed) > -0.85;
          if (!on) continue;
          canvas.drawRect(
            Rect.fromLTWH(wx, wy, 10, 14),
            Paint()
              ..color = const Color(
                0xFFFFE08A,
              ).withValues(alpha: 0.35 + (seed % 3) * 0.2),
          );
        }
      }
      x += bw + 4;
    }
  }

  @override
  bool shouldRepaint(_SkylinePainter old) => false;
}

class _GrassPainter extends CustomPainter {
  final ValueNotifier<double> time;
  _GrassPainter(this.time) : super(repaint: time);

  @override
  void paint(Canvas canvas, Size size) {
    final t = time.value;
    final w = size.width, h = size.height;
    canvas.drawPath(
      Path()
        ..moveTo(0, h * 0.55)
        ..quadraticBezierTo(w * 0.3, h * 0.35, w * 0.6, h * 0.55)
        ..quadraticBezierTo(w * 0.85, h * 0.7, w, h * 0.5)
        ..lineTo(w, h)
        ..lineTo(0, h)
        ..close(),
      Paint()..color = const Color(0xFF5FBF62),
    );
    final r = Random(3);
    for (var x = 0.0; x < w; x += 9) {
      final bh = 30 + r.nextDouble() * 40;
      final lean = sin(t * 1.3 + x * 0.02) * 8 + (r.nextDouble() - 0.5) * 10;
      final base = h * 0.62;
      canvas.drawPath(
        Path()
          ..moveTo(x - 5, base + 10)
          ..quadraticBezierTo(
            x + lean * 0.4,
            base - bh * 0.5,
            x + lean,
            base - bh,
          )
          ..quadraticBezierTo(x + lean * 0.3, base - bh * 0.4, x + 5, base + 10)
          ..close(),
        Paint()
          ..color = r.nextBool()
              ? const Color(0xFF4CAF50)
              : const Color(0xFF7ED36F),
      );
    }
    canvas.drawRect(
      Rect.fromLTWH(0, h * 0.62, w, h * 0.38),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF6CC86A), Color(0xFF43A047)],
        ).createShader(Rect.fromLTWH(0, h * 0.62, w, h * 0.38)),
    );
    // Daisies in the grass.
    for (final fx in [0.33, 0.58, 0.67, 0.9]) {
      final c = Offset(fx * w, h * 0.66 + sin(fx * 40) * 8);
      for (var i = 0; i < 6; i++) {
        final a = i * pi / 3 + t * 0.2;
        canvas.drawCircle(
          c + Offset(cos(a), sin(a)) * 8,
          6,
          Paint()..color = Colors.white,
        );
      }
      canvas.drawCircle(c, 5.5, Paint()..color = const Color(0xFFFFC21A));
    }
  }

  @override
  bool shouldRepaint(_GrassPainter old) => false;
}

class _WavesPainter extends CustomPainter {
  final ValueNotifier<double> time;
  _WavesPainter(this.time) : super(repaint: time);

  @override
  void paint(Canvas canvas, Size size) {
    final t = time.value;
    final w = size.width, h = size.height;
    final layers = [
      (0.18, 0.22, 26.0, 0.9, const Color(0x5539D0E6)),
      (0.38, 0.34, 20.0, -1.2, const Color(0x8826B5D6)),
      (0.62, 0.5, 16.0, 1.5, const Color(0xFFF4DDA6)),
    ];
    for (final (top, freq, amp, speed, color) in layers) {
      final path = Path()..moveTo(0, h);
      for (var x = 0.0; x <= w; x += 8) {
        path.lineTo(
          x,
          h * top + sin(x / w * pi * 2 / freq * 0.5 + t * speed) * amp,
        );
      }
      path
        ..lineTo(w, h)
        ..close();
      canvas.drawPath(path, Paint()..color = color);
    }
    // Foam on the shore.
    final foam = Path();
    for (var x = 0.0; x <= w; x += 8) {
      final y = h * 0.62 + sin(x / w * pi * 2 / 0.5 * 0.5 + t * 1.5) * 16;
      x == 0 ? foam.moveTo(x, y) : foam.lineTo(x, y);
    }
    canvas.drawPath(
      foam,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_WavesPainter old) => false;
}
