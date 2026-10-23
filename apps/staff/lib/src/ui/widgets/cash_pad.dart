import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:kiosk_core/kiosk_core.dart';

import '../theme.dart';

/// Euro banknotes and coins the cashier can tap, largest first.
const euroNotes = <Cents>[500, 1000, 2000, 5000, 10000, 20000];
const euroCoins = <Cents>[200, 100, 50, 20, 10, 5, 2, 1];

/// The notes and coins that make up [cents], largest first: what to hand
/// back as change.
List<Cents> changeBreakdown(Cents cents) {
  final out = <Cents>[];
  var left = cents;
  for (final d in [...euroNotes.reversed, ...euroCoins]) {
    while (left >= d) {
      out.add(d);
      left -= d;
    }
  }
  return out;
}

/// Tappable euro notes and coins. A tap adds one piece to what the
/// customer handed over, a long press takes one back; the badge on each
/// piece counts how many were taken.
class CashPad extends StatelessWidget {
  final Map<Cents, int> counts;
  final ValueChanged<Cents> onAdd;
  final ValueChanged<Cents> onRemove;

  const CashPad({
    super.key,
    required this.counts,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      const gap = 12.0;
      final noteW = (box.maxWidth - gap * 2) / 3;
      final coinSlot = (box.maxWidth - gap * 3) / 4;
      Widget piece(Cents c, Widget face) => _Piece(
        key: ValueKey('pay-cash-$c'),
        count: counts[c] ?? 0,
        onTap: () => onAdd(c),
        onLongPress: () => onRemove(c),
        child: face,
      );
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _Caption(icon: Icons.payments_outlined, text: 'Banconote'),
          for (final row in [euroNotes.sublist(0, 3), euroNotes.sublist(3)])
            Padding(
              padding: const EdgeInsets.only(bottom: gap),
              child: Row(
                children: [
                  for (final (i, c) in row.indexed) ...[
                    if (i > 0) const SizedBox(width: gap),
                    SizedBox(
                      width: noteW,
                      height: noteW * 0.52,
                      child: piece(c, Banknote(c)),
                    ),
                  ],
                ],
              ),
            ),
          const SizedBox(height: 4),
          const _Caption(icon: Icons.toll_outlined, text: 'Monete'),
          for (final row in [euroCoins.sublist(0, 4), euroCoins.sublist(4)])
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  for (final (i, c) in row.indexed) ...[
                    if (i > 0) const SizedBox(width: gap),
                    SizedBox(
                      width: coinSlot,
                      height: math.min(coinSlot, 76),
                      child: Center(
                        child: SizedBox.square(
                          dimension: math.min(coinSlot, 76) * _coinScale(c),
                          child: piece(c, Coin(c)),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      );
    },
  );
}

/// Coin diameter relative to the 2 € coin, as in real life but squeezed
/// so the 1 cent stays easy to tap.
double _coinScale(Cents c) =>
    0.72 +
    0.28 *
        switch (c) {
          200 => 1.0,
          100 => 0.8,
          50 => 0.85,
          20 => 0.65,
          10 => 0.45,
          5 => 0.55,
          2 => 0.3,
          _ => 0.1,
        };

class _Caption extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Caption({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      children: [
        Icon(icon, size: 16, color: S.muted),
        const SizedBox(width: 6),
        Text(
          text.toUpperCase(),
          style: const TextStyle(
            fontSize: 12,
            letterSpacing: 1.2,
            fontWeight: FontWeight.w700,
            color: S.muted,
          ),
        ),
      ],
    ),
  );
}

/// One tappable note or coin: sinks under the finger and shows a count
/// badge once taken.
class _Piece extends StatefulWidget {
  final int count;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final Widget child;
  const _Piece({
    super.key,
    required this.count,
    required this.onTap,
    required this.onLongPress,
    required this.child,
  });

  @override
  State<_Piece> createState() => _PieceState();
}

class _PieceState extends State<_Piece> {
  bool _down = false;

  @override
  Widget build(BuildContext context) => MouseRegion(
    cursor: SystemMouseCursors.click,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) => setState(() => _down = false),
      onTapCancel: () => setState(() => _down = false),
      onTap: widget.onTap,
      onLongPress: widget.count > 0 ? widget.onLongPress : null,
      child: AnimatedScale(
        scale: _down ? 0.92 : 1,
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOut,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(child: widget.child),
            Positioned(
              top: -8,
              right: -8,
              child: AnimatedSwitcher(
                duration: S.fast,
                transitionBuilder: (child, a) => ScaleTransition(
                  scale: CurvedAnimation(parent: a, curve: Curves.easeOutBack),
                  child: child,
                ),
                child: widget.count == 0
                    ? const SizedBox.shrink()
                    : Container(
                        key: ValueKey(widget.count),
                        constraints: const BoxConstraints(minWidth: 28),
                        height: 28,
                        padding: const EdgeInsets.symmetric(horizontal: 7),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: S.ink,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: S.shadow,
                        ),
                        child: Text(
                          '${widget.count}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// A Europa-series euro banknote, drawn to scale of its box.
class Banknote extends StatelessWidget {
  final Cents cents;
  const Banknote(this.cents, {super.key});

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(6),
      boxShadow: const [
        BoxShadow(
          color: Color(0x26000000),
          blurRadius: 10,
          offset: Offset(0, 4),
        ),
      ],
    ),
    child: CustomPaint(painter: _BanknotePainter(cents)),
  );
}

class _NoteColors {
  final Color light;
  final Color base;
  final Color dark;
  const _NoteColors(this.light, this.base, this.dark);
}

const _noteColors = <Cents, _NoteColors>{
  500: _NoteColors(Color(0xFFD5DCD6), Color(0xFF97A49C), Color(0xFF55625A)),
  1000: _NoteColors(Color(0xFFF6D3CB), Color(0xFFE0645A), Color(0xFF9E2B25)),
  2000: _NoteColors(Color(0xFFD3E2F5), Color(0xFF5A8DD0), Color(0xFF244E8C)),
  5000: _NoteColors(Color(0xFFFBE2C4), Color(0xFFEE9A45), Color(0xFFA85C14)),
  10000: _NoteColors(Color(0xFFD5EBD9), Color(0xFF58AA74), Color(0xFF256B3F)),
  20000: _NoteColors(Color(0xFFF6EBC6), Color(0xFFDDB64C), Color(0xFF8E6C12)),
};

class _BanknotePainter extends CustomPainter {
  final Cents cents;
  _BanknotePainter(this.cents);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final c = _noteColors[cents]!;
    final shape = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(h * 0.07),
    );
    canvas.save();
    canvas.clipRRect(shape);

    // Paper: light on the left, the denomination colour to the right.
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = LinearGradient(
          colors: [c.light, c.base, c.base, c.dark],
          stops: const [0, 0.45, 0.75, 1],
        ).createShader(Offset.zero & size),
    );

    // Guilloche lines across the paper.
    final wave = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.6, h * 0.008)
      ..color = Colors.white.withValues(alpha: 0.22);
    for (var k = 0; k < 7; k++) {
      final path = Path();
      for (var x = 0.0; x <= w; x += w / 60) {
        final y =
            h * (0.18 + k * 0.11) +
            math.sin(x / w * math.pi * 4 + k) * h * 0.035;
        x == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
      }
      canvas.drawPath(path, wave);
    }

    // The arches and windows of the architecture on every note.
    final arch = Paint()..color = c.dark.withValues(alpha: 0.22);
    final archLine = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1, h * 0.012)
      ..color = c.dark.withValues(alpha: 0.35);
    for (var i = 0; i < 3; i++) {
      final left = w * (0.30 + i * 0.105);
      final aw = w * 0.085;
      final top = h * (0.30 + (i == 1 ? -0.06 : 0));
      final r = Rect.fromLTWH(left, top, aw, h * 0.62);
      final p = Path()
        ..moveTo(r.left, r.bottom)
        ..lineTo(r.left, r.top + aw / 2)
        ..arcToPoint(
          Offset(r.right, r.top + aw / 2),
          radius: Radius.circular(aw / 2),
        )
        ..lineTo(r.right, r.bottom)
        ..close();
      canvas.drawPath(p, arch);
      canvas.drawPath(p, archLine);
    }

    // Hologram strip with its rainbow sheen.
    final strip = Rect.fromLTWH(w * 0.77, 0, w * 0.075, h);
    canvas.drawRect(
      strip,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFE8ECEF),
            Color(0xFFB9C7F2),
            Color(0xFFF2E6B5),
            Color(0xFFBDE8D5),
            Color(0xFFE8ECEF),
          ],
        ).createShader(strip),
    );
    canvas.drawRect(
      strip,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Colors.white.withValues(alpha: 0.7),
    );

    // Watermark window.
    canvas.drawOval(
      Rect.fromLTWH(w * 0.865, h * 0.22, w * 0.11, h * 0.48),
      Paint()..color = Colors.white.withValues(alpha: 0.28),
    );

    // EU flag, top left.
    final flag = Rect.fromLTWH(w * 0.04, h * 0.09, w * 0.13, h * 0.2);
    canvas.drawRect(flag, Paint()..color = const Color(0xFF1F3F9A));
    final star = Paint()..color = const Color(0xFFFFD43B);
    for (var s = 0; s < 12; s++) {
      final a = s / 12 * math.pi * 2;
      canvas.drawCircle(
        flag.center + Offset(math.cos(a), math.sin(a)) * flag.height * 0.32,
        math.max(0.7, flag.height * 0.055),
        star,
      );
    }

    final value = '${cents ~/ 100}';
    // Big value, bottom left, white with a soft shadow.
    _text(
      canvas,
      value,
      Offset(w * 0.04, h * 0.40),
      TextStyle(
        fontSize: h * 0.5,
        height: 1,
        fontWeight: FontWeight.w900,
        letterSpacing: -h * 0.02,
        color: Colors.white,
        shadows: [
          Shadow(
            color: c.dark.withValues(alpha: 0.6),
            blurRadius: h * 0.04,
            offset: Offset(0, h * 0.015),
          ),
        ],
      ),
    );
    // Small value, top right of the strip area.
    _text(
      canvas,
      value,
      Offset(w * 0.56, h * 0.06),
      TextStyle(
        fontSize: h * 0.2,
        height: 1,
        fontWeight: FontWeight.w800,
        color: c.dark,
      ),
    );
    _text(
      canvas,
      'EURO  ΕΥΡΩ',
      Offset(w * 0.33, h * 0.88),
      TextStyle(
        fontSize: h * 0.075,
        height: 1,
        fontWeight: FontWeight.w700,
        letterSpacing: h * 0.01,
        color: c.dark.withValues(alpha: 0.75),
      ),
    );
    canvas.restore();

    canvas.drawRRect(
      shape,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = c.dark.withValues(alpha: 0.35),
    );
  }

  @override
  bool shouldRepaint(_BanknotePainter old) => old.cents != cents;
}

