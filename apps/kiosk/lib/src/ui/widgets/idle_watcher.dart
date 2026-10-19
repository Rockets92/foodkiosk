import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../scope.dart';
import '../theme.dart';
import 'pressable.dart';

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
    final total = widget.confirmTime.inSeconds;
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
                color: Colors.black.withValues(alpha: 0.6),
                child: Center(
                  child:
                      Container(
                        key: const ValueKey('idle-dialog'),
                        width: 680,
                        padding: const EdgeInsets.all(48),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(40),
                          boxShadow: K.shadowStrong,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox.square(
                              dimension: 160,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  SizedBox.expand(
                                    child: CircularProgressIndicator(
                                      value: _secondsLeft! / total,
                                      strokeWidth: 12,
                                      color: K.red,
                                      backgroundColor: K.line,
                                    ),
                                  ),
                                  Text(
                                    '$_secondsLeft',
                                    style: KText.display.copyWith(fontSize: 64),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 28),
                            Text(
                              t('stillThere'),
                              textAlign: TextAlign.center,
                              style: KText.h1,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              t('stillThereHint', args: {'n': _secondsLeft!}),
                              textAlign: TextAlign.center,
                              style: KText.body,
                            ),
                            const SizedBox(height: 36),
                            KButton(
                              key: const ValueKey('idle-continue'),
                              label: t('continue'),
                              height: 96,
                              expand: true,
                              onTap: _stay,
                            ),
                          ],
                        ),
                      ).animate().scale(
                        begin: const Offset(0.85, 0.85),
                        duration: 400.ms,
                        curve: Curves.easeOutBack,
                      ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
