import 'package:flutter/material.dart';

import '../../state/kiosk_controller.dart';

import '../scope.dart';
import '../theme.dart';

/// Shown while the server cannot be reached; retries automatically.
class OfflineScreen extends StatelessWidget {
  const OfflineScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final k = context.kiosk;
    final loading = k.loadState == LoadState.loading;
    return Scaffold(
      key: const ValueKey('offline'),
      backgroundColor: brandPrimary,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (loading)
              const CircularProgressIndicator(color: Colors.white)
            else ...[
              const Icon(Icons.cloud_off, color: Colors.white, size: 120),
              const SizedBox(height: 24),
              Text(
                context.t('outOfService'),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 36,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                k.backend.baseUri.toString(),
                style: const TextStyle(color: Colors.white70, fontSize: 18),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
