import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:kiosk_core/kiosk_core.dart';

import '../../theme.dart';
import '../../widgets/common.dart';
import 'fields.dart';

const presetInfo = {
  'orderOnly': (
    'Solo ordine',
    'Il totem stampa lo scontrino e il cliente paga in cassa.',
    Icons.receipt_long_rounded,
  ),
  'payAtCounterKitchenAfterPayment': (
    'Cassa, poi cucina',
    'Paga in cassa: la cucina riceve l\'ordine dopo l\'incasso.',
    Icons.point_of_sale_rounded,
  ),
  'payAtCounterKitchenImmediately': (
    'Cassa e cucina subito',
    'La cucina parte subito, il cliente paga in cassa.',
    Icons.bolt_rounded,
  ),
  'fullService': (
    'Servizio completo',
    'Pagamento col POS sul totem, documento fiscale, cucina e ritiro.',
    Icons.credit_card_rounded,
  ),
};

/// Italian text for the flow issue codes of [FlowConfig.validate].
String flowIssueText(FlowIssue i) => switch (i.code) {
  'duplicateAction' => 'Un\'azione è ripetuta due volte nello stesso momento.',
  'fiscalBeforePayment' =>
    'Il documento fiscale si può emettere solo a ordine pagato.',
  'unreachablePaid' =>
    'Il pagamento è disattivato: le azioni su "Ordine pagato" non '
        'verrebbero mai eseguite.',
  'kitchenTwice' =>
    'La cucina riceve l\'ordine due volte: alla conferma e al pagamento.',
  'readyWithoutKitchen' =>
    'Nessun ordine arriva allo schermo cucina, quindi nessuno può segnarlo '
        'pronto.',
  'noTicket' =>
    'Il cliente non riceve uno scontrino stampato: il numero è solo a '
        'schermo.',
  'counterNoTicket' =>
    'Chi paga in cassa non ha uno scontrino da mostrare al cassiere.',
  _ => i.message,
};

/// Canonical form (events and actions in enum order, no empty lists), to
/// compare a flow with the presets.
String canonicalFlow(FlowConfig f) => jsonEncode({
  'paymentMode': f.paymentMode.name,
  'rules': {
    for (final e in FlowEvent.values)
      if (f.actionsFor(e).isNotEmpty)
        e.name: [
          for (final a in FlowAction.values)
            if (f.actionsFor(e).contains(a)) a.name,
        ],
  },
});

class FlowSection extends StatelessWidget {
  final FlowConfig flow;
  final Map<String, FlowConfig> presets;
  final List<FlowIssue> issues;
  final bool validating;
  final bool counterFallback;
  final ValueChanged<FlowConfig> onChanged;
  final ValueChanged<bool> onCounterFallback;

  const FlowSection({
    super.key,
    required this.flow,
    required this.presets,
    required this.issues,
    required this.validating,
    required this.counterFallback,
    required this.onChanged,
    required this.onCounterFallback,
  });

  void _toggle(FlowEvent e, FlowAction a, bool on) {
    final rules = <FlowEvent, List<FlowAction>>{
      for (final ev in FlowEvent.values)
        ev: [
          for (final x in FlowAction.values)
            if (ev == e && x == a ? on : flow.actionsFor(ev).contains(x)) x,
        ],
    }..removeWhere((_, v) => v.isEmpty);
    onChanged(FlowConfig(paymentMode: flow.paymentMode, rules: rules));
  }

  @override
  Widget build(BuildContext context) {
    final current = canonicalFlow(flow);
    final activePreset = presets.entries
        .where((p) => canonicalFlow(p.value) == current)
        .map((p) => p.key)
        .firstOrNull;
    return SectionCard(
      icon: Icons.alt_route_rounded,
      title: 'Flusso ordine',
      subtitle:
          'Come paga il cliente e cosa succede a ogni passaggio. Parti da un '
          'modello e personalizzalo.',
      trailing: Pill(
        activePreset == null
            ? 'Personalizzato'
            : presetInfo[activePreset]?.$1 ?? activePreset,
        color: activePreset == null ? S.info : S.success,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Modelli pronti', style: ST.h3),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, box) {
              final cols = box.maxWidth > 900 ? 4 : 2;
              final w = (box.maxWidth - 12 * (cols - 1)) / cols;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final p in presets.entries)
                    SizedBox(
                      width: w,
                      child: _PresetCard(
                        name: p.key,
                        selected: p.key == activePreset,
                        onTap: () => onChanged(p.value),
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),
          SettingRow(
            label: 'Pagamento',
            help: 'Dove paga il cliente',
            child: SegmentedButton<PaymentMode>(
              key: const ValueKey('payment-mode'),
              showSelectedIcon: false,
              segments: [
                for (final m in PaymentMode.values)
                  ButtonSegment(value: m, label: Text(paymentModeLabel(m))),
              ],
              selected: {flow.paymentMode},
              onSelectionChanged: (v) => onChanged(
                FlowConfig(paymentMode: v.first, rules: flow.rules),
              ),
            ),
          ),
          if (flow.canPayOnKiosk)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Se il POS rifiuta, permetti di pagare in cassa',
                style: ST.h3,
              ),
              subtitle: const Text(
                'Il cliente non resta bloccato: l\'ordine passa in cassa.',
                style: ST.small,
              ),
              value: counterFallback,
              onChanged: onCounterFallback,
            ),
          const SizedBox(height: 16),
          const Text('Ciclo dell\'ordine', style: ST.h3),
          const SizedBox(height: 10),
          _Cycle(flow: flow),
          const SizedBox(height: 24),
          const Text('Azioni per ogni passaggio', style: ST.h3),
          const SizedBox(height: 8),
          _Matrix(flow: flow, onToggle: _toggle),
          const SizedBox(height: 16),
          _Issues(issues: issues, validating: validating),
        ],
      ),
    );
  }
}

