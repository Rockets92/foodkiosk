import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:kiosk_core/kiosk_core.dart';

/// Endless ambient animation of a holiday: snow, bats, rising hearts,
/// confetti, petals, fireworks or bubbles.
///
/// Everything is a function of the elapsed time, so there is no state to
/// update per frame; [onLight] picks colours that read on the light pages
/// instead of the coloured hero backgrounds.
class HolidayParticles extends StatefulWidget {
  final HolidayTheme theme;
  final bool onLight;

  /// Scales the number of particles (1 = full-screen hero).
  final double density;

  const HolidayParticles({
    super.key,
    required this.theme,
    this.onLight = false,
    this.density = 1,
  });

  @override
  State<HolidayParticles> createState() => _HolidayParticlesState();
}

class _HolidayParticlesState extends State<HolidayParticles>
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
  Widget build(BuildContext context) => IgnorePointer(
    child: RepaintBoundary(
      child: CustomPaint(
        size: Size.infinite,
        painter: _ParticlePainter(
          kind: widget.theme.id,
          onLight: widget.onLight,
          density: widget.density,
          time: _time,
        ),
      ),
    ),
  );
}

/// Random but stable traits of one particle.
class _Seed {
  final double x, phase, speed, size, sway, spin, pick;
  _Seed(Random r)
    : x = r.nextDouble(),
      phase = r.nextDouble(),
      speed = 0.6 + r.nextDouble() * 0.8,
      size = r.nextDouble(),
      sway = r.nextDouble(),
      spin = r.nextDouble() * 2 - 1,
      pick = r.nextDouble();

  T of<T>(List<T> items) => items[(pick * items.length).floor()];
}

final _seeds = List.generate(140, (i) => _Seed(Random(i * 7919 + 13)));

class _ParticlePainter extends CustomPainter {
  final String kind;
  final bool onLight;
  final double density;
  final ValueNotifier<double> time;

  _ParticlePainter({
    required this.kind,
    required this.onLight,
    required this.density,
    required this.time,
  }) : super(repaint: time);

  Iterable<_Seed> _take(int n) => _seeds.take((n * density).round());

  @override
  void paint(Canvas canvas, Size size) {
    final t = time.value;
    switch (kind) {
      case 'christmas':
        _snow(canvas, size, t);
      case 'halloween':
        if (!onLight) _stars(canvas, size, t, const Color(0xFFFFF3C4));
        _bats(canvas, size, t);
      case 'valentine':
        _hearts(canvas, size, t);
      case 'carnival':
        _confetti(canvas, size, t, const [
          Color(0xFFF03F8C),
          Color(0xFFFFD23F),
          Color(0xFF2EC4B6),
          Color(0xFF8E3FD1),
          Color(0xFFFF8A1C),
          Color(0xFF4F8DF7),
        ]);
        _streamers(canvas, size, t);
      case 'easter':
        _petals(canvas, size, t);
      case 'newYear':
        if (onLight) {
          _confetti(canvas, size, t, const [
            Color(0xFFF5C451),
            Color(0xFFE9A825),
            Color(0xFF364C86),
            Color(0xFFC9CED9),
          ], count: 40);
        } else {
          _stars(canvas, size, t, const Color(0xFFFFE08A));
          _fireworks(canvas, size, t);
        }
      case 'summer':
        _bubbles(canvas, size, t);
    }
  }

  // ---- snow ---------------------------------------------------------------

  void _snow(Canvas canvas, Size size, double t) {
    final color = onLight ? const Color(0xFF9FB6D6) : Colors.white;
    for (final s in _take(onLight ? 45 : 90)) {
      final fall = (s.phase + t * s.speed * 0.045) % 1.0;
      final y = -20 + fall * (size.height + 40);
      final x = s.x * size.width + sin(t * (0.6 + s.sway) + s.phase * 9) * 26;
      final crystal = s.pick > 0.78;
      final alpha = (onLight ? 0.35 : 0.55) + s.size * 0.4;
      final paint = Paint()..color = color.withValues(alpha: alpha);
      if (crystal) {
        _flake(canvas, Offset(x, y), 9 + s.size * 11, t * s.spin, paint);
      } else {
        canvas.drawCircle(
          Offset(x, y),
          2.5 + s.size * 5,
          paint
            ..maskFilter = s.size > 0.7
                ? const MaskFilter.blur(BlurStyle.normal, 2)
                : null,
        );
      }
    }
  }

