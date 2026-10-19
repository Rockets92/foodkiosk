import 'package:flutter/material.dart';

import '../state/kiosk_controller.dart';
import 'scope.dart';
import 'screens/attract_screen.dart';
import 'screens/cart_screen.dart';
import 'screens/done_screen.dart';
import 'screens/menu_screen.dart';
import 'screens/offline_screen.dart';
import 'screens/payment_screen.dart';
import 'screens/start_screen.dart';
import 'theme.dart';
import 'widgets/common.dart';
import 'widgets/idle_watcher.dart';
import 'widgets/staff_corner.dart';

final _theme = kioskTheme();

class KioskApp extends StatelessWidget {
  final KioskController controller;
  final Future<void> Function(Uri) onServerChanged;

  const KioskApp({
    super.key,
    required this.controller,
    required this.onServerChanged,
  });

  @override
  Widget build(BuildContext context) {
    return KioskScope(
      controller: controller,
      child: MaterialApp(
        title: 'Food Kiosk',
        debugShowCheckedModeBanner: false,
        theme: _theme,
        home: _Shell(onServerChanged: onServerChanged),
      ),
    );
  }
}

class _Shell extends StatelessWidget {
  final Future<void> Function(Uri) onServerChanged;
  const _Shell({required this.onServerChanged});

  @override
  Widget build(BuildContext context) {
    final k = context.kiosk;
    final Widget screen = k.loadState != LoadState.ready
        ? const OfflineScreen()
        : switch (k.step) {
            KioskStep.attract => const AttractScreen(),
            KioskStep.start => const StartScreen(),
            KioskStep.menu => const MenuScreen(),
            KioskStep.cart => const CartScreen(),
            KioskStep.payment => const PaymentScreen(),
            KioskStep.done => const DoneScreen(),
          };
    return IdleWatcher(
      child: Stack(
        children: [
          Positioned.fill(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 450),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, anim) => FadeTransition(
                opacity: anim,
                child: ScaleTransition(
                  scale: Tween(begin: 0.97, end: 1.0).animate(anim),
                  child: child,
                ),
              ),
              child: screen,
            ),
          ),
          const DemoBadge(),
          StaffCorner(onServerChanged: onServerChanged),
        ],
      ),
    );
  }
}
