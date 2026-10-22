import 'package:flutter/material.dart';

import '../theme.dart';

/// Shrinks slightly while pressed, like the physical feel of the big
/// fast-food kiosks. Wraps any card or button.
class Pressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double pressedScale;

  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.pressedScale = 0.96,
  });

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  void _set(bool v) {
    if (widget.onTap == null) return;
    setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _set(true),
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? widget.pressedScale : 1,
        duration: K.fast,
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// Large rounded call-to-action button.
class KButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final Widget? trailing;

  /// Defaults to the palette's primary colour.
  final Color? color;
  final Color foreground;
  final double height;
  final bool expand;

  const KButton({
    super.key,
    required this.label,
    this.onTap,
    this.icon,
    this.trailing,
    this.color,
    this.foreground = Colors.white,
    this.height = 84,
    this.expand = false,
  });

  const KButton.secondary({
    super.key,
    required this.label,
    this.onTap,
    this.icon,
    this.trailing,
    this.height = 84,
    this.expand = false,
  }) : color = Colors.white,
       foreground = K.ink;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final color = this.color ?? K.primary;
    final content = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: trailing == null
          ? MainAxisAlignment.center
          : MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, color: foreground, size: 30),
                const SizedBox(width: 12),
              ],
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: KText.button.copyWith(color: foreground),
                ),
              ),
            ],
          ),
        ),
        ?trailing,
      ],
    );
    return Pressable(
      onTap: onTap,
      child: AnimatedOpacity(
        opacity: enabled ? 1 : 0.4,
        duration: K.fast,
        child: Container(
          height: height,
          padding: const EdgeInsets.symmetric(horizontal: 32),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(height / 2),
            border: color == Colors.white
                ? Border.all(color: K.line, width: 2)
                : null,
            boxShadow: enabled && color != Colors.white
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.35),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                  ]
                : null,
          ),
          child: content,
        ),
      ),
    );
  }
}

/// Round icon button (close, back, quantity).
class RoundButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final double size;
  final Color color;
  final Color foreground;

  const RoundButton({
    super.key,
    required this.icon,
    this.onTap,
    this.size = 64,
    this.color = Colors.white,
    this.foreground = K.ink,
  });

  @override
  Widget build(BuildContext context) => Pressable(
    onTap: onTap,
    pressedScale: 0.88,
    child: AnimatedOpacity(
      opacity: onTap == null ? 0.35 : 1,
      duration: K.fast,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: K.shadow,
        ),
        child: Icon(icon, color: foreground, size: size * 0.5),
      ),
    ),
  );
}