/// A euro coin seen from its common side.
class Coin extends StatelessWidget {
  final Cents cents;
  const Coin(this.cents, {super.key});

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      shape: BoxShape.circle,
      boxShadow: [
        BoxShadow(
          color: Color(0x33000000),
          blurRadius: 8,
          offset: Offset(0, 3),
        ),
      ],
    ),
    child: CustomPaint(painter: _CoinPainter(cents)),
  );
}

class _Metal {
  final Color light;
  final Color base;
  final Color dark;
  const _Metal(this.light, this.base, this.dark);
}

const _copper = _Metal(Color(0xFFF2B07C), Color(0xFFC87533), Color(0xFF7E3F17));
const _nordicGold = _Metal(
  Color(0xFFFBE7A1),
  Color(0xFFDDB64C),
  Color(0xFF94701A),
);
const _silver = _Metal(Color(0xFFF7F8FA), Color(0xFFC5C9CE), Color(0xFF7D838A));

class _CoinPainter extends CustomPainter {
  final Cents cents;
  _CoinPainter(this.cents);

  void _disc(Canvas canvas, Offset o, double r, _Metal m) {
    final rect = Rect.fromCircle(center: o, radius: r);
    canvas.drawCircle(
      o,
      r,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.4, -0.5),
          radius: 1.1,
          colors: [m.light, m.base, m.dark],
          stops: const [0, 0.55, 1],
        ).createShader(rect),
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.shortestSide / 2;
    final o = size.center(Offset.zero);
    final (outer, inner) = switch (cents) {
      200 => (_silver, _nordicGold),
      100 => (_nordicGold, _silver),
      >= 10 => (_nordicGold, _nordicGold),
      _ => (_copper, _copper),
    };
    _disc(canvas, o, r, outer);
    // Milled rim.
    canvas.drawCircle(
      o,
      r * 0.93,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.05
        ..color = outer.dark.withValues(alpha: 0.35),
    );
    final bimetal = cents >= 100;
    if (bimetal) {
      _disc(canvas, o, r * 0.68, inner);
      canvas.drawCircle(
        o,
        r * 0.68,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.03
          ..color = inner.dark.withValues(alpha: 0.5),
      );
    }

