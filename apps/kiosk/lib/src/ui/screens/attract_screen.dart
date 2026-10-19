import 'package:flutter/material.dart';

import '../../i18n.dart';
import '../scope.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Idle screen: invites passers-by to touch, cycling through languages.
class AttractScreen extends StatefulWidget {
  const AttractScreen({super.key});

  @override
  State<AttractScreen> createState() => _AttractScreenState();
}

class _AttractScreenState extends State<AttractScreen>
    with SingleTickerProviderStateMixin {
  late final _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat(reverse: true);
  int _langIndex = 0;

  @override
  void initState() {
    super.initState();
    _pulse.addStatusListener((s) {
      if (s == AnimationStatus.dismissed && mounted) {
        setState(() => _langIndex++);
      }
    });
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final k = context.kiosk;
    final langs = k.settings.languages;
    final t = Strings(langs[_langIndex % langs.length]);
    return Material(
      key: const ValueKey('attract'),
      color: brandPrimary,
      child: InkWell(
        onTap: k.start,
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const VenueLogo(size: 220),
                const SizedBox(height: 32),
                Text(
                  k.settings.venueName,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 56,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 80),
                ScaleTransition(
                  scale: Tween(begin: 0.94, end: 1.06).animate(
                    CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 48,
                      vertical: 28,
                    ),
                    decoration: BoxDecoration(
                      color: brandAccent,
                      borderRadius: BorderRadius.circular(48),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.touch_app, size: 48),
                        const SizedBox(width: 16),
                        Text(
                          t('touchToOrder'),
                          style: const TextStyle(
                            fontSize: 40,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
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