  void _flake(Canvas canvas, Offset c, double r, double angle, Paint fill) {
    final paint = Paint()
      ..color = fill.color
      ..strokeWidth = max(1.6, r / 7)
      ..strokeCap = StrokeCap.round;
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(angle);
    for (var i = 0; i < 6; i++) {
      canvas.drawLine(Offset.zero, Offset(0, -r), paint);
      canvas.drawLine(Offset(0, -r * 0.55), Offset(r * 0.28, -r * 0.8), paint);
      canvas.drawLine(Offset(0, -r * 0.55), Offset(-r * 0.28, -r * 0.8), paint);
      canvas.rotate(pi / 3);
    }
    canvas.restore();
  }

  // ---- twinkling stars ----------------------------------------------------

  void _stars(Canvas canvas, Size size, double t, Color color) {
    for (final s in _seeds.skip(100).take(36)) {
      final twinkle = 0.5 + 0.5 * sin(t * (1.5 + s.sway * 2) + s.phase * 20);
      final p = Offset(s.x * size.width, s.size * size.height * 0.55);
      final r = 1.2 + s.spin.abs() * 2.2;
      canvas.drawCircle(
        p,
        r * (0.7 + twinkle * 0.6),
        Paint()..color = color.withValues(alpha: 0.2 + twinkle * 0.7),
      );
      if (s.pick > 0.8) {
        final glint = Paint()
          ..color = color.withValues(alpha: twinkle * 0.8)
          ..strokeWidth = 1.4;
        final l = r * 4 * twinkle;
        canvas.drawLine(p.translate(-l, 0), p.translate(l, 0), glint);
        canvas.drawLine(p.translate(0, -l), p.translate(0, l), glint);
      }
    }
  }

  // ---- bats ---------------------------------------------------------------

  void _bats(Canvas canvas, Size size, double t) {
    final color = onLight ? const Color(0x556A2C9E) : const Color(0xFF1C0C2C);
    for (final (i, s) in _take(onLight ? 4 : 8).indexed) {
      final p = (s.phase + t * (0.035 + s.speed * 0.025)) % 1.0;
      final leftToRight = i.isEven;
      final x = (leftToRight ? -0.12 + p * 1.24 : 1.12 - p * 1.24) * size.width;
      final y =
          (0.06 + s.sway * (onLight ? 0.8 : 0.42)) * size.height +
          sin(p * pi * 4 + s.phase * 6) * 40;
      final w = 30 + s.size * 34;
      final flap = sin(t * (10 + s.speed * 4) + s.phase * 10);
      _bat(canvas, Offset(x, y), w, flap, leftToRight, color);
    }
  }

