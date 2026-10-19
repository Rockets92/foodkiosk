import 'package:flutter/material.dart';
import 'package:kiosk_core/kiosk_core.dart';

import '../scope.dart';
import '../widgets/common.dart';

/// Language and "eat in / take away" on a single screen, to save a tap.
class StartScreen extends StatelessWidget {
  const StartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final k = context.kiosk;
    final t = context.t;
    final modes = [
      for (final m in ServiceMode.values)
        if (k.settings.serviceModes.contains(m)) m,
    ];
    return Scaffold(
      key: const ValueKey('start'),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: k.reset,
                  icon: const Icon(Icons.arrow_back),
                  label: Text(t('back'), style: const TextStyle(fontSize: 20)),
                ),
              ),
              const Spacer(),
              const VenueLogo(size: 140),
              const SizedBox(height: 24),
              Text(
                t('welcome'),
                style: Theme.of(
                  context,
                ).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 40),
              if (k.settings.languages.length > 1) ...[
                Text(
                  t('chooseLanguage'),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  alignment: WrapAlignment.center,
                  children: [
                    for (final code in k.settings.languages)
                      _LanguageButton(code: code),
                  ],
                ),
                const SizedBox(height: 56),
              ],
              Text(
                t('whereEat'),
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  for (final m in modes)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: _ModeCard(mode: m),
                      ),
                    ),
                ],
              ),
              const Spacer(flex: 2),
            ],
          ),
        ),
      ),
    );
  }
}

class _LanguageButton extends StatelessWidget {
  final String code;
  const _LanguageButton({required this.code});

  @override
  Widget build(BuildContext context) {
    final k = context.kiosk;
    final selected = k.language == code;
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      key: ValueKey('start-lang-$code'),
      borderRadius: BorderRadius.circular(16),
      onTap: () => k.setLanguage(code),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
        decoration: BoxDecoration(
          color: selected ? scheme.primary : scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          context.t.languageName(code),
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: selected ? scheme.onPrimary : scheme.onSurface,
          ),
        ),
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  final ServiceMode mode;
  const _ModeCard({required this.mode});

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return Card(
      key: ValueKey('mode-${mode.name}'),
      child: InkWell(
        onTap: () => context.kiosk.chooseServiceMode(mode),
        child: AspectRatio(
          aspectRatio: 0.9,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                mode == ServiceMode.eatIn
                    ? Icons.restaurant
                    : Icons.shopping_bag_outlined,
                size: 120,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 24),
              Text(
                t(mode.name),
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
