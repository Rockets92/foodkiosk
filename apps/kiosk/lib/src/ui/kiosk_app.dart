import 'package:flutter/material.dart';
import 'package:kiosk_core/kiosk_core.dart';

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
import 'widgets/coupon.dart';
import 'widgets/idle_watcher.dart';
import 'widgets/scanner_listener.dart';
import 'widgets/staff_corner.dart';

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
      child: _Themed(
        controller: controller,
        builder: (theme) => MaterialApp(
          title: 'Food Kiosk',
          debugShowCheckedModeBanner: false,
          theme: theme,
          builder: (context, child) => _FitToScreen(child: child!),
          home: _Shell(onServerChanged: onServerChanged),
        ),
      ),
    );
  }
}

/// Follows the palette of the server settings, rebuilding the theme only
/// when it changes.
class _Themed extends StatefulWidget {
  final KioskController controller;
  final Widget Function(ThemeData theme) builder;
  const _Themed({required this.controller, required this.builder});

  @override
  State<_Themed> createState() => _ThemedState();
}

class _ThemedState extends State<_Themed> {
  late ColorPalette _palette = widget.controller.settings.colors;
  late ThemeData _theme = kioskTheme(_palette);

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_sync);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_sync);
    super.dispose();
  }

  void _sync() {
    final next = widget.controller.settings.colors;
    if (next.id == _palette.id) return;
    setState(() {
      _palette = next;
      _theme = kioskTheme(next);
    });
    rebuildAll(context);
  }

  @override
  Widget build(BuildContext context) => widget.builder(_theme);
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
    final scanning =
        k.loadState == LoadState.ready &&
        k.discountsEnabled &&
        k.settings.discounts.scanner &&
        const {
          KioskStep.attract,
          KioskStep.start,
          KioskStep.menu,
          KioskStep.cart,
        }.contains(k.step);
    return ScannerListener(
      enabled: scanning,
      onScan: (code) => k.applyCoupon(code, scanned: true),
      child: IdleWatcher(child: _stack(screen)),
    );
  }

  Widget _stack(Widget screen) => Stack(
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
      const CouponToast(),
      StaffCorner(onServerChanged: onServerChanged),
    ],
  );
}

/// The kiosk is designed for a 1080 px wide portrait screen and needs at
/// least 900 px of height. On smaller screens (smaller totems, a window on
/// a PC) it is laid out at that size and scaled down, so it looks the same
/// instead of overflowing.
class _FitToScreen extends StatelessWidget {
  static const minWidth = 1080.0;
  static const minHeight = 900.0;
  final Widget child;
  const _FitToScreen({required this.child});

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final s = mq.size;
    if (s.isEmpty) return child;
    final scale = [
      1.0,
      s.width / minWidth,
      s.height / minHeight,
    ].reduce((a, b) => a < b ? a : b);
    if (scale >= 1) return child;
    final size = mq.size / scale;
    return ClipRect(
      child: OverflowBox(
        alignment: Alignment.topLeft,
        minWidth: 0,
        minHeight: 0,
        maxWidth: double.infinity,
        maxHeight: double.infinity,
        child: Transform.scale(
          scale: scale,
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: size.width,
            height: size.height,
            child: MediaQuery(
              data: mq.copyWith(
                size: size,
                padding: mq.padding / scale,
                viewPadding: mq.viewPadding / scale,
                viewInsets: mq.viewInsets / scale,
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
