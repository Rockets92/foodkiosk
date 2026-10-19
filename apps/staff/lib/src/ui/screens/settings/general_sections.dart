import 'package:flutter/material.dart';
import 'package:kiosk_core/kiosk_core.dart';

import '../../theme.dart';
import '../../widgets/common.dart';
import 'fields.dart';

/// Shared by every section: the draft settings as JSON plus a setter.
typedef DraftSetter = void Function(String key, Object? value);

const languageNames = {'it': 'Italiano', 'en': 'English'};

class DemoSection extends StatelessWidget {
  final bool demo;
  final ValueChanged<bool> onChanged;
  const DemoSection({super.key, required this.demo, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final color = demo ? S.warning : S.success;
    return AnimatedContainer(
      duration: S.medium,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: demo
              ? const [Color(0xFFFFF4D6), Color(0xFFFFE7A8)]
              : const [Color(0xFFE3F6EC), Color(0xFFCFF0DE)],
        ),
        borderRadius: BorderRadius.circular(S.radius),
        boxShadow: S.shadow,
      ),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              demo ? Icons.science_rounded : Icons.storefront_rounded,
              color: color,
              size: 34,
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('Modalità demo', style: ST.h2),
                    const SizedBox(width: 10),
                    Pill(
                      demo ? 'ATTIVA' : 'IN PRODUZIONE',
                      color: demo ? const Color(0xFFB36B00) : S.success,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  demo
                      ? 'Pagamenti e documenti fiscali sono simulati, le '
                            'scorte vengono ignorate e gli ordini sono '
                            'segnati come demo. Ideale per provare il totem '
                            'senza POS né registratore.'
                      : 'I pagamenti passano dal POS configurato e i '
                            'documenti fiscali dal registratore telematico. '
                            'Le scorte vengono controllate se attive.',
                  style: ST.body.copyWith(color: S.inkSoft),
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          Transform.scale(
            scale: 1.3,
            child: Switch(
              key: const ValueKey('demo-switch'),
              value: demo,
              onChanged: onChanged,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }
}

class GeneralSection extends StatelessWidget {
  final KioskSettings s;
  final DraftSetter set;
  const GeneralSection({super.key, required this.s, required this.set});

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      icon: Icons.storefront_rounded,
      title: 'Generale',
      subtitle: 'Nome del locale, lingue, servizio e comportamento del totem',
      child: Column(
        children: [
          SettingRow(
            label: 'Nome del locale',
            help: 'Compare sul totem e sugli scontrini',
            child: SyncedTextField(
              key: const ValueKey('venue-name'),
              value: s.venueName,
              width: 360,
              onChanged: (v) => set('venueName', v),
            ),
          ),
          SettingRow(
            label: 'Simbolo valuta',
            child: SyncedTextField(
              value: s.currencySymbol,
              width: 100,
              onChanged: (v) => set('currencySymbol', v),
            ),
          ),
          SettingRow(
            label: 'Lingue del totem',
            help: 'Il cliente può cambiarle in qualsiasi momento',
            child: Wrap(
              spacing: 10,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                for (final e in languageNames.entries)
                  FilterChip(
                    key: ValueKey('lang-${e.key}'),
                    label: Text(e.value),
                    selected: s.languages.contains(e.key),
                    onSelected: (on) {
                      final langs = [
                        for (final l in languageNames.keys)
                          if (l == e.key ? on : s.languages.contains(l)) l,
                      ];
                      set('languages', langs);
                      if (!langs.contains(s.defaultLanguage) &&
                          langs.isNotEmpty) {
                        set('defaultLanguage', langs.first);
                      }
                    },
                  ),
                const SizedBox(width: 12),
                const Text('Predefinita:', style: ST.small),
                DropdownButton<String>(
                  value: s.languages.contains(s.defaultLanguage)
                      ? s.defaultLanguage
                      : null,
                  items: [
                    for (final l in s.languages)
                      DropdownMenuItem(
                        value: l,
                        child: Text(languageNames[l] ?? l),
                      ),
                  ],
                  onChanged: (v) => set('defaultLanguage', v),
                ),
              ],
            ),
          ),
          SettingRow(
            label: 'Modalità di servizio',
            help: 'Con una sola modalità il totem salta la domanda',
            child: Wrap(
              spacing: 10,
              children: [
                for (final m in ServiceMode.values)
                  FilterChip(
                    key: ValueKey('service-${m.name}'),
                    avatar: Icon(serviceModeIcon(m), size: 18),
                    label: Text(serviceModeLabel(m)),
                    selected: s.serviceModes.contains(m),
                    onSelected: (on) => set('serviceModes', [
                      for (final x in ServiceMode.values)
                        if (x == m ? on : s.serviceModes.contains(x)) x.name,
                    ]),
                  ),
              ],
            ),
          ),
          SettingRow(
            label: 'Reset per inattività',
            help: 'Dopo quanti secondi senza tocchi il totem ricomincia',
            child: SyncedTextField(
              value: '${s.idleTimeoutSeconds}',
              numeric: true,
              width: 140,
              suffix: 'sec',
              onChanged: (v) => set('idleTimeoutSeconds', int.tryParse(v)),
            ),
          ),
          SettingRow(
            label: 'Quantità massima per riga',
            child: SyncedTextField(
              value: '${s.maxQuantityPerLine}',
              numeric: true,
              width: 140,
              onChanged: (v) => set('maxQuantityPerLine', int.tryParse(v)),
            ),
          ),
          const Divider(height: 28),
          _Toggle(
            title: 'Mostra allergeni',
            subtitle: 'Icone e dettagli allergeni sulle schede prodotto',
            value: s.showAllergens,
            onChanged: (v) => set('showAllergens', v),
          ),
          _Toggle(
            title: 'Mostra calorie',
            value: s.showCalories,
            onChanged: (v) => set('showCalories', v),
          ),
          _Toggle(
            title: 'Gestione scorte',
            subtitle:
                'Scala le quantità e segna esauriti i prodotti finiti '
                '(ignorata in modalità demo)',
            value: s.stockTracking,
            onChanged: (v) => set('stockTracking', v),
          ),
        ],
      ),
    );
  }
}

