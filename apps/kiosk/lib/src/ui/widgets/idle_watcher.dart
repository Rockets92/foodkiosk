import 'dart:async';

import 'package:flutter/material.dart';

import '../scope.dart';

/// Resets the kiosk when a customer walks away mid-order: after the idle
/// timeout it asks "are you still there?" and resets if nobody answers.
class IdleWatcher extends StatefulWidget {
  final Widget child;
  final Duration confirmTime;

  const IdleWatcher({
    super.key,
    required this.child,
    this.confirmTime = const Duration(seconds: 15),
  });

  @override
  State<IdleWatcher> createState() => _IdleWatcherState();
}

class _IdleWatcherState extends State<IdleWatcher> {
  Timer? _idle;
  Timer? _countdown;
  int? _secondsLeft;

  void _restart() {
    _idle?.cancel();
    final k = context.kiosk;
    if (!k.idleSensitive || _secondsLeft != null) return;
    _idle = Timer(Duration(seconds: k.settings.idleTimeoutSeconds), _ask);
  }

  void _ask() {
    setState(() => _secondsLeft = widget.confirmTime.inSeconds);
    _countdown = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return timer.cancel();
      final left = (_secondsLeft ?? 0) - 1;
      if (left <= 0) {
        timer.cancel();
        setState(() => _secondsLeft = null);
        Navigator.of(context).popUntil((r) => r.isFirst);
        context.kiosk.cancelAndReset();
      } else {
        setState(() => _secondsLeft = left);
      }
    });
  }

  void _stay() {
    _countdown?.cancel();
    setState(() => _secondsLeft = null);
    _restart();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Rebuilt on every controller change: re-arm for the current step.
    if (_secondsLeft == null) _restart();
  }

  @override
  void dispose() {
    _idle?.cancel();
    _countdown?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) {
        if (_secondsLeft == null) _restart();
      },
      child: Stack(
        children: [
          widget.child,
          if (_secondsLeft != null)
            Positioned.fill(
              child: ColoredBox(
                color: Colors.black54,
                child: Center(
                  child: Card(
                    key: const ValueKey('idle-dialog'),
                    child: Padding(
                      padding: const EdgeInsets.all(40),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            t('stillThere'),
                            style: const TextStyle(
                              fontSize: 40,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            t('stillThereHint', args: {'n': _secondsLeft!}),
                            style: const TextStyle(fontSize: 24),
                          ),
                          const SizedBox(height: 32),
                          FilledButton(
                            key: const ValueKey('idle-continue'),
                            onPressed: _stay,
                            child: Text(t('continue')),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
