import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../scope.dart';
import '../theme.dart';
import 'net_image.dart';
import 'pressable.dart';

/// Venue logo; a generated placeholder until a real one is uploaded.
class VenueLogo extends StatelessWidget {
  final double size;
  const VenueLogo({super.key, this.size = 160});

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: const NetImage('/media/placeholder/logo.svg'),
  );
}

/// Pill-shaped language switcher.
class LanguageSwitcher extends StatelessWidget {
  final bool dark;
  const LanguageSwitcher({super.key, this.dark = false});

  @override
  Widget build(BuildContext context) {
    final k = context.kiosk;
    final langs = k.settings.languages;
    if (langs.length < 2) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: dark ? Colors.white.withValues(alpha: 0.15) : Colors.white,
        borderRadius: BorderRadius.circular(40),
        boxShadow: dark ? null : K.shadow,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final code in langs)
            Pressable(
              key: ValueKey('lang-$code'),
              onTap: () => k.setLanguage(code),
              child: AnimatedContainer(
                duration: K.medium,
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: k.language == code
                      ? (dark ? Colors.white : K.ink)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(34),
                ),
                child: Text(
                  code.toUpperCase(),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: k.language == code
                        ? (dark ? K.red : Colors.white)
                        : (dark ? Colors.white : K.inkSoft),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Small badge reminding staff that the kiosk runs in demo mode.
class DemoBadge extends StatelessWidget {
  const DemoBadge({super.key});

  @override
  Widget build(BuildContext context) {
    if (!context.kiosk.settings.demoMode) return const SizedBox.shrink();
    return Positioned(
      top: 4,
      left: 0,
      right: 0,
      child: IgnorePointer(
        child: Center(
          child: Container(
            key: const ValueKey('demo-badge'),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: K.ink.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: K.yellow,
                        shape: BoxShape.circle,
                      ),
                    )
                    .animate(onPlay: (c) => c.repeat(reverse: true))
                    .fade(begin: 1, end: 0.2, duration: 900.ms),
                const SizedBox(width: 8),
                const Text(
                  'DEMO',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    letterSpacing: 1.5,
                    fontFamily: 'Poppins',
                    decoration: TextDecoration.none,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Amount that slides when it changes.
class AnimatedAmount extends StatelessWidget {
  final String text;
  final TextStyle style;
  const AnimatedAmount(this.text, {super.key, required this.style});

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration: K.medium,
    transitionBuilder: (child, anim) => FadeTransition(
      opacity: anim,
      child: SlideTransition(
        position: Tween(
          begin: const Offset(0, 0.4),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
        child: child,
      ),
    ),
    child: Text(text, key: ValueKey(text), style: style),
  );
}

/// Soft coloured disc behind product pictures.
class ImageDisc extends StatelessWidget {
  final String? image;
  final Color color;
  final double padding;
  const ImageDisc({
    super.key,
    required this.image,
    required this.color,
    this.padding = 18,
  });

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      FractionallySizedBox(
        widthFactor: 0.86,
        heightFactor: 0.86,
        child: DecoratedBox(
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
      ),
      Padding(padding: EdgeInsets.all(padding), child: NetImage(image)),
    ],
  );
}

Future<bool> confirmDialog(BuildContext context, String question) async {
  final t = context.t;
  final result = await showGeneralDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'confirm',
    barrierColor: Colors.black54,
    transitionDuration: K.medium,
    pageBuilder: (ctx, _, _) => Center(
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(K.radius),
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.help_outline_rounded, size: 72, color: K.red),
                const SizedBox(height: 16),
                Text(question, textAlign: TextAlign.center, style: KText.h2),
                const SizedBox(height: 32),
                Row(
                  children: [
                    Expanded(
                      child: KButton.secondary(
                        key: const ValueKey('confirm-no'),
                        label: t('no'),
                        onTap: () => Navigator.pop(ctx, false),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: KButton(
                        key: const ValueKey('confirm-yes'),
                        label: t('yes'),
                        onTap: () => Navigator.pop(ctx, true),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ),
    transitionBuilder: (_, anim, _, child) => ScaleTransition(
      scale: Tween(
        begin: 0.9,
        end: 1.0,
      ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutBack)),
      child: FadeTransition(opacity: anim, child: child),
    ),
  );
  return result ?? false;
}
