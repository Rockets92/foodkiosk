import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:kiosk_core/kiosk_core.dart';

import '../../api.dart';
import '../../session.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Day overview: takings, orders, average ticket, orders by hour and the
/// best-selling products.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Map<String, Object?>? _data;
  String? _error;
  DateTime _day = DateTime.now();
  StreamSubscription<ServerEvent>? _sub;
  Timer? _debounce;

  String get _dayKey =>
      '${_day.year.toString().padLeft(4, '0')}-'
      '${_day.month.toString().padLeft(2, '0')}-'
      '${_day.day.toString().padLeft(2, '0')}';

  bool get _isToday {
    final now = DateTime.now();
    return _day.year == now.year &&
        _day.month == now.month &&
        _day.day == now.day;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_sub == null) {
      _sub = context.staffRead.orderEvents.listen((_) {
        _debounce?.cancel();
        _debounce = Timer(const Duration(milliseconds: 800), _load);
      });
      _load();
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final data = await context.staffRead.api.summary(day: _dayKey);
      if (mounted) {
        setState(() {
          _data = data;
          _error = null;
        });
      }
    } on ApiError catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _pickDay() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _day,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      locale: const Locale('it'),
    );
    if (picked == null) return;
    setState(() {
      _day = picked;
      _data = null;
    });
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    return Scaffold(
      key: const ValueKey('dashboard'),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PageHeader(
            title: 'Riepilogo',
            subtitle: _isToday
                ? 'Andamento di oggi, aggiornato in tempo reale'
                : 'Andamento del ${_day.day}/${_day.month}/${_day.year}',
            actions: [
              OutlinedButton.icon(
                key: const ValueKey('dashboard-day'),
                onPressed: _pickDay,
                icon: const Icon(Icons.calendar_month_rounded),
                label: Text(_isToday ? 'Oggi' : '${_day.day}/${_day.month}'),
              ),
              IconButton.filledTonal(
                tooltip: 'Aggiorna',
                onPressed: _load,
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          Expanded(
            child: data == null
                ? _error == null
                      ? const Center(child: CircularProgressIndicator())
                      : EmptyState(
                          icon: Icons.wifi_off_rounded,
                          title: 'Riepilogo non disponibile',
                          message: _error,
                          action: FilledButton(
                            onPressed: _load,
                            child: const Text('Riprova'),
                          ),
                        )
                : _Body(data: data),
          ),
        ],
      ),
    );
  }
}

class _Body extends StatelessWidget {
  final Map<String, Object?> data;
  const _Body({required this.data});

  int _int(String key) => (data[key] as num?)?.toInt() ?? 0;

  @override
  Widget build(BuildContext context) {
    final money = context.staff.money;
    final demo = _int('demoOrders');
    final byHour = [
      for (final n in data['byHour'] as List? ?? const []) (n as num).toInt(),
    ];
    final top = [
      for (final p in data['topProducts'] as List? ?? const [])
        (p as Map).cast<String, Object?>(),
    ];
    final tiles = [
      (
        'Incasso',
        money(_int('revenueCents')),
        Icons.euro_rounded,
        S.success,
        'contanti ${money(_int('cashCents'))} · '
            'carta ${money(_int('cardCents'))}',
      ),
      (
        'Ordini',
        '${_int('orders')}',
        Icons.receipt_long_rounded,
        S.info,
        '${_int('eatIn')} qui · ${_int('takeAway')} via',
      ),
      (
        'Scontrino medio',
        money(_int('averageCents')),
        Icons.shopping_basket_rounded,
        S.red,
        'sugli ordini pagati',
      ),
      (
        'Da incassare',
        '${_int('awaitingCounter')}',
        Icons.point_of_sale_rounded,
        S.warning,
        'in attesa alla cassa',
      ),
      (
        'Annullati',
        '${_int('cancelled')}',
        Icons.cancel_outlined,
        S.muted,
        'esclusi dai totali',
      ),
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(28, 0, 28, 28),
      children: [
        if (demo > 0) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: S.yellow.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const Icon(Icons.science_rounded),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '$demo ordini sono stati fatti in modalità demo: '
                    'pagamenti simulati, non sono incassi reali.',
                    style: ST.body,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        LayoutBuilder(
          builder: (context, box) {
            final perRow = box.maxWidth > 1100 ? 5 : 3;
            final w = (box.maxWidth - 16 * (perRow - 1)) / perRow;
            return Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                for (final (i, t) in tiles.indexed)
                  SizedBox(
                    width: w,
                    child: _Kpi(
                      label: t.$1,
                      value: t.$2,
                      icon: t.$3,
                      color: t.$4,
                      note: t.$5,
                    ).animate().fadeIn(delay: (60 * i).ms).slideY(begin: 0.15),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, box) {
            final wide = box.maxWidth > 1000;
            final chart = Panel(child: _HourChart(byHour: byHour));
            final right = Column(
              children: [
                Panel(
                  child: _TopProducts(products: top, money: money),
                ),
                const SizedBox(height: 16),
                Panel(
                  child: _ModeSplit(
                    eatIn: _int('eatIn'),
                    takeAway: _int('takeAway'),
                  ),
                ),
              ],
            );
            if (!wide) {
              return Column(
                children: [chart, const SizedBox(height: 16), right],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: chart),
                const SizedBox(width: 16),
                Expanded(flex: 2, child: right),
              ],
            );
          },
        ).animate().fadeIn(delay: 300.ms, duration: 400.ms),
      ],
    );
  }
}

