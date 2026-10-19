import 'package:flutter/material.dart';

import '../scope.dart';
import '../theme.dart';
import 'net_image.dart';

/// Venue logo; a generated placeholder until a real one is uploaded.
class VenueLogo extends StatelessWidget {
  final double size;
  const VenueLogo({super.key, this.size = 160});

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: const ClipOval(child: NetImage('/media/placeholder/Logo.svg')),
  );
}

/// Language switcher shown in headers.
class LanguageBar extends StatelessWidget {
  const LanguageBar({super.key});

  @override
  Widget build(BuildContext context) {
    final k = context.kiosk;
    if (k.settings.languages.length < 2) return const SizedBox.shrink();
    return Wrap(
      spacing: 8,
      children: [
        for (final code in k.settings.languages)
          ChoiceChip(
            key: ValueKey('lang-$code'),
            label: Text(
              code.toUpperCase(),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            selected: k.language == code,
            onSelected: (_) => k.setLanguage(code),
          ),
      ],
    );
  }
}

/// Corner ribbon reminding that the kiosk runs in demo mode.
class DemoRibbon extends StatelessWidget {
  const DemoRibbon({super.key});

  @override
  Widget build(BuildContext context) {
    if (!context.kiosk.settings.demoMode) return const SizedBox.shrink();
    return const Positioned(
      top: 0,
      right: 0,
      child: IgnorePointer(
        child: SizedBox.square(
          dimension: 160,
          child: Banner(
            message: 'DEMO',
            location: BannerLocation.topEnd,
            color: brandAccent,
            textStyle: TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.w900,
              fontSize: 13,
              height: 1,
            ),
            child: SizedBox.expand(),
          ),
        ),
      ),
    );
  }
}

Future<bool> confirmDialog(BuildContext context, String question) async {
  final t = context.t;
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      content: Text(question, style: const TextStyle(fontSize: 26)),
      actionsAlignment: MainAxisAlignment.spaceEvenly,
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(t('no')),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(t('yes')),
        ),
      ],
    ),
  );
  return result ?? false;
}