class _Toggle extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _Toggle({
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => SwitchListTile(
    contentPadding: EdgeInsets.zero,
    title: Text(title, style: ST.h3),
    subtitle: subtitle == null ? null : Text(subtitle!, style: ST.small),
    value: value,
    onChanged: onChanged,
  );
}

class SecuritySection extends StatelessWidget {
  final String newPin;
  final String confirmPin;
  final ValueChanged<String> onNewPin;
  final ValueChanged<String> onConfirmPin;

  const SecuritySection({
    super.key,
    required this.newPin,
    required this.confirmPin,
    required this.onNewPin,
    required this.onConfirmPin,
  });

  /// Null when the fields are empty or valid.
  static String? error(String pin, String confirm) {
    if (pin.isEmpty && confirm.isEmpty) return null;
    if (pin.length < 4) return 'Il PIN deve avere almeno 4 cifre';
    if (pin != confirm) return 'I due PIN non coincidono';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final err = error(newPin, confirmPin);
    return SectionCard(
      icon: Icons.lock_rounded,
      title: 'Sicurezza',
      subtitle: 'PIN per l\'area staff e il menu nascosto del totem',
      accent: S.ink,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 16,
            runSpacing: 12,
            children: [
              SyncedTextField(
                key: const ValueKey('new-pin'),
                label: 'Nuovo PIN',
                value: newPin,
                numeric: true,
                obscure: true,
                width: 220,
                onChanged: onNewPin,
              ),
              SyncedTextField(
                key: const ValueKey('confirm-pin'),
                label: 'Ripeti il PIN',
                value: confirmPin,
                numeric: true,
                obscure: true,
                width: 220,
                onChanged: onConfirmPin,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            err ??
                'Lascia vuoto per mantenere il PIN attuale. Dopo il '
                    'cambio dovrai accedere di nuovo.',
            style: ST.small.copyWith(color: err == null ? S.inkSoft : S.red),
          ),
        ],
      ),
    );
  }
}