  void _bat(
    Canvas canvas,
    Offset c,
    double w,
    double flap,
    bool facingRight,
    Color color,
  ) {
    final paint = Paint()..color = color;
    canvas.save();
    canvas.translate(c.dx, c.dy);
    if (!facingRight) canvas.scale(-1, 1);
    canvas.rotate(0.08 * flap);
    final h = w * 0.55 * flap;
    for (final side in [-1.0, 1.0]) {
      final tip = Offset(side * w, -h - w * 0.1);
      final wing = Path()
        ..moveTo(0, -w * 0.08)
        ..quadraticBezierTo(side * w * 0.45, -h - w * 0.32, tip.dx, tip.dy)
        ..quadraticBezierTo(
          side * w * 0.82,
          -h * 0.55 + w * 0.02,
          side * w * 0.68,
          -h * 0.45 + w * 0.12,
        )
        ..quadraticBezierTo(
          side * w * 0.55,
          -h * 0.3 + w * 0.06,
          side * w * 0.4,
          -h * 0.2 + w * 0.16,
        )
        ..quadraticBezierTo(side * w * 0.25, w * 0.04, 0, w * 0.14)
        ..close();
      canvas.drawPath(wing, paint);
    }
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(0, w * 0.04),
        width: w * 0.3,
        height: w * 0.42,
      ),
      paint,
    );
    final head = Path()
      ..addOval(
        Rect.fromCenter(
          center: Offset(0, -w * 0.16),
          width: w * 0.24,
          height: w * 0.22,
        ),
      )
      ..moveTo(-w * 0.11, -w * 0.2)
      ..lineTo(-w * 0.08, -w * 0.36)
      ..lineTo(-w * 0.02, -w * 0.24)
      ..moveTo(w * 0.11, -w * 0.2)
      ..lineTo(w * 0.08, -w * 0.36)
      ..lineTo(w * 0.02, -w * 0.24);
    canvas.drawPath(head, paint);
    if (!onLight) {
      final eye = Paint()..color = const Color(0xFFFFB13B);
      canvas.drawCircle(Offset(-w * 0.045, -w * 0.17), w * 0.025, eye);
      canvas.drawCircle(Offset(w * 0.045, -w * 0.17), w * 0.025, eye);
    }
    canvas.restore();
  }

  // ---- hearts -------------------------------------------------------------

  void _hearts(Canvas canvas, Size size, double t) {
    final colors = onLight
        ? const [Color(0x40E0194A), Color(0x33F7476F), Color(0x2EFF8FAB)]
        : const [
            Color(0xFFFFFFFF),
            Color(0xFFFFC6D5),
            Color(0xFFFF8FAB),
            Color(0xFFFFE3EA),
          ];
    for (final s in _take(onLight ? 18 : 30)) {
      final rise = (s.phase + t * s.speed * 0.05) % 1.0;
      final y = size.height + 40 - rise * (size.height + 80);
      final x = s.x * size.width + sin(t * (0.8 + s.sway) + s.phase * 7) * 30;
      final r = 10 + s.size * 22;
      final fade = rise > 0.8 ? (1 - rise) / 0.2 : 1.0;
      final color = s.of(colors);
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(sin(t * 1.4 + s.phase * 5) * 0.25);
      canvas.drawPath(
        heartPath(r),
        Paint()
          ..color = color.withValues(
            alpha: color.a * fade * (onLight ? 1 : 0.55 + s.size * 0.4),
          ),
      );
      canvas.restore();
    }
  }

  // ---- confetti and streamers --------------------------------------------

  void _confetti(
    Canvas canvas,
    Size size,
    double t,
    List<Color> colors, {
    int count = 80,
  }) {
    for (final s in _take(onLight ? count ~/ 2 : count)) {
      final fall = (s.phase + t * s.speed * 0.07) % 1.0;
      final y = -20 + fall * (size.height + 40);
      final x = s.x * size.width + sin(t * (1 + s.sway) + s.phase * 8) * 22;
      final color = s.of(colors).withValues(alpha: onLight ? 0.45 : 0.95);
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(t * s.spin * 3);
      final flip = cos(t * (3 + s.sway * 4) + s.phase * 6);
      canvas.scale(flip, 1);
      final paint = Paint()..color = color;
      final w = 8 + s.size * 10;
      if (s.sway > 0.7) {
        canvas.drawCircle(Offset.zero, w * 0.45, paint);
      } else {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset.zero, width: w, height: w * 0.55),
            const Radius.circular(2),
          ),
          paint,
        );
      }
      canvas.restore();
    }
  }

  void _streamers(Canvas canvas, Size size, double t) {
    const colors = [
      Color(0xFFFFD23F),
      Color(0xFF2EC4B6),
      Color(0xFFF03F8C),
      Color(0xFFFFFFFF),
    ];
    for (final s in _seeds.skip(60).take((10 * density).round())) {
      final fall = (s.phase + t * s.speed * 0.045) % 1.0;
      final y0 = -160 + fall * (size.height + 320);
      final x0 = s.x * size.width;
      final paint = Paint()
        ..color = s.of(colors).withValues(alpha: onLight ? 0.4 : 0.9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round;
      final path = Path()..moveTo(x0, y0);
      for (var i = 1; i <= 24; i++) {
        final k = i / 24;
        path.lineTo(
          x0 + sin(k * pi * 4 + t * 3 + s.phase * 6) * 14 + k * s.spin * 30,
          y0 + k * 130,
        );
      }
      canvas.drawPath(path, paint);
    }
  }

  // ---- petals -------------------------------------------------------------

  void _petals(Canvas canvas, Size size, double t) {
    final colors = onLight
        ? const [Color(0x40B9A2F0), Color(0x40FF9EC0), Color(0x4D8FD9B6)]
        : const [
            Color(0xFFFFFFFF),
            Color(0xFFFFC1D8),
            Color(0xFFE2D6FA),
            Color(0xFFFFE9A3),
          ];
    for (final s in _take(onLight ? 26 : 46)) {
      final fall = (s.phase + t * s.speed * 0.04) % 1.0;
      final y = -20 + fall * (size.height + 40);
      final x = s.x * size.width + sin(t * (0.7 + s.sway) + s.phase * 8) * 40;
      final w = 10 + s.size * 12;
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(t * s.spin * 1.5 + s.phase * 6);
      canvas.scale(1, 0.55 + 0.45 * cos(t * (1.2 + s.sway) + s.phase * 4));
      final petal = Path()
        ..moveTo(0, -w)
        ..quadraticBezierTo(w * 0.8, -w * 0.2, 0, w)
        ..quadraticBezierTo(-w * 0.8, -w * 0.2, 0, -w);
      canvas.drawPath(
        petal,
        Paint()
          ..color = s
              .of(colors)
              .withValues(alpha: onLight ? s.of(colors).a : 0.9),
      );
      canvas.restore();
    }
  }

  // ---- fireworks ----------------------------------------------------------

  void _fireworks(Canvas canvas, Size size, double t) {
    const colors = [
      Color(0xFFFFD86B),
      Color(0xFFFF6F93),
      Color(0xFF6FE3FF),
      Color(0xFFFFFFFF),
      Color(0xFFB98BFF),
      Color(0xFF8CFF9E),
    ];
    final slots = (6 * density).round().clamp(1, 7);
    for (var slot = 0; slot < slots; slot++) {
      final period = 2.4 + slot * 0.31;
      final local = t + slot * 1.13;
      final cycle = (local / period).floor();
      final lt = local - cycle * period;
      final r = Random(slot * 977 + cycle);
      final target = Offset(
        (0.12 + r.nextDouble() * 0.76) * size.width,
        (0.2 + r.nextDouble() * 0.3) * size.height,
      );
      final color = colors[r.nextInt(colors.length)];
      final second = colors[r.nextInt(colors.length)];
      const climb = 0.7;
      if (lt < climb) {
        // The rocket climbs with a fading trail.
        final k = Curves.easeOutCubic.transform(lt / climb);
        final start = Offset(target.dx + 40, size.height + 20);
        final p = Offset.lerp(start, target, k)!;
        final tail = Offset.lerp(start, target, max(0, k - 0.08))!;
        canvas.drawLine(
          tail,
          p,
          Paint()
            ..shader = LinearGradient(
              colors: [color.withValues(alpha: 0), color],
            ).createShader(Rect.fromPoints(tail, p))
            ..strokeWidth = 4
            ..strokeCap = StrokeCap.round,
        );
        canvas.drawCircle(p, 4, Paint()..color = Colors.white);
        continue;
      }
      final k = ((lt - climb) / 1.6).clamp(0.0, 1.0);
      if (k >= 1) continue;
      final radius = 90 + r.nextDouble() * 100;
      final spread = Curves.easeOutCubic.transform(k) * radius;
      final drop = k * k * 60;
      final alpha = 1 - k * k;
      if (k < 0.15) {
        canvas.drawCircle(
          target,
          radius * 0.6 * (1 - k / 0.15),
          Paint()
            ..color = color.withValues(alpha: 0.35)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 30),
        );
      }
      const sparks = 30;
      for (var i = 0; i < sparks; i++) {
        final a = i * 2 * pi / sparks + slot;
        final ring = i.isEven ? 1.0 : 0.72;
        final p =
            target + Offset(cos(a), sin(a)) * spread * ring + Offset(0, drop);
        final trail =
            target +
            Offset(cos(a), sin(a)) * max(0, spread * ring - 22) +
            Offset(0, drop * 0.8);
        final c = i.isEven ? color : second;
        canvas.drawLine(
          trail,
          p,
          Paint()
            ..color = c.withValues(alpha: alpha * 0.7)
            ..strokeWidth = 3.5
            ..strokeCap = StrokeCap.round,
        );
        canvas.drawCircle(
          p,
          4.2 * (1 - k * 0.5),
          Paint()..color = c.withValues(alpha: alpha),
        );
      }
    }
  }

  // ---- bubbles ------------------------------------------------------------

  void _bubbles(Canvas canvas, Size size, double t) {
    final color = onLight ? const Color(0xFF0A8DB8) : Colors.white;
    for (final s in _take(onLight ? 18 : 34)) {
      final rise = (s.phase + t * s.speed * 0.035) % 1.0;
      final y = size.height + 30 - rise * (size.height + 60);
      final x = s.x * size.width + sin(t * (0.9 + s.sway) + s.phase * 7) * 18;
      final r = 6 + s.size * 20;
      final alpha =
          (onLight ? 0.18 : 0.4) * (rise > 0.85 ? (1 - rise) / 0.15 : 1);
      canvas.drawCircle(
        Offset(x, y),
        r,
        Paint()
          ..color = color.withValues(alpha: alpha * 0.35)
          ..style = PaintingStyle.fill,
      );
      canvas.drawCircle(
        Offset(x, y),
        r,
        Paint()
          ..color = color.withValues(alpha: alpha)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
      canvas.drawCircle(
        Offset(x - r * 0.35, y - r * 0.35),
        r * 0.18,
        Paint()..color = color.withValues(alpha: alpha * 1.6),
      );
    }
  }

  @override
  bool shouldRepaint(_ParticlePainter old) =>
      old.kind != kind || old.onLight != onLight || old.density != density;
}

/// A heart of half-width [r] centred on the origin.
Path heartPath(double r) => Path()
  ..moveTo(0, r * 0.9)
  ..cubicTo(-r * 1.2, r * 0.1, -r * 1.05, -r * 0.95, 0, -r * 0.45)
  ..cubicTo(r * 1.05, -r * 0.95, r * 1.2, r * 0.1, 0, r * 0.9)
  ..close();
