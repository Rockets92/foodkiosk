import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:kiosk_core/kiosk_core.dart';

import '../../i18n.dart';
import '../../state/kiosk_controller.dart';
import '../holiday/decor.dart';
import '../scope.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/net_image.dart';
import '../widgets/pressable.dart';

/// "Eat in or take away?" with the language switcher, on one screen.
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
    final landscape = MediaQuery.sizeOf(context).aspectRatio > 1;
    final holiday = K.holiday;
    return Scaffold(
      key: const ValueKey('start'),
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (holiday != null && !landscape)
            HolidayScene(
              key: ValueKey('holiday-${holiday.id}'),
              theme: holiday,
              onLight: true,
            ),
          _content(context, k, t, modes, landscape, holiday),
        ],
      ),
    );
  }

  Widget _content(
    BuildContext context,
    KioskController k,
    Strings t,
    List<ServiceMode> modes,
    bool landscape,
    HolidayTheme? holiday,
  ) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(40, 24, 40, 40),
        child: Column(
          children: [
            Row(
              children: [
                RoundButton(
                  key: const ValueKey('start-back'),
                  icon: Icons.close_rounded,
                  onTap: k.reset,
                ),
                const Spacer(),
                const LanguageSwitcher(),
              ],
            ),
            const Spacer(),
            const VenueLogo(
              size: 120,
            ).animate().scale(duration: 600.ms, curve: Curves.elasticOut),
            if (holiday != null) ...[
              const SizedBox(height: 24),
              HolidayGreeting(
                theme: holiday,
                text: holidayGreeting(t, holiday),
              ),
            ],
            const SizedBox(height: 28),
            Text(
              t('welcome'),
              style: KText.display,
              textAlign: TextAlign.center,
            ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.3),
            const SizedBox(height: 8),
            Text(
                  t('whereEat'),
                  style: KText.h2.copyWith(
                    color: K.inkSoft,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                )
                .animate()
                .fadeIn(delay: 120.ms, duration: 400.ms)
                .slideY(begin: 0.3),
            const SizedBox(height: 56),
            SizedBox(
              height: landscape ? 420 : 620,
              child: Row(
                children: [
                  for (final (i, m) in modes.indexed)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: _ModeCard(mode: m)
                            .animate()
                            .fadeIn(delay: (220 + i * 120).ms, duration: 500.ms)
                            .slideY(
                              begin: 0.25,
                              curve: Curves.easeOutCubic,
                              duration: 500.ms,
                            ),
                      ),
                    ),
                ],
              ),
            ),
            const Spacer(flex: 2),
          ],
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
    final eatIn = mode == ServiceMode.eatIn;
    return Pressable(
      key: ValueKey('mode-${mode.name}'),
      onTap: () => context.kiosk.chooseServiceMode(mode),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(40),
          boxShadow: K.shadow,
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            Expanded(
              child: Container(
                width: double.infinity,
                color: eatIn ? K.primarySoft : K.accentSoft,
                padding: const EdgeInsets.all(28),
                child: Illustration(eatIn ? 'eat_in' : 'take_away'),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    eatIn
                        ? Icons.restaurant_rounded
                        : Icons.shopping_bag_rounded,
                    color: K.primary,
                    size: 36,
                  ),
                  const SizedBox(width: 12),
                  Text(t(mode.name), style: KText.h2),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
