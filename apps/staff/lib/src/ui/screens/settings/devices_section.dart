import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:kiosk_core/kiosk_core.dart';

import '../../theme.dart';
import 'fields.dart';

const adapterNames = {
  'none': 'Nessuno',
  'demo': 'Simulato',
  'escposNetwork': 'Stampante termica di rete (ESC/POS)',
  'kiosk': 'Stampante del totem (USB o Windows)',
  'epsonRt': 'Registratore telematico Epson (RT)',
  'adeOnline': 'Documento commerciale online (Agenzia delle Entrate)',
};

/// Options a new adapter type starts with.
const _defaults = <String, Map<String, Object?>>{
  'escposNetwork': {'host': '', 'port': 9100, 'width': 42},
  'kiosk': {'width': 42},
  'epsonRt': {
    'host': '',
    'port': 80,
    'departments': {'10': 1, '22': 2},
  },
};

class DevicesSection extends StatelessWidget {
  final KioskSettings s;
  final Map<String, List<String>> adapters;
  final void Function(String key, AdapterConfig config) onChanged;

  const DevicesSection({
    super.key,
    required this.s,
    required this.adapters,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final devices = [
      (
        'payment',
        'payment',
        'Terminale di pagamento (POS)',
        Icons.contactless_rounded,
        s.payment,
      ),
      (
        'customerPrinter',
        'printer',
        'Stampante scontrini cliente',
        Icons.print_rounded,
        s.customerPrinter,
      ),
      (
        'kitchenPrinter',
        'printer',
        'Stampante cucina',
        Icons.soup_kitchen_rounded,
        s.kitchenPrinter,
      ),
      (
        'counterPrinter',
        'printer',
        'Stampante cassa (documenti degli ordini pagati in cassa)',
        Icons.point_of_sale_rounded,
        s.counterPrinter,
      ),
    ];
    return SectionCard(
      icon: Icons.devices_other_rounded,
      title: 'Dispositivi',
      subtitle:
          'POS e stampanti termiche. Il registratore telematico è nella '
          'sezione Agenzia delle Entrate',
      accent: S.info,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (s.demoMode)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: S.accent.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(Icons.science_rounded, color: Color(0xFFB36B00)),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'In modalità demo pagamento e documento fiscale sono '
                      'sempre simulati, qualunque dispositivo sia scelto qui.',
                      style: ST.body,
                    ),
                  ),
                ],
              ),
            ),
          for (final (key, kind, title, icon, config) in devices)
            DeviceCard(
              key: ValueKey('device-$key'),
              id: key,
              title: title,
              icon: icon,
              types: {
                ...?adapters[kind]?.where(
                  // Only the customer's ticket can come out of the totem.
                  (t) => t != 'kiosk' || key == 'customerPrinter',
                ),
                config.type,
              }.toList(),
              config: config,
              onChanged: (c) => onChanged(key, c),
            ),
        ],
      ),
    );
  }
}

/// One pluggable device: its type and the options of that type.
class DeviceCard extends StatelessWidget {
  final String id;
  final String title;
  final IconData icon;
  final List<String> types;
  final AdapterConfig config;
  final ValueChanged<AdapterConfig> onChanged;

  /// Without it the type is chosen elsewhere and only the options show.
  final bool typePicker;

  const DeviceCard({
    super.key,
    required this.id,
    required this.title,
    required this.icon,
    required this.types,
    required this.config,
    required this.onChanged,
    this.typePicker = true,
  });

  void _set(String option, Object? value) {
    final options = {...config.options};
    if (value == null) {
      options.remove(option);
    } else {
      options[option] = value;
    }
    onChanged(AdapterConfig(config.type, options));
  }