    // Twelve stars around the edge.
    final star = Paint()..color = outer.dark.withValues(alpha: 0.55);
    final starRing = bimetal ? r * 0.82 : r * 0.8;
    for (var s = 0; s < 12; s++) {
      final a = s / 12 * math.pi * 2 - math.pi / 2;
      canvas.drawCircle(
        o + Offset(math.cos(a), math.sin(a)) * starRing,
        r * 0.045,
        star,
      );
    }

    final euro = cents >= 100;
    final value = euro ? '${cents ~/ 100}' : '$cents';
    final ink = inner.dark;
    final big = TextStyle(
      fontSize: r * (euro ? 0.78 : (value.length > 1 ? 0.62 : 0.7)),
      height: 1,
      fontWeight: FontWeight.w900,
      letterSpacing: -r * 0.03,
      color: ink,
      shadows: [
        Shadow(color: inner.light, offset: Offset(-r * 0.02, -r * 0.02)),
      ],
    );
    final small = TextStyle(
      fontSize: r * 0.2,
      height: 1,
      fontWeight: FontWeight.w800,
      letterSpacing: r * 0.03,
      color: ink,
    );
    final vp = _layout(value, big);
    final lp = _layout(euro ? 'EURO' : 'CENT', small);
    final total = vp.height + lp.height * 0.9;
    vp.paint(canvas, o - Offset(vp.width / 2, total / 2 + r * 0.04));
    lp.paint(
      canvas,
      o + Offset(-lp.width / 2, total / 2 - lp.height + r * 0.02),
    );
  }

  @override
  bool shouldRepaint(_CoinPainter old) => old.cents != cents;
}

TextPainter _layout(String text, TextStyle style) => TextPainter(
  text: TextSpan(text: text, style: style),
  textDirection: TextDirection.ltr,
)..layout();

void _text(Canvas canvas, String text, Offset at, TextStyle style) =>
    _layout(text, style).paint(canvas, at);

/// Small picture of [cents] for the change list: a mini note or coin.
class CashChip extends StatelessWidget {
  final Cents cents;
  final int count;
  const CashChip(this.cents, {super.key, this.count = 1});

  @override
  Widget build(BuildContext context) {
    final note = cents >= 500;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (note)
          SizedBox(width: 68, height: 35, child: Banknote(cents))
        else
          SizedBox.square(
            dimension: 30 + 12 * _coinScale(cents),
            child: Coin(cents),
          ),
        if (count > 1) ...[
          const SizedBox(width: 4),
          Text(
            'x$count',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: S.ink,
            ),
          ),
        ],
      ],
    );
  }
}
