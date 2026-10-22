import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:kiosk_core/kiosk_core.dart';

import '../../api.dart';
import '../../session.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Kitchen display: tickets move from "to prepare" to "in preparation" to
/// "ready", and are handed over from there. Updates live.
class KitchenScreen extends StatefulWidget {
  final bool fullscreen;
  final VoidCallback onToggleFullscreen;

  const KitchenScreen({
    super.key,
    this.fullscreen = false,
    required this.onToggleFullscreen,
  });

  @override
  State<KitchenScreen> createState() => _KitchenScreenState();
}

class _KitchenScreenState extends State<KitchenScreen> {
  List<Order> _orders = [];
  bool _loading = true;
  String? _error;
  StreamSubscription<ServerEvent>? _sub;
  Timer? _tick;
  final _busy = <String>{};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_sub == null) {
      final session = context.staffRead;
      _sub = session.orderEvents.listen((_) => _load());
      // Refreshes waiting times, and covers a lost event.
      _tick = Timer.periodic(const Duration(seconds: 20), (_) => _load());
      _load();
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _tick?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final orders = await context.staffRead.api.kitchenOrders();
      if (!mounted) return;
      setState(() {
        _orders = orders;
        _loading = false;
        _error = null;
      });
    } on ApiError catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.message;
        });
      }
    }
  }

  Future<void> _advance(Order o) async {
    final next = switch (o.kitchenStatus) {
      KitchenStatus.queued => KitchenStatus.preparing,
      KitchenStatus.preparing => KitchenStatus.ready,
      KitchenStatus.ready => KitchenStatus.collected,
      _ => null,
    };
    if (next == null || _busy.contains(o.id)) return;
    setState(() => _busy.add(o.id));
    final api = context.staffRead.api;
    final updated = await guard(
      context,
      () => api.setKitchenStatus(o.id, next),
    );
    if (!mounted) return;
    setState(() {
      _busy.remove(o.id);
      if (updated != null) {
        _orders = [
          for (final x in _orders)
            if (x.id != o.id)
              x
            else if (updated.kitchenStatus != KitchenStatus.collected)
              updated,
        ];
      }
    });
  }

  Future<void> _back(Order o) async {
    final prev = switch (o.kitchenStatus) {
      KitchenStatus.preparing => KitchenStatus.queued,
      KitchenStatus.ready => KitchenStatus.preparing,
      _ => null,
    };
    if (prev == null) return;
    final api = context.staffRead.api;
    await guard(context, () => api.setKitchenStatus(o.id, prev));
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final columns = [
      (KitchenStatus.queued, 'Da preparare', S.warning),
      (KitchenStatus.preparing, 'In preparazione', S.info),
      (KitchenStatus.ready, 'Pronti', S.success),
    ];
    return Scaffold(
      key: const ValueKey('kitchen'),
      backgroundColor: widget.fullscreen ? const Color(0xFF1C1C21) : null,
      body: Column(
        children: [
          _Header(
            dark: widget.fullscreen,
            count: _orders.length,
            fullscreen: widget.fullscreen,
            onToggleFullscreen: widget.onToggleFullscreen,
            onSoldOut: () => showDialog<void>(
              context: context,
              builder: (_) => StaffScope(
                session: context.staffRead,
                child: const _SoldOutDialog(),
              ),
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Pill(
                _error!,
                color: S.danger,
                icon: Icons.wifi_off_rounded,
              ),
            ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _orders.isEmpty
                ? EmptyState(
                    icon: Icons.soup_kitchen_rounded,
                    title: 'Nessun ordine in cucina',
                    message: _usesKitchen(context)
                        ? 'I nuovi ordini compaiono qui da soli.'
                        : 'Il flusso attuale non invia ordini allo schermo '
                              'cucina: attivalo in Impostazioni → Flusso.',
                  )
                : Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final (status, title, color) in columns)
                          Expanded(
                            child: _Lane(
                              title: title,
                              color: color,
                              dark: widget.fullscreen,
                              orders: [
                                for (final o in _orders)
                                  if (o.kitchenStatus == status) o,
                              ],
                              busy: _busy,
                              onAdvance: _advance,
                              onBack: _back,
                            ),
                          ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  bool _usesKitchen(BuildContext context) => context
      .staff
      .settings
      .flow
      .rules
      .values
      .any((a) => a.contains(FlowAction.sendToKitchenDisplay));
}

class _Header extends StatelessWidget {
  final bool dark;
  final int count;
  final bool fullscreen;
  final VoidCallback onToggleFullscreen;
  final VoidCallback onSoldOut;

  const _Header({
    required this.dark,
    required this.count,
    required this.fullscreen,
    required this.onToggleFullscreen,
    required this.onSoldOut,
  });

  @override
  Widget build(BuildContext context) {
    final fg = dark ? Colors.white : S.ink;
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 20, 20, 12),
      child: Row(
        children: [
          Icon(Icons.soup_kitchen_rounded, color: fg, size: 30),
          const SizedBox(width: 12),
          Text('Cucina', style: ST.h1.copyWith(color: fg)),
          const SizedBox(width: 12),
          Pill('$count ordini', color: dark ? S.accent : S.primary),
          const Spacer(),
          _Clock(color: fg),
          const SizedBox(width: 16),
          OutlinedButton.icon(
            key: const ValueKey('sold-out'),
            style: dark
                ? OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white24),
                  )
                : null,
            onPressed: onSoldOut,
            icon: const Icon(Icons.block_rounded),
            label: const Text('Esauriti'),
          ),
          const SizedBox(width: 8),
          IconButton.filledTonal(
            key: const ValueKey('kitchen-fullscreen'),
            tooltip: fullscreen ? 'Esci da schermo intero' : 'Schermo intero',
            onPressed: onToggleFullscreen,
            icon: Icon(
              fullscreen
                  ? Icons.fullscreen_exit_rounded
                  : Icons.fullscreen_rounded,
            ),
          ),
        ],
      ),
    );
  }
}

class _Clock extends StatefulWidget {
  final Color color;
  const _Clock({required this.color});

  @override
  State<_Clock> createState() => _ClockState();
}

class _ClockState extends State<_Clock> {
  late final Timer _timer = Timer.periodic(
    const Duration(seconds: 15),
    (_) => setState(() {}),
  );

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Text(
    hhmm(DateTime.now()),
    style: TextStyle(
      color: widget.color,
      fontSize: 26,
      fontWeight: FontWeight.w800,
    ),
  );
}

class _Lane extends StatelessWidget {
  final String title;
  final Color color;
  final bool dark;
  final List<Order> orders;
  final Set<String> busy;
  final void Function(Order) onAdvance;
  final void Function(Order) onBack;

  const _Lane({
    required this.title,
    required this.color,
    required this.dark,
    required this.orders,
    required this.busy,
    required this.onAdvance,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: dark
            ? Colors.white.withValues(alpha: 0.04)
            : Colors.black.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
            child: Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: ST.h2.copyWith(color: dark ? Colors.white : S.ink),
                ),
                const Spacer(),
                Text('${orders.length}', style: ST.h2.copyWith(color: color)),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
              children: [
                for (final o in orders)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _Ticket(
                      key: ValueKey(o.id),
                      order: o,
                      color: color,
                      busy: busy.contains(o.id),
                      onAdvance: () => onAdvance(o),
                      onBack: () => onBack(o),
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

class _Ticket extends StatelessWidget {
  final Order order;
  final Color color;
  final bool busy;
  final VoidCallback onAdvance;
  final VoidCallback onBack;

  const _Ticket({
    super.key,
    required this.order,
    required this.color,
    required this.busy,
    required this.onAdvance,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final minutes = DateTime.now().difference(order.createdAt).inMinutes;
    final late = minutes >= 10;
    final waitColor = minutes < 5
        ? S.success
        : late
        ? S.danger
        : S.warning;
    final (action, icon) = switch (order.kitchenStatus) {
      KitchenStatus.queued => ('Inizia', Icons.play_arrow_rounded),
      KitchenStatus.preparing => ('Pronto', Icons.check_rounded),
      _ => ('Consegnato', Icons.done_all_rounded),
    };
    final allergens = {for (final l in order.lines) ...l.allergens};
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: late ? Border.all(color: S.danger, width: 2) : null,
        boxShadow: S.shadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: color.withValues(alpha: 0.12),
            padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
            child: Row(
              children: [
                Text(
                  orderNumber(order.number),
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    color: color,
                  ),
                ),
                const SizedBox(width: 10),
                Icon(serviceModeIcon(order.serviceMode), size: 20),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    serviceModeLabel(order.serviceMode),
                    overflow: TextOverflow.ellipsis,
                    style: ST.h3,
                  ),
                ),
                const Spacer(),
                Icon(Icons.timer_outlined, size: 18, color: waitColor),
                const SizedBox(width: 2),
                Text(
                  "$minutes'",
                  style: TextStyle(
                    color: waitColor,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                if (order.kitchenStatus != KitchenStatus.queued)
                  IconButton(
                    tooltip: 'Torna indietro',
                    visualDensity: VisualDensity.compact,
                    onPressed: onBack,
                    icon: const Icon(Icons.undo_rounded, size: 20),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final l in order.lines) ...[
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: '${l.quantity}× ',
                          style: TextStyle(
                            color: S.primary,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        TextSpan(text: l.name.resolve('it')),
                      ],
                    ),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  for (final o in l.options)
                    Padding(
                      padding: const EdgeInsets.only(left: 28),
                      child: Text(
                        o.name.resolve('it'),
                        style: const TextStyle(fontSize: 15, color: S.inkSoft),
                      ),
                    ),
                  if (l.note case final note? when note.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(left: 28),
                      child: Text(
                        '“$note”',
                        style: TextStyle(
                          fontSize: 15,
                          fontStyle: FontStyle.italic,
                          color: S.primary,
                        ),
                      ),
                    ),
                  const SizedBox(height: 6),
                ],
                if (allergens.isNotEmpty)
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      for (final a in allergens)
                        Pill(
                          a.label.resolve('it'),
                          color: S.warning,
                          icon: Icons.warning_amber_rounded,
                        ),
                    ],
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
            child: FilledButton.icon(
              key: ValueKey('advance-${order.number}'),
              style: FilledButton.styleFrom(
                backgroundColor: color,
                minimumSize: const Size.fromHeight(56),
              ),
              onPressed: busy ? null : onAdvance,
              icon: Icon(icon),
              label: Text(action, style: const TextStyle(fontSize: 18)),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.1);
  }
}

/// Quick sold-out switches, so the kitchen can stop a product on the
/// kiosks without opening the menu editor.
class _SoldOutDialog extends StatelessWidget {
  const _SoldOutDialog();

  @override
  Widget build(BuildContext context) {
    final session = context.staff;
    final menu = session.menu;
    return AlertDialog(
      title: const Text('Prodotti esauriti', style: ST.h2),
      content: SizedBox(
        width: 520,
        height: 560,
        child: ListView(
          children: [
            for (final c in menu.categories) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 12, 4, 4),
                child: Text(c.name.resolve('it'), style: ST.h3),
              ),
              for (final p in menu.productsIn(c.id))
                SwitchListTile(
                  key: ValueKey('soldout-${p.id}'),
                  secondary: ServerImage(p.imageUrl, size: 40, radius: 10),
                  title: Text(p.name.resolve('it')),
                  subtitle: Text(p.soldOut ? 'Esaurito' : 'Disponibile'),
                  value: !p.soldOut,
                  onChanged: (available) => guard(
                    context,
                    () => session.api.patchProduct(p.id, soldOut: !available),
                  ).then((_) => session.reloadMenu()),
                ),
            ],
          ],
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Fatto'),
        ),
      ],
    );
  }
}
