import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:kiosk_core/kiosk_core.dart';

import '../../api.dart';
import '../../session.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'settings/devices_section.dart';
import 'settings/discounts_section.dart';
import 'settings/flow_section.dart';
import 'settings/general_sections.dart';
import 'settings/network_section.dart';

/// Venue settings: demo mode, kiosk behaviour, order flow, devices,
/// network, PIN.
/// Edits a local draft; nothing reaches the server until "Salva".
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

enum _Part {
  demo('Modalità demo', Icons.science_rounded),
  general('Generale', Icons.storefront_rounded),
  flow('Flusso ordine', Icons.alt_route_rounded),
  discounts('Codici sconto', Icons.local_offer_rounded),
  devices('Dispositivi', Icons.devices_other_rounded),
  network('Rete', Icons.lan_rounded),
  security('Sicurezza', Icons.lock_rounded);

  final String label;
  final IconData icon;
  const _Part(this.label, this.icon);
}

class _SettingsScreenState extends State<SettingsScreen> {
  /// Settings as last loaded from / saved to the server.
  String _original = '';
  Map<String, Object?> _draft = {};
  String _newPin = '';
  String _confirmPin = '';
  bool _saving = false;

  Map<String, FlowConfig> _presets = FlowConfig.presets;
  Map<String, List<String>> _adapters = const {
    'payment': ['none', 'demo'],
    'fiscal': ['none', 'demo'],
    'printer': ['none', 'demo'],
  };
  List<FlowIssue> _issues = [];
  bool _validating = false;
  Timer? _debounce;
  String _validated = '';

  final _keys = {for (final p in _Part.values) p: GlobalKey()};
  bool _loaded = false;

