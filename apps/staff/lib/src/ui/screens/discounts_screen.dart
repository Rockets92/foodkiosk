import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:kiosk_core/kiosk_core.dart';

import '../../api.dart';
import '../../session.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'discounts/discount_editor.dart';

enum _Filter {
  all('Tutti'),
  active('Attivi'),
  exhausted('Esauriti'),
  expired('Scaduti'),
  off('Disattivati');

  final String label;
  const _Filter(this.label);
}

/// The state of a code right now, for its badge and the filters.
enum CodeStatus {
  active('Attivo', S.success),
  scheduled('Non ancora attivo', S.info),
  exhausted('Esaurito', S.warning),
  expired('Scaduto', S.muted),
  off('Disattivato', S.muted);

  final String label;
  final Color color;
  const CodeStatus(this.label, this.color);

  static CodeStatus of(DiscountCode c, DateTime now) =>
      switch (c.unavailableReason(now)) {
        null => active,
        'codeDisabled' => off,
        'codeNotYetValid' => scheduled,
        'codeExpired' => expired,
        _ => exhausted,
      };
}

/// Discount codes: create, edit, switch off, see how much each was used,
/// show its QR code / barcode.
class DiscountsScreen extends StatefulWidget {
  const DiscountsScreen({super.key});

  @override
  State<DiscountsScreen> createState() => _DiscountsScreenState();
}

class _DiscountsScreenState extends State<DiscountsScreen> {
  List<DiscountCode>? _codes;
  String? _error;
  _Filter _filter = _Filter.all;
  String _query = '';
  StreamSubscription<ServerEvent>? _sub;

  @override
  void initState() {
    super.initState();
    final session = context.staffRead;
    _load();
    _sub = session.events
        .where(
          (e) =>
              e.type == ServerEvent.discountsUpdated ||
              e.type == ServerEvent.orderCreated,
        )
        .listen((_) => _load());
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final codes = await context.staffRead.api.discounts();
      if (mounted) {
        setState(() {
          _codes = codes;
          _error = null;
        });
      }
    } on ApiError catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  bool _matches(DiscountCode c, DateTime now) {
    final q = _query.trim().toUpperCase();
    if (q.isNotEmpty &&
        !c.code.contains(q) &&
        !c.note.toUpperCase().contains(q) &&
        !c.label.resolve('it').toUpperCase().contains(q)) {
      return false;
    }
    final status = CodeStatus.of(c, now);
    return switch (_filter) {
      _Filter.all => true,
      _Filter.active =>
        status == CodeStatus.active || status == CodeStatus.scheduled,
      _Filter.exhausted => status == CodeStatus.exhausted,
      _Filter.expired => status == CodeStatus.expired,
      _Filter.off => status == CodeStatus.off,
    };
  }

  @override
  Widget build(BuildContext context) {
    final session = context.staff;
    final now = DateTime.now();
    final codes = _codes ?? const <DiscountCode>[];
    final shown = [
      for (final c in codes)
        if (_matches(c, now)) c,
    ];
    final active = codes
        .where((c) => CodeStatus.of(c, now) == CodeStatus.active)
        .length;
    final uses = codes.fold(0, (s, c) => s + c.usedCount);
    final d = session.settings.discounts;
    final where = [
      if (d.manualEntry) 'tastiera del totem',
      if (d.scanner) 'lettore QR/barcode',
      if (d.atCounter) 'cassa',
    ].join(', ');
    return Scaffold(
      key: const ValueKey('discounts'),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PageHeader(
            title: 'Codici sconto',
            subtitle:
                '${codes.length} codici · $active attivi · $uses utilizzi'
                '${where.isEmpty ? '' : ' · accettati da: $where'}',
            actions: [
              FilledButton.icon(
                key: const ValueKey('new-discount'),
                onPressed: () => editDiscount(context),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Nuovo codice'),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 0, 28, 12),
            child: Row(
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    children: [
                      for (final f in _Filter.values)
                        ChoiceChip(
                          key: ValueKey('discount-filter-${f.name}'),
                          label: Text(f.label),
                          selected: _filter == f,
                          selectedColor: S.ink,
                          labelStyle: TextStyle(
                            color: _filter == f ? Colors.white : S.ink,
                            fontWeight: FontWeight.w600,
                          ),
                          showCheckmark: false,
                          onSelected: (_) => setState(() => _filter = f),
                        ),
                    ],
                  ),
                ),
                SizedBox(
                  width: 260,
                  child: TextField(
                    key: const ValueKey('discount-search'),
                    onChanged: (v) => setState(() => _query = v),
                    decoration: const InputDecoration(
                      hintText: 'Cerca codice o nota',
                      prefixIcon: Icon(Icons.search_rounded),
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _codes == null
                ? (_error == null
                      ? const Center(child: CircularProgressIndicator())
                      : EmptyState(
                          icon: Icons.cloud_off_rounded,
                          title: 'Codici non disponibili',
                          message: _error,
                          action: OutlinedButton(
                            onPressed: _load,
                            child: const Text('Riprova'),
                          ),
                        ))
                : shown.isEmpty
                ? EmptyState(
                    icon: Icons.local_offer_outlined,
                    title: codes.isEmpty
                        ? 'Nessun codice sconto'
                        : 'Nessun codice in questo elenco',
                    message: codes.isEmpty
                        ? 'Crea un codice percentuale, a importo fisso o '
                              'con un prodotto in omaggio.'
                        : null,
                    action: codes.isEmpty
                        ? FilledButton.icon(
                            onPressed: () => editDiscount(context),
                            icon: const Icon(Icons.add_rounded),
                            label: const Text('Nuovo codice'),
                          )
                        : null,
                  )
                : GridView.builder(
                    padding: const EdgeInsets.fromLTRB(28, 4, 28, 28),
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 560,
                          mainAxisExtent: 214,
                          crossAxisSpacing: 18,
                          mainAxisSpacing: 18,
                        ),
                    itemCount: shown.length,
                    itemBuilder: (_, i) =>
                        _CodeCard(code: shown[i], now: now, onChanged: _load)
                            .animate()
                            .fadeIn(delay: (25 * i.clamp(0, 12)).ms)
                            .slideY(begin: 0.08),
                  ),
          ),
        ],
      ),
    );
  }
}

class _CodeCard extends StatelessWidget {
  final DiscountCode code;
  final DateTime now;
  final VoidCallback onChanged;
  const _CodeCard({
    required this.code,
    required this.now,
    required this.onChanged,
  });