class _Kpi extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final String note;

  const _Kpi({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.note,
  });

  @override
  Widget build(BuildContext context) => Panel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: ST.small,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800),
          ),
        ),
        Text(
          note,
          style: ST.small,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    ),
  );
}

class _HourChart extends StatelessWidget {
  final List<int> byHour;
  const _HourChart({required this.byHour});

  @override
  Widget build(BuildContext context) {
    final hours = byHour.length == 24 ? byHour : List.filled(24, 0);
    final used = [
      for (var h = 0; h < 24; h++)
        if (hours[h] > 0) h,
    ];
    final from = used.isEmpty ? 7 : min(used.first, 11);
    final to = used.isEmpty ? 23 : max(used.last, 15);
    final peak = hours.reduce(max);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Ordini per fascia oraria', style: ST.h2),
        const SizedBox(height: 4),
        Text(
          peak == 0
              ? 'Ancora nessun ordine'
              : 'Ora di punta: ${hours.indexOf(peak)}:00 con $peak ordini',
          style: ST.small,
        ),
        const SizedBox(height: 20),
        SizedBox(
          height: 240,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var h = from; h <= to; h++)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (hours[h] > 0)
                          Text(
                            '${hours[h]}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        const SizedBox(height: 4),
                        TweenAnimationBuilder<double>(
                          tween: Tween(
                            begin: 0,
                            end: peak == 0 ? 0 : hours[h] / peak,
                          ),
                          duration: const Duration(milliseconds: 700),
                          curve: Curves.easeOutCubic,
                          builder: (_, v, _) => Container(
                            height: max(4, 180 * v),
                            decoration: BoxDecoration(
                              color: hours[h] == peak && peak > 0
                                  ? S.red
                                  : hours[h] > 0
                                  ? S.red.withValues(alpha: 0.45)
                                  : S.line,
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text('$h', style: ST.small),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TopProducts extends StatelessWidget {
  final List<Map<String, Object?>> products;
  final String Function(Cents) money;
  const _TopProducts({required this.products, required this.money});

  @override
  Widget build(BuildContext context) {
    final maxQty = products.isEmpty
        ? 1
        : products.map((p) => (p['quantity'] as num).toInt()).reduce(max);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Più venduti', style: ST.h2),
        const SizedBox(height: 12),
        if (products.isEmpty)
          const Text('Nessuna vendita', style: ST.small)
        else
          for (final (i, p) in products.take(8).indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  SizedBox(
                    width: 24,
                    child: Text(
                      '${i + 1}',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: i < 3 ? S.red : S.muted,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                p['name'] as String? ?? '',
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Text(
                              '${p['quantity']} · '
                              '${money((p['totalCents'] as num).toInt())}',
                              style: ST.small,
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: (p['quantity'] as num) / maxQty,
                            minHeight: 6,
                            backgroundColor: S.line,
                            color: i < 3 ? S.red : S.yellow,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
      ],
    );
  }
}

class _ModeSplit extends StatelessWidget {
  final int eatIn;
  final int takeAway;
  const _ModeSplit({required this.eatIn, required this.takeAway});

  @override
  Widget build(BuildContext context) {
    final total = eatIn + takeAway;
    final share = total == 0 ? 0.5 : eatIn / total;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Mangio qui / Porto via', style: ST.h2),
        const SizedBox(height: 14),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            height: 18,
            child: Row(
              children: [
                Expanded(
                  flex: max(1, (share * 1000).round()),
                  child: Container(color: total == 0 ? S.line : S.red),
                ),
                Expanded(
                  flex: max(1, ((1 - share) * 1000).round()),
                  child: Container(color: total == 0 ? S.line : S.yellow),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _Legend(
              color: S.red,
              icon: serviceModeIcon(ServiceMode.eatIn),
              text:
                  'Mangio qui $eatIn'
                  '${total == 0 ? '' : ' (${(share * 100).round()}%)'}',
            ),
            const Spacer(),
            _Legend(
              color: S.yellow,
              icon: serviceModeIcon(ServiceMode.takeAway),
              text:
                  'Porto via $takeAway'
                  '${total == 0 ? '' : ' (${((1 - share) * 100).round()}%)'}',
            ),
          ],
        ),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String text;
  const _Legend({required this.color, required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 6),
      Icon(icon, size: 16, color: S.inkSoft),
      const SizedBox(width: 4),
      Text(text, style: ST.small),
    ],
  );
}