  KioskSettings get _s => KioskSettings.fromJson(_draft);
  bool get _dirty =>
      jsonEncode(_draft) != _original ||
      _newPin.isNotEmpty ||
      _confirmPin.isNotEmpty;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final session = context.staff;
    final server = jsonEncode(session.settings.toJson());
    if (!_loaded) {
      _loaded = true;
      _reset(session.settings);
      _loadMeta(session.api);
    } else if (server != _original && !_dirty) {
      // Changed elsewhere (another admin): follow it while not editing.
      _reset(session.settings);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _reset(KioskSettings s) {
    _original = jsonEncode(s.toJson());
    _draft = (jsonDecode(_original) as Map).cast();
    _newPin = '';
    _confirmPin = '';
    _scheduleValidation();
  }

  Future<void> _loadMeta(StaffApi api) async {
    try {
      final presets = await api.flowPresets();
      final adapters = await api.adapters();
      if (!mounted) return;
      setState(() {
        if (presets.isNotEmpty) _presets = presets;
        _adapters = adapters;
      });
    } on ApiError {
      // Keep the built-in lists.
    }
  }

  void _set(String key, Object? value) => setState(() {
    if (value == null) {
      _draft.remove(key);
    } else {
      _draft[key] = value;
    }
    if (key == 'flow') _scheduleValidation();
  });

  void _scheduleValidation() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), _validate);
  }

  Future<void> _validate() async {
    final flow = _s.flow;
    final key = jsonEncode(flow.toJson());
    if (key == _validated) return;
    if (mounted) setState(() => _validating = true);
    List<FlowIssue> issues;
    try {
      issues = await context.staffRead.api.validateFlow(flow);
    } on ApiError {
      issues = flow.validate();
    }
    if (!mounted) return;
    setState(() {
      _validated = key;
      _issues = issues;
      _validating = false;
    });
  }

  Future<void> _toggleDemo(bool on) async {
    if (!on) {
      final ok = await confirm(
        context,
        title: 'Passare in produzione?',
        message:
            'I pagamenti useranno il POS e i documenti fiscali il '
            'registratore configurati in "Dispositivi". Verifica che siano '
            'collegati e impostati prima di salvare: senza, il totem non '
            'potrà incassare.',
        confirmLabel: 'Disattiva demo',
      );
      if (!ok) return;
    }
    _set('demoMode', on);
  }

  Future<void> _save() async {
    final pinError = SecuritySection.error(_newPin, _confirmPin);
    if (pinError != null) {
      showMessage(context, pinError, error: true);
      _scrollTo(_Part.security);
      return;
    }
    if (_issues.any((i) => i.level == FlowIssueLevel.error)) {
      showMessage(
        context,
        'Il flusso ordine ha degli errori da correggere',
        error: true,
      );
      _scrollTo(_Part.flow);
      return;
    }
    final changesPin = _newPin.isNotEmpty;
    final session = context.staffRead;
    setState(() => _saving = true);
    final saved = await guard(
      context,
      () => session.api.saveSettings({
        ..._draft,
        if (changesPin) 'adminPin': _newPin,
      }),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (saved == null) return;
    setState(() => _reset(saved));
    if (changesPin) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: const Icon(Icons.lock_reset_rounded, size: 40),
          title: const Text('PIN aggiornato', style: ST.h2),
          content: const Text(
            'Esci e accedi di nuovo con il nuovo PIN. Ricordati di '
            'comunicarlo al personale.',
            style: ST.body,
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Ho capito'),
            ),
          ],
        ),
      );
    } else {
      showMessage(context, 'Impostazioni salvate');
      await session.reloadSettings();
    }
  }

  void _scrollTo(_Part p) {
    final ctx = _keys[p]!.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: S.medium,
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _s;
    final sections = <_Part, Widget>{
      _Part.demo: DemoSection(demo: s.demoMode, onChanged: _toggleDemo),
      _Part.general: GeneralSection(s: s, set: _set),
      _Part.flow: FlowSection(
        flow: s.flow,
        presets: _presets,
        issues: _issues,
        validating: _validating,
        counterFallback: s.counterFallback,
        onChanged: (f) => _set('flow', f.toJson()),
        onCounterFallback: (v) => _set('counterFallback', v),
      ),
      _Part.discounts: DiscountsSection(
        value: s.discounts,
        onChanged: (d) => _set('discounts', d.toJson()),
      ),
      _Part.devices: DevicesSection(
        s: s,
        adapters: _adapters,
        onChanged: (key, c) => _set(key, c.toJson()),
      ),
      _Part.network: NetworkSection(api: context.staff.api),
      _Part.security: SecuritySection(
        newPin: _newPin,
        confirmPin: _confirmPin,
        onNewPin: (v) => setState(() => _newPin = v),
        onConfirmPin: (v) => setState(() => _confirmPin = v),
      ),
    };
    return Scaffold(
      key: const ValueKey('settings'),
      body: Column(
        children: [
          const PageHeader(
            title: 'Impostazioni',
            subtitle:
                'Configura il locale, il ciclo dell\'ordine e i dispositivi',
          ),
          Expanded(
            child: Stack(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SideNav(onSelect: _scrollTo),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(8, 4, 28, 120),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 1100),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                for (final e in sections.entries)
                                  Padding(
                                    key: _keys[e.key],
                                    padding: const EdgeInsets.only(bottom: 20),
                                    child: e.value,
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                _SaveBar(
                  visible: _dirty,
                  saving: _saving,
                  onSave: _save,
                  onDiscard: () => setState(
                    () => _reset(
                      KioskSettings.fromJson(
                        (jsonDecode(_original) as Map).cast(),
                      ),
                    ),
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

class _SideNav extends StatelessWidget {
  final ValueChanged<_Part> onSelect;
  const _SideNav({required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        if (MediaQuery.sizeOf(context).width < 1200) {
          return const SizedBox(width: 20);
        }
        return SizedBox(
          width: 230,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 4, 12, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final p in _Part.values)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: TextButton.icon(
                      style: TextButton.styleFrom(
                        alignment: Alignment.centerLeft,
                        foregroundColor: S.ink,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () => onSelect(p),
                      icon: Icon(p.icon, size: 20, color: S.inkSoft),
                      label: Text(p.label),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SaveBar extends StatelessWidget {
  final bool visible;
  final bool saving;
  final VoidCallback onSave;
  final VoidCallback onDiscard;

  const _SaveBar({
    required this.visible,
    required this.saving,
    required this.onSave,
    required this.onDiscard,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: AnimatedSlide(
        duration: S.medium,
        curve: Curves.easeOutCubic,
        offset: visible ? Offset.zero : const Offset(0, 1.5),
        child: AnimatedOpacity(
          duration: S.medium,
          opacity: visible ? 1 : 0,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 900),
                padding: const EdgeInsets.fromLTRB(24, 14, 14, 14),
                decoration: BoxDecoration(
                  color: S.nav,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x40000000),
                      blurRadius: 30,
                      offset: Offset(0, 10),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.edit_note_rounded, color: S.yellow),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Hai modifiche non salvate',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    TextButton(
                      key: const ValueKey('discard-settings'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white70,
                      ),
                      onPressed: saving || !visible ? null : onDiscard,
                      child: const Text('Annulla modifiche'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      key: const ValueKey('save-settings'),
                      onPressed: saving || !visible ? null : onSave,
                      icon: saving
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.save_rounded),
                      label: const Text('Salva modifiche'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