  @override
  Widget build(BuildContext context) {
    final o = config.options;
    String str(String k) => o[k] == null ? '' : '${o[k]}';
    Widget number(
      String k,
      String label, {
      double width = 140,
      bool dec = false,
    }) => SyncedTextField(
      label: label,
      value: str(k),
      numeric: true,
      decimal: dec,
      width: width,
      onChanged: (v) => _set(k, dec ? double.tryParse(v) : int.tryParse(v)),
    );
    Widget host() => SyncedTextField(
      key: ValueKey('$id-host'),
      label: 'Indirizzo IP',
      hint: '192.168.1.50',
      value: str('host'),
      width: 220,
      onChanged: (v) => _set('host', v.trim()),
    );

    final fields = <Widget>[
      if (config.type == 'escposNetwork') ...[
        host(),
        number('port', 'Porta'),
        SizedBox(
          width: 200,
          child: DropdownButtonHideUnderline(
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Larghezza carta',
                isDense: true,
              ),
              child: DropdownButton<int>(
                isDense: true,
                isExpanded: true,
                value: (o['width'] as num?)?.toInt() == 48 ? 48 : 42,
                items: const [
                  DropdownMenuItem(value: 42, child: Text('42 colonne')),
                  DropdownMenuItem(value: 48, child: Text('48 colonne')),
                ],
                onChanged: (v) => _set('width', v),
              ),
            ),
          ),
        ),
      ],
      if (config.type == 'kiosk') ...[
        SizedBox(
          width: 200,
          child: DropdownButtonHideUnderline(
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Larghezza carta',
                isDense: true,
              ),
              child: DropdownButton<int>(
                key: ValueKey('$id-width'),
                isDense: true,
                isExpanded: true,
                value: switch ((o['width'] as num?)?.toInt()) {
                  32 => 32,
                  48 => 48,
                  _ => 42,
                },
                items: const [
                  DropdownMenuItem(value: 32, child: Text('58 mm (32)')),
                  DropdownMenuItem(value: 42, child: Text('80 mm (42)')),
                  DropdownMenuItem(value: 48, child: Text('80 mm (48)')),
                ],
                onChanged: (v) => _set('width', v),
              ),
            ),
          ),
        ),
        const SizedBox(
          width: 520,
          child: Text(
            'Ogni totem stampa le ricevute dei suoi ordini sulla stampante '
            'scelta nel suo menu staff (angolo in alto a sinistra → '
            'Stampante ricevute). Le ristampe e gli ordini al banco escono '
            'dalla stampante cassa.',
            style: ST.small,
          ),
        ),
      ],
      if (config.type == 'epsonRt') ...[host(), number('port', 'Porta')],
      if (config.type == 'demo' && id == 'payment') ...[
        number('delayMs', 'Attesa (ms)'),
        number('failureRate', 'Rifiuti casuali (0-1)', dec: true, width: 180),
        SyncedTextField(
          label: 'Rifiuta se i centesimi finiscono con',
          hint: 'es. 13',
          value: str('declineCentsSuffix'),
          numeric: true,
          width: 280,
          onChanged: (v) => _set('declineCentsSuffix', v.isEmpty ? null : v),
        ),
      ],
      if (config.type == 'demo' && id.endsWith('Printer'))
        number('width', 'Colonne'),
    ];

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: S.line, width: 1.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, color: S.inkSoft),
              const SizedBox(width: 10),
              Expanded(child: Text(title, style: ST.h3)),
              if (typePicker)
                SizedBox(
                  width: 340,
                  child: DropdownButtonFormField<String>(
                    key: ValueKey('$id-type:${config.type}'),
                    initialValue: config.type,
                    isExpanded: true,
                    decoration: const InputDecoration(isDense: true),
                    items: [
                      for (final t in types)
                        DropdownMenuItem(
                          value: t,
                          child: Text(
                            adapterNames[t] ?? t,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (t) {
                      if (t == null || t == config.type) return;
                      onChanged(AdapterConfig(t, {...?_defaults[t]}));
                    },
                  ),
                ),
            ],
          ),
          if (fields.isNotEmpty) ...[
            const SizedBox(height: 14),
            Wrap(spacing: 12, runSpacing: 12, children: fields),
          ],
          if (config.type == 'epsonRt') ...[
            const SizedBox(height: 14),
            _Departments(
              departments: {
                for (final e in (o['departments'] as Map? ?? const {}).entries)
                  '${e.key}': (e.value as num?)?.toInt() ?? 1,
              },
              onChanged: (d) => _set('departments', d),
            ),
          ],
          if (config.type != 'none')
            Theme(
              data: Theme.of(context)
                  .copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: const Text('Avanzate (JSON)', style: ST.small),
                children: [
                  _JsonEditor(
                    key: ValueKey(jsonEncode(config.options)),
                    options: config.options,
                    onApply: (opts) =>
                        onChanged(AdapterConfig(config.type, opts)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// VAT rate → RT department, as editable rows.
class _Departments extends StatelessWidget {
  final Map<String, int> departments;
  final ValueChanged<Map<String, int>> onChanged;
  const _Departments({required this.departments, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final rows = departments.entries.toList();
    void update(int index, String vat, int dept) => onChanged({
      for (final (i, e) in rows.indexed)
        if (i == index) vat: dept else e.key: e.value,
    });
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Reparti per aliquota IVA', style: ST.h3),
        const Text(
          'Ogni aliquota va sul reparto configurato nel registratore.',
          style: ST.small,
        ),
        const SizedBox(height: 8),
        for (final (i, e) in rows.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                SyncedTextField(
                  label: 'IVA',
                  suffix: '%',
                  value: e.key,
                  numeric: true,
                  decimal: true,
                  width: 120,
                  onChanged: (v) => update(i, v, e.value),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  child: Icon(Icons.arrow_forward_rounded, color: S.muted),
                ),
                SyncedTextField(
                  label: 'Reparto',
                  value: '${e.value}',
                  numeric: true,
                  width: 120,
                  onChanged: (v) => update(i, e.key, int.tryParse(v) ?? 1),
                ),
                IconButton(
                  tooltip: 'Rimuovi',
                  onPressed: () => onChanged({...departments}..remove(e.key)),
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
              ],
            ),
          ),
        TextButton.icon(
          onPressed: () => onChanged({...departments, '': 1}),
          icon: const Icon(Icons.add_rounded),
          label: const Text('Aggiungi aliquota'),
        ),
      ],
    );
  }
}

class _JsonEditor extends StatefulWidget {
  final Map<String, Object?> options;
  final ValueChanged<Map<String, Object?>> onApply;
  const _JsonEditor({super.key, required this.options, required this.onApply});

  @override
  State<_JsonEditor> createState() => _JsonEditorState();
}

class _JsonEditorState extends State<_JsonEditor> {
  late final _controller = TextEditingController(
    text: const JsonEncoder.withIndent('  ').convert(widget.options),
  );
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _apply() {
    try {
      final decoded = jsonDecode(_controller.text);
      if (decoded is! Map) throw const FormatException();
      widget.onApply(decoded.cast());
    } on FormatException {
      setState(() => _error = 'JSON non valido: serve un oggetto { ... }');
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [
      TextField(
        controller: _controller,
        maxLines: 8,
        minLines: 3,
        style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
        decoration: InputDecoration(errorText: _error),
        onChanged: (_) {
          if (_error != null) setState(() => _error = null);
        },
      ),
      const SizedBox(height: 8),
      OutlinedButton(onPressed: _apply, child: const Text('Applica')),
    ],
  );
}
