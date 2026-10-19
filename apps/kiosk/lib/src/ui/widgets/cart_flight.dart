import 'package:flutter/material.dart';

import '../theme.dart';
import 'net_image.dart';

/// "Fly to cart" animation: the product picture jumps from where it was
/// added into the order button, which then bounces.
abstract final class CartFlight {
  /// Attached to the order button in the menu.
  static final targetKey = GlobalKey(debugLabel: 'cart-target');

  /// Incremented when a flight lands; the order button listens to bounce.
  static final landed = ValueNotifier<int>(0);

  static Rect? _rectOf(GlobalKey key) {
    final box = key.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.attached) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  static void launch(
    BuildContext context, {
    required Rect from,
    String? image,
  }) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    final to = _rectOf(targetKey);
    if (overlay == null || to == null) {
      landed.value++;
      return;
    }
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _Flight(
        from: from,
        to: to,
        image: image,
        onDone: () {
          entry.remove();
          landed.value++;
        },
      ),
    );
    overlay.insert(entry);
  }
}

class _Flight extends StatefulWidget {
  final Rect from;
  final Rect to;
  final String? image;
  final VoidCallback onDone;

  const _Flight({
    required this.from,
    required this.to,
    this.image,
    required this.onDone,
  });

  @override
  State<_Flight> createState() => _FlightState();
}

class _FlightState extends State<_Flight> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 750),
  )..forward().whenComplete(widget.onDone);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final start = widget.from.center;
    final end = widget.to.center;
    final control = Offset((start.dx + end.dx) / 2, start.dy - 260);
    final size = widget.from.shortestSide.clamp(120.0, 320.0);
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, _) {
          final t = Curves.easeInOutCubic.transform(_c.value);
          // Quadratic Bézier from start to end through an arc above.
          final p = Offset(
            (1 - t) * (1 - t) * start.dx +
                2 * (1 - t) * t * control.dx +
                t * t * end.dx,
            (1 - t) * (1 - t) * start.dy +
                2 * (1 - t) * t * control.dy +
                t * t * end.dy,
          );
          final s = size * (1 - 0.8 * t);
          return Stack(
            children: [
              Positioned(
                left: p.dx - s / 2,
                top: p.dy - s / 2,
                width: s,
                height: s,
                child: Opacity(
                  opacity: t > 0.9 ? (1 - t) * 10 : 1,
                  child: Transform.rotate(
                    angle: t * 0.6,
                    child: DecoratedBox(
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: K.shadowStrong,
                      ),
                      child: NetImage(widget.image),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