class _PresetCard extends StatelessWidget {
  final String name;
  final bool selected;
  final VoidCallback onTap;
  const _PresetCard({
    required this.name,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final (title, text, icon) =
        presetInfo[name] ?? (name, '', Icons.tune_rounded);
    return Material(
      color: selected ? S.primary.withValues(alpha: 0.07) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: selected ? S.primary : S.line,
          width: selected ? 2 : 1.5,
        ),
      ),
      child: InkWell(
        key: ValueKey('preset-$name'),
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: selected ? S.primary : S.inkSoft),
                  const Spacer(),
                  if (selected)
                    Icon(
                      Icons.check_circle_rounded,
                      color: S.primary,
                      size: 20,
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(title, style: ST.h3),
              const SizedBox(height: 2),
              Text(
                text,
                style: ST.small,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The three moments of an order, with the actions attached to each.
class _Cycle extends StatelessWidget {
  final FlowConfig flow;
  const _Cycle({required this.flow});

  @override
  Widget build(BuildContext context) {
    final steps = [
      (FlowEvent.submitted, Icons.touch_app_rounded, true),
      (
        FlowEvent.paid,
        Icons.payments_rounded,
        flow.paymentMode != PaymentMode.none,
      ),
      (FlowEvent.ready, Icons.notifications_active_rounded, true),
    ];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (i, (event, icon, active)) in steps.indexed) ...[
          if (i > 0)
            const Padding(
              padding: EdgeInsets.only(top: 26),
              child: Icon(Icons.arrow_forward_rounded, color: S.muted),
            ),
          Expanded(
            child: AnimatedOpacity(
              duration: S.medium,
              opacity: active ? 1 : 0.4,
              child: Container(
                padding: const EdgeInsets.all(14),
                margin: const EdgeInsets.symmetric(horizontal: 6),
                decoration: BoxDecoration(
                  color: S.background,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: S.primary,
                          child: Icon(icon, color: Colors.white, size: 18),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(flowEventLabel(event), style: ST.h3),
                        ),
                      ],
                    ),
                    if (event == FlowEvent.paid)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          active
                              ? paymentModeLabel(flow.paymentMode)
                              : 'Pagamento non gestito',
                          style: ST.small,
                        ),
                      ),
                    const SizedBox(height: 10),
                    if (flow.actionsFor(event).isEmpty)
                      const Text('Nessuna azione', style: ST.small)
                    else
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final a in flow.actionsFor(event))
                            Pill(
                              flowActionLabel(a),
                              color: S.ink,
                            ).animate().fadeIn(duration: 200.ms),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _Matrix extends StatelessWidget {
  final FlowConfig flow;
  final void Function(FlowEvent, FlowAction, bool) onToggle;
  const _Matrix({required this.flow, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Table(
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        defaultColumnWidth: const FixedColumnWidth(130),
        columnWidths: const {0: FixedColumnWidth(190)},
        children: [
          TableRow(
            children: [
              const SizedBox(),
              for (final a in FlowAction.values)
                Padding(
                  padding: const EdgeInsets.all(6),
                  child: Text(
                    flowActionLabel(a),
                    textAlign: TextAlign.center,
                    style: ST.small.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
            ],
          ),
          for (final e in FlowEvent.values)
            TableRow(
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: S.line)),
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(flowEventLabel(e), style: ST.h3),
                ),
                for (final a in FlowAction.values)
                  Center(
                    child: Checkbox(
                      key: ValueKey('rule-${e.name}-${a.name}'),
                      value: flow.actionsFor(e).contains(a),
                      onChanged: (v) => onToggle(e, a, v ?? false),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _Issues extends StatelessWidget {
  final List<FlowIssue> issues;
  final bool validating;
  const _Issues({required this.issues, required this.validating});

  @override
  Widget build(BuildContext context) {
    if (issues.isEmpty) {
      return Row(
        children: [
          Icon(
            validating ? Icons.hourglass_top_rounded : Icons.verified_rounded,
            color: validating ? S.muted : S.success,
          ),
          const SizedBox(width: 8),
          Text(
            validating ? 'Verifica in corso…' : 'Il flusso è valido.',
            style: ST.body.copyWith(
              color: validating ? S.muted : S.success,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final i in issues)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _color(i.level).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(_icon(i.level), color: _color(i.level)),
                const SizedBox(width: 10),
                Expanded(child: Text(flowIssueText(i), style: ST.body)),
                Pill(_levelLabel(i.level), color: _color(i.level)),
              ],
            ),
          ),
      ],
    );
  }

  static Color _color(FlowIssueLevel l) => switch (l) {
    FlowIssueLevel.error => S.primary,
    FlowIssueLevel.warning => S.warning,
    FlowIssueLevel.info => S.info,
  };

  static IconData _icon(FlowIssueLevel l) => switch (l) {
    FlowIssueLevel.error => Icons.error_rounded,
    FlowIssueLevel.warning => Icons.warning_amber_rounded,
    FlowIssueLevel.info => Icons.info_outline_rounded,
  };

  static String _levelLabel(FlowIssueLevel l) => switch (l) {
    FlowIssueLevel.error => 'Blocca il salvataggio',
    FlowIssueLevel.warning => 'Attenzione',
    FlowIssueLevel.info => 'Nota',
  };
}
