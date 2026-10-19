import 'dart:async';
import 'dart:io' show exit;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../scope.dart';

/// Invisible area in the top-left corner: a 3 second press opens the
/// staff menu (after the PIN), to change the server address or close the
/// app. Customers never see it.
class StaffCorner extends StatefulWidget {
  final Future<void> Function(Uri) onServerChanged;
  const StaffCorner({super.key, required this.onServerChanged});

  @override
  State<StaffCorner> createState() => _StaffCornerState();
}

class _StaffCornerState extends State<StaffCorner> {
  Timer? _hold;

  @override
  void dispose() {
    _hold?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      width: 80,
      height: 80,
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) =>
            _hold = Timer(const Duration(seconds: 3), _openMenu),
        onPointerUp: (_) => _hold?.cancel(),
        onPointerCancel: (_) => _hold?.cancel(),
      ),
    );
  }

  Future<void> _openMenu() async {
    final k = context.kiosk;
    final pin = await _prompt('PIN', obscure: true);
    if (pin == null || !mounted) return;
    if (!await k.backend.verifyStaffPin(pin)) {
      if (mounted) {
        ScaffoldMessenger.maybeOf(
          context,
        )?.showSnackBar(const SnackBar(content: Text('PIN errato')));
      }
      return;
    }
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Menu staff'),
        children: [
          SimpleDialogOption(
            child: const Text(
              'Indirizzo server',
              style: TextStyle(fontSize: 22),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              final url = await _prompt(
                'Indirizzo server',
                initial: k.backend.baseUri.toString(),
              );
              final uri = url == null ? null : Uri.tryParse(url.trim());
              if (uri != null && uri.hasScheme) {
                await widget.onServerChanged(uri);
              }
            },
          ),
          SimpleDialogOption(
            child: const Text('Ricarica menu', style: TextStyle(fontSize: 22)),
            onPressed: () {
              Navigator.pop(ctx);
              k.reload();
            },
          ),
          if (!kIsWeb)
            SimpleDialogOption(
              child: const Text(
                'Chiudi applicazione',
                style: TextStyle(fontSize: 22),
              ),
              onPressed: () => exit(0),
            ),
        ],
      ),
    );
  }

  Future<String?> _prompt(
    String label, {
    bool obscure = false,
    String? initial,
  }) {
    final controller = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(label),
        content: TextField(
          controller: controller,
          obscureText: obscure,
          autofocus: true,
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
