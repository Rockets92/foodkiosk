import 'dart:math';

import 'package:flutter/material.dart';
import 'package:kiosk_core/kiosk_core.dart';

import '../../theme.dart';

final _random = Random();

/// Id for a new item, from its Italian name (the server keeps ids as sent).
String newId(String name) {
  final base = name
      .toLowerCase()
      .replaceAll(RegExp(r'[àáâä]'), 'a')
      .replaceAll(RegExp(r'[èéêë]'), 'e')
      .replaceAll(RegExp(r'[ìíîï]'), 'i')
      .replaceAll(RegExp(r'[òóôö]'), 'o')
      .replaceAll(RegExp(r'[ùúûü]'), 'u')
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  final suffix = _random.nextInt(0xffff).toRadixString(16).padLeft(4, '0');
  return '${base.isEmpty ? 'item' : base}-$suffix';
}

/// "6,50" / "6.5" / "6" → 650; null when not a valid amount.
Cents? parseEuro(String text, {bool allowNegative = false}) {
  final t = text.trim().replaceAll('€', '').replaceAll(' ', '');
  if (t.isEmpty) return null;
  final m = RegExp(r'^(-?)(\d+)(?:[.,](\d{1,2}))?$').firstMatch(t);
  if (m == null) return null;
  if (m.group(1)!.isNotEmpty && !allowNegative) return null;
  final cents =
      int.parse(m.group(2)!) * 100 +
      int.parse((m.group(3) ?? '0').padRight(2, '0'));
  return m.group(1)!.isEmpty ? cents : -cents;
}

String euroText(Cents cents) {
  final neg = cents < 0;
  final abs = cents.abs();
  return '${neg ? '-' : ''}${abs ~/ 100},${(abs % 100).toString().padLeft(2, '0')}';
}

/// Controllers for a text available in Italian and English.
class LocalizedControllers {
  final TextEditingController it;
  final TextEditingController en;

  LocalizedControllers(LocalizedText text)
    : it = TextEditingController(text: text.values['it'] ?? ''),
      en = TextEditingController(text: text.values['en'] ?? '');

  LocalizedText get value => LocalizedText({
    if (it.text.trim().isNotEmpty) 'it': it.text.trim(),
    if (en.text.trim().isNotEmpty) 'en': en.text.trim(),
  });

  void dispose() {
    it.dispose();
    en.dispose();
  }
}

/// Two side-by-side fields: Italian and English.
class LocalizedFields extends StatelessWidget {
  final String label;
  final LocalizedControllers controllers;
  final bool requiredIt;
  final int maxLines;
  final String? keyPrefix;

  const LocalizedFields({
    super.key,
    required this.label,
    required this.controllers,
    this.requiredIt = false,
    this.maxLines = 1,
    this.keyPrefix,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: TextFormField(
            key: keyPrefix == null ? null : ValueKey('$keyPrefix-it'),
            controller: controllers.it,
            maxLines: maxLines,
            decoration: InputDecoration(
              labelText: '$label (IT)${requiredIt ? ' *' : ''}',
              prefixText: '🇮🇹  ',
            ),
            validator: requiredIt
                ? (v) => (v ?? '').trim().isEmpty ? 'Obbligatorio' : null
                : null,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: TextFormField(
            key: keyPrefix == null ? null : ValueKey('$keyPrefix-en'),
            controller: controllers.en,
            maxLines: maxLines,
            decoration: InputDecoration(
              labelText: '$label (EN)',
              prefixText: '🇬🇧  ',
            ),
          ),
        ),
      ],
    );
  }
}

/// Small section title inside editors.
class FormSection extends StatelessWidget {
  final String title;
  final String? hint;
  const FormSection(this.title, {super.key, this.hint});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 22, bottom: 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(title, style: ST.h3),
        if (hint != null) ...[
          const SizedBox(width: 8),
          Flexible(child: Text(hint!, style: ST.small)),
        ],
      ],
    ),
  );
}

/// Allergen chips with Italian labels.
class AllergenPicker extends StatelessWidget {
  final Set<Allergen> selected;
  final ValueChanged<Set<Allergen>> onChanged;
  final bool dense;
  const AllergenPicker({
    super.key,
    required this.selected,
    required this.onChanged,
    this.dense = false,
  });

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      for (final a in Allergen.values)
        FilterChip(
          visualDensity: dense ? VisualDensity.compact : null,
          label: Text(a.label.resolve('it')),
          selected: selected.contains(a),
          selectedColor: S.warning.withValues(alpha: 0.2),
          onSelected: (on) =>
              onChanged(on ? ({...selected, a}) : (selected.difference({a}))),
        ),
    ],
  );
}

/// Large modal editor frame with a title, scrollable body and actions.
class EditorDialog extends StatelessWidget {
  final String title;
  final Widget body;
  final List<Widget> actions;
  final double width;
  const EditorDialog({
    super.key,
    required this.title,
    required this.body,
    required this.actions,
    this.width = 860,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: width,
          maxHeight: size.height - 48,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 22, 12, 8),
              child: Row(
                children: [
                  Expanded(child: Text(title, style: ST.h2)),
                  IconButton(
                    tooltip: 'Chiudi',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(28, 8, 28, 24),
                child: body,
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
              child: Row(children: actions),
            ),
          ],
        ),
      ),
    );
  }
}
