import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:kiosk_core/kiosk_core.dart';

import '../../api.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Customer-facing monitor: numbers in preparation and ready to collect.
/// Uses only the public endpoint, so it runs without a staff PIN.
class PickupScreen extends StatefulWidget {
  final StaffApi api;
  final VoidCallback? onExit;
  final VoidCallback? onFullscreen;
  final Duration refresh;

  const PickupScreen({
    super.key,
    required this.api,
    this.onExit,
    this.onFullscreen,
    this.refresh = const Duration(seconds: 2),
  });

  @override
  State<PickupScreen> createState() => _PickupScreenState();
}

class _PickupScreenState extends State<PickupScreen> {
  List<int> _preparing = [];
  List<int> _ready = [];
  bool _offline = false;
  Timer? _timer;
  StreamSubscription<ServerEvent>? _events;

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(widget.refresh, (_) => _load());
    // Standalone (no PIN): keep a live connection too, so announcements
    // show at once and the server lists this screen among its devices.
    if (widget.api.pin.isEmpty) {
      _events = widget.api.events().listen((_) => _load());
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _events?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final board = await widget.api.pickup();
      if (!mounted) return;
      setState(() {
        _preparing = board.preparing;
        _ready = board.ready;
        _offline = false;
      });
    } on ApiError {
      if (mounted) setState(() => _offline = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const ValueKey('pickup'),
      backgroundColor: S.nav,
      body: Stack(
        children: [
          Row(
            children: [
              Expanded(
                flex: 2,
                child: _Column(
                  title: 'In preparazione',
                  icon: Icons.local_fire_department_rounded,
                  numbers: _preparing,
                  background: const Color(0xFF232329),
                  numberColor: Colors.white70,
                  numberSize: 64,
                ),
              ),
              Expanded(
                flex: 3,
                child: _Column(
                  title: 'Pronto! Ritira qui',
                  icon: Icons.check_circle_rounded,
                  numbers: _ready,
                  background: S.red,
                  numberColor: S.yellow,
                  numberSize: 96,
                  highlight: true,
                ),
              ),
            ],
          ),
          if (_offline)
            const Positioned(
              left: 0,
              right: 0,
              bottom: 16,
              child: Center(
                child: Pill(
                  'Connessione al server persa',
                  color: S.yellow,
                  icon: Icons.wifi_off_rounded,
                ),
              ),
            ),
          Positioned(
            top: 12,
            right: 12,
            child: Row(
              children: [
                if (widget.onFullscreen != null)
                  IconButton(
                    tooltip: 'Schermo intero',
                    onPressed: widget.onFullscreen,
                    icon: const Icon(
                      Icons.fullscreen_rounded,
                      color: Colors.white38,
                    ),
                  ),
                if (widget.onExit != null)
                  IconButton(
                    key: const ValueKey('pickup-exit'),
                    tooltip: 'Esci',
                    onPressed: widget.onExit,
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Colors.white38,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Column extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<int> numbers;
  final Color background;
  final Color numberColor;
  final double numberSize;
  final bool highlight;

  const _Column({
    required this.title,
    required this.icon,
    required this.numbers,
    required this.background,
    required this.numberColor,
    required this.numberSize,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: background,
      padding: const EdgeInsets.fromLTRB(32, 40, 32, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.white, size: 40),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 38,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          Expanded(
            child: SingleChildScrollView(
              child: Wrap(
                spacing: 20,
                runSpacing: 20,
                children: [
                  for (final n in numbers)
                    _Number(
                      key: ValueKey(n),
                      number: n,
                      color: numberColor,
                      size: numberSize,
                      highlight: highlight,
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Number extends StatelessWidget {
  final int number;
  final Color color;
  final double size;
  final bool highlight;

  const _Number({
    super.key,
    required this.number,
    required this.color,
    required this.size,
    required this.highlight,
  });

  @override
  Widget build(BuildContext context) {
    final box = Container(
      padding: EdgeInsets.symmetric(horizontal: size * 0.3, vertical: 6),
      decoration: BoxDecoration(
        color: highlight
            ? Colors.black.withValues(alpha: 0.18)
            : Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Text(
        orderNumber(number),
        style: TextStyle(
          color: color,
          fontSize: size,
          fontWeight: FontWeight.w900,
          height: 1.1,
        ),
      ),
    );
    final entered = box
        .animate()
        .fadeIn(duration: 400.ms)
        .scale(
          begin: const Offset(0.6, 0.6),
          curve: Curves.easeOutBack,
          duration: 500.ms,
        );
    // Newly ready numbers pulse a few times to catch the eye.
    return highlight
        ? entered
              .animate(delay: 500.ms)
              .shimmer(duration: 900.ms, color: Colors.white54)
              .then()
              .shimmer(duration: 900.ms, color: Colors.white54)
        : entered;
  }
}
