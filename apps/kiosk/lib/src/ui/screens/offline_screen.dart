import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../state/kiosk_controller.dart';
import '../scope.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Shown while the server cannot be reached; retries automatically.
class OfflineScreen extends StatelessWidget {
  const OfflineScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final k = context.kiosk;
    final loading = k.loadState == LoadState.loading;
    return Scaffold(
      key: const ValueKey('offline'),
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: K.heroGradient),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const VenueLogo(size: 160)
                  .animate(onPlay: (c) => c.repeat(reverse: true))
                  .scaleXY(begin: 0.95, end: 1.05, duration: 900.ms),
              const SizedBox(height: 32),
              if (loading)
                const CircularProgressIndicator(color: Colors.white)
              else ...[
                Text(
                  context.t('outOfService'),
                  textAlign: TextAlign.center,
                  style: KText.h1.copyWith(color: Colors.white),
                ),
                const SizedBox(height: 12),
                Text(
                  k.backend.baseUri.toString(),
                  style: KText.body.copyWith(color: Colors.white70),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