  Future<void> _toggle(BuildContext context, bool on) async {
    final api = context.staffRead.api;
    final json = {...code.toJson(), 'enabled': on};
    await guard(context, () => api.saveDiscount(DiscountCode.fromJson(json)));
    onChanged();
  }

  Future<void> _menu(BuildContext context, String action) async {
    final api = context.staffRead.api;
    switch (action) {
      case 'reset':
        if (!await confirm(
          context,
          title: 'Azzerare gli utilizzi di ${code.code}?',
          message: 'Il contatore torna a 0 e il codice si può usare di nuovo.',
          confirmLabel: 'Azzera',
        )) {
          return;
        }
        if (context.mounted) {
          await guard(context, () => api.resetDiscountUses(code.id));
        }
      case 'delete':
        if (!await confirm(
          context,
          title: 'Eliminare il codice ${code.code}?',
          message:
              'Non sarà più accettato. Gli ordini che l\'hanno usato '
              'restano invariati.',
          confirmLabel: 'Elimina',
          destructive: true,
        )) {
          return;
        }
        if (context.mounted) {
          await guard(context, () => api.deleteDiscount(code.id));
        }
    }
    onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final status = CodeStatus.of(code, now);
    final max = code.maxUses;
    final dim = status == CodeStatus.off || status == CodeStatus.expired;
    return Opacity(
      opacity: dim ? 0.6 : 1,
      child: DiscountTicket(
        key: ValueKey('discount-${code.code}'),
        code: code,
        footer: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    max == null
                        ? '${code.usedCount} utilizzi · illimitato'
                        : '${code.usedCount} / $max utilizzi',
                    overflow: TextOverflow.ellipsis,
                    style: ST.small.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                Pill(status.label, color: status.color),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: TweenAnimationBuilder<double>(
                tween: Tween(
                  begin: 0,
                  end: max == null
                      ? (code.usedCount > 0 ? 1 : 0)
                      : (code.usedCount / max).clamp(0, 1),
                ),
                duration: const Duration(milliseconds: 900),
                curve: Curves.easeOutCubic,
                builder: (_, v, _) => LinearProgressIndicator(
                  value: v,
                  minHeight: 7,
                  backgroundColor: S.line,
                  color: max == null
                      ? S.info.withValues(alpha: 0.4)
                      : DiscountTicket.colorOf(code.type),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Switch(
                  key: ValueKey('discount-switch-${code.code}'),
                  value: code.enabled,
                  onChanged: (v) => _toggle(context, v),
                ),
                const Spacer(),
                IconButton(
                  key: ValueKey('discount-qr-${code.code}'),
                  tooltip: 'QR code e codice a barre',
                  onPressed: () => showDiscountQr(context, code),
                  icon: const Icon(Icons.qr_code_2_rounded),
                ),
                IconButton(
                  key: ValueKey('discount-edit-${code.code}'),
                  tooltip: 'Modifica',
                  onPressed: () async {
                    await editDiscount(context, code: code);
                    onChanged();
                  },
                  icon: const Icon(Icons.edit_rounded),
                ),
                PopupMenuButton<String>(
                  tooltip: 'Altro',
                  onSelected: (a) => _menu(context, a),
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'reset',
                      child: ListTile(
                        leading: Icon(Icons.restart_alt_rounded),
                        title: Text('Azzera utilizzi'),
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: ListTile(
                        leading: Icon(
                          Icons.delete_outline_rounded,
                          color: S.red,
                        ),
                        title: Text('Elimina'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
