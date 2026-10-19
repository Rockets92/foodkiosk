import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kiosk_core/kiosk_core.dart';

import '../../../session.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import 'form_helpers.dart';

/// Groups of options (sizes, sides, extras, removals) used by products.
class ModifiersTab extends StatelessWidget {
  const ModifiersTab({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.staff;
    final menu = session.menu;
    if (menu.modifierGroups.isEmpty) {
      return EmptyState(
        icon: Icons.tune_rounded,
        title: 'Nessun gruppo di varianti',
        message:
            'Formati, contorni e aggiunte si creano qui e si collegano '
            'ai prodotti.',
        action: FilledButton.icon(
          onPressed: () => editModifierGroup(context),
          icon: const Icon(Icons.add_rounded),
          label: const Text('Nuovo gruppo'),
        ),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(28, 8, 28, 28),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 460,
        mainAxisExtent: 210,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: menu.modifierGroups.length,
      itemBuilder: (context, i) {
        final g = menu.modifierGroups[i];
        final usedBy = menu.products
            .where((p) => p.modifierGroupIds.contains(g.id))
            .length;
        return Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(S.radius),
          child: InkWell(
            key: ValueKey('group-${g.id}'),
            borderRadius: BorderRadius.circular(S.radius),
            onTap: () => editModifierGroup(context, group: g),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(S.radius),
                boxShadow: S.shadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          g.name.resolve('it'),
                          style: ST.h2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Pill(
                        g.required ? 'Obbligatorio' : 'Facoltativo',
                        color: g.required ? S.red : S.info,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_selectionText(g)} · usato da $usedBy prodotti',
                    style: ST.small,
                  ),
                  const Spacer(),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final o in g.options.take(6))
                        Chip(
                          visualDensity: VisualDensity.compact,
                          avatar: o.imageUrl == null
                              ? null
                              : ServerImage(o.imageUrl, size: 22, radius: 6),
                          label: Text(
                            o.priceDeltaCents == 0
                                ? o.name.resolve('it')
                                : '${o.name.resolve('it')} '
                                      '${o.priceDeltaCents > 0 ? '+' : ''}'
                                      '${session.money(o.priceDeltaCents)}',
                            style: TextStyle(
                              color: o.enabled ? S.ink : S.muted,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      if (g.options.length > 6)
                        Chip(
                          visualDensity: VisualDensity.compact,
                          label: Text('+${g.options.length - 6}'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  static String _selectionText(ModifierGroup g) {
    if (g.maxSelect == 1) {
      return g.minSelect >= 1 ? 'Scelta singola' : 'Al massimo una scelta';
    }
    final max = g.maxSelect == 0 ? 'illimitate' : 'max ${g.maxSelect}';
    return g.minSelect > 0
        ? 'Almeno ${g.minSelect}, $max'
        : 'Scelte multiple, $max';
  }
}

Future<void> editModifierGroup(BuildContext context, {ModifierGroup? group}) {
  final session = context.staffRead;
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => StaffScope(
      session: session,
      child: _GroupEditor(group: group),
    ),
  );
}

class _OptionDraft {
  final String id;
  final LocalizedControllers name;
  final TextEditingController price;
  final TextEditingController image;
  bool selectedByDefault;
  bool enabled;
  Set<Allergen> allergens;

  _OptionDraft(ModifierOption? o)
    : id = o?.id ?? '',
      name = LocalizedControllers(o?.name ?? const LocalizedText.empty()),
      price = TextEditingController(
        text: o == null || o.priceDeltaCents == 0
            ? ''
            : euroText(o.priceDeltaCents),
      ),
      image = TextEditingController(text: o?.imageUrl ?? ''),
      selectedByDefault = o?.selectedByDefault ?? false,
      enabled = o?.enabled ?? true,
      allergens = {...?o?.allergens};

  void dispose() {
    name.dispose();
    price.dispose();
    image.dispose();
  }
}

class _GroupEditor extends StatefulWidget {
  final ModifierGroup? group;
  const _GroupEditor({this.group});

  @override
  State<_GroupEditor> createState() => _GroupEditorState();
}

class _GroupEditorState extends State<_GroupEditor> {
  final _form = GlobalKey<FormState>();
  late final ModifierGroup? _g = widget.group;
  late final _name = LocalizedControllers(
    _g?.name ?? const LocalizedText.empty(),
  );
  late final _min = TextEditingController(text: '${_g?.minSelect ?? 0}');
  late final _max = TextEditingController(text: '${_g?.maxSelect ?? 1}');
  late final List<_OptionDraft> _options = [
    for (final o in _g?.options ?? const <ModifierOption>[]) _OptionDraft(o),
  ];
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    if (_options.isEmpty) _options.add(_OptionDraft(null));
  }

  @override
  void dispose() {
    _name.dispose();
    _min.dispose();
    _max.dispose();
    for (final o in _options) {
      o.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final min = int.tryParse(_min.text) ?? 0;
    final max = int.tryParse(_max.text) ?? 1;
    final options = [
      for (final d in _options)
        if (d.name.it.text.trim().isNotEmpty)
          ModifierOption(
            id: d.id.isEmpty ? newId(d.name.it.text) : d.id,
            name: d.name.value,
            imageUrl: d.image.text.trim().isEmpty
                ? null
                : _imagePath(d.image.text.trim()),
            priceDeltaCents: parseEuro(d.price.text, allowNegative: true) ?? 0,
            allergens: [
              for (final a in Allergen.values)
                if (d.allergens.contains(a)) a,
            ],
            enabled: d.enabled,
            selectedByDefault: d.selectedByDefault,
          ),
    ];
    if (options.isEmpty) {
      showMessage(context, 'Aggiungi almeno un\'opzione', error: true);
      return;
    }
    if (max != 0 && min > max) {
      showMessage(
        context,
        'Il minimo non può superare il massimo',
        error: true,
      );
      return;
    }
    final session = context.staffRead;
    final group = ModifierGroup(
      id: _g?.id ?? newId(_name.it.text),
      name: _name.value,
      minSelect: min,
      maxSelect: max,
      options: options,
    );
    setState(() => _busy = true);
    final saved = await guard(
      context,
      () => session.api.saveModifierGroup(group, isNew: _g == null),
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (saved == null) return;
    await session.reloadMenu();
    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    final session = context.staffRead;
    final usedBy = session.menu.products
        .where((p) => p.modifierGroupIds.contains(_g!.id))
        .length;
    if (!await confirm(
      context,
      title: 'Eliminare il gruppo "${_g!.name.resolve('it')}"?',
      message: usedBy == 0
          ? null
          : 'È collegato a $usedBy prodotti, che non lo proporranno più.',
      confirmLabel: 'Elimina',
      destructive: true,
    )) {
      return;
    }
    if (!mounted) return;
    final ok = await guard(context, () async {
      await session.api.deleteModifierGroup(_g.id);
      return true;
    });
    if (ok != true || !mounted) return;
    await session.reloadMenu();
    if (mounted) Navigator.pop(context);
  }

  Future<void> _editAllergens(_OptionDraft d) async {
    var selected = d.allergens;
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text('Allergeni di "${d.name.it.text.trim()}"', style: ST.h2),
          content: SizedBox(
            width: 520,
            child: AllergenPicker(
              selected: selected,
              onChanged: (v) => setLocal(() => selected = v),
            ),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Fatto'),
            ),
          ],
        ),
      ),
    );
    setState(() => d.allergens = selected);
  }

  @override
  Widget build(BuildContext context) {
    final min = int.tryParse(_min.text) ?? 0;
    return EditorDialog(
      title: _g == null ? 'Nuovo gruppo di varianti' : 'Modifica varianti',
      width: 1040,
      body: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 12),
            LocalizedFields(
              label: 'Nome del gruppo',
              controllers: _name,
              requiredIt: true,
              keyPrefix: 'group-name',
            ),
            const FormSection(
              'Regole di scelta',
              hint: 'Minimo 1 = obbligatorio; massimo 0 = senza limite',
            ),
            Row(
              children: [
                SizedBox(
                  width: 160,
                  child: TextFormField(
                    controller: _min,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(labelText: 'Minimo'),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 160,
                  child: TextFormField(
                    controller: _max,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(labelText: 'Massimo'),
                  ),
                ),
                const SizedBox(width: 16),
                Pill(
                  min >= 1 ? 'Obbligatorio' : 'Facoltativo',
                  color: min >= 1 ? S.red : S.info,
                ),
              ],
            ),
            FormSection(
              'Opzioni (${_options.length})',
              hint: 'Trascina per riordinare',
            ),
            ReorderableListView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              onReorderItem: (from, to) => setState(() {
                _options.insert(to, _options.removeAt(from));
              }),
              children: [
                for (var i = 0; i < _options.length; i++)
                  _optionRow(i, _options[i]),
              ],
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                key: const ValueKey('add-option'),
                onPressed: () =>
                    setState(() => _options.add(_OptionDraft(null))),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Aggiungi opzione'),
              ),
            ),
          ],
        ),
      ),
      actions: [
        if (_g != null)
          TextButton.icon(
            style: TextButton.styleFrom(foregroundColor: S.red),
            onPressed: _busy ? null : _delete,
            icon: const Icon(Icons.delete_outline_rounded),
            label: const Text('Elimina'),
          ),
        const Spacer(),
        OutlinedButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('Annulla'),
        ),
        const SizedBox(width: 10),
        FilledButton.icon(
          key: const ValueKey('save-group'),
          onPressed: _busy ? null : _save,
          icon: const Icon(Icons.check_rounded),
          label: const Text('Salva'),
        ),
      ],
    );
  }

  Widget _optionRow(int i, _OptionDraft d) {
    return Container(
      key: ObjectKey(d),
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(4, 8, 8, 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFAF8F4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: S.line),
      ),
      child: Row(
        children: [
          ReorderableDragStartListener(
            index: i,
            child: const Padding(
              padding: EdgeInsets.all(6),
              child: Icon(Icons.drag_indicator_rounded, color: S.muted),
            ),
          ),
          ValueListenableBuilder(
            valueListenable: d.image,
            builder: (_, v, _) => ServerImage(
              v.text.trim().isEmpty ? null : _imagePath(v.text.trim()),
              size: 44,
              radius: 10,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 5,
            child: TextFormField(
              controller: d.name.it,
              decoration: const InputDecoration(
                labelText: 'Nome (IT)',
                isDense: true,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 4,
            child: TextFormField(
              controller: d.name.en,
              decoration: const InputDecoration(
                labelText: 'Nome (EN)',
                isDense: true,
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 110,
            child: TextFormField(
              controller: d.price,
              decoration: const InputDecoration(
                labelText: 'Prezzo +/-',
                suffixText: '€',
                isDense: true,
              ),
              validator: (v) =>
                  (v ?? '').trim().isEmpty ||
                      parseEuro(v!, allowNegative: true) != null
                  ? null
                  : 'Non valido',
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: TextFormField(
              controller: d.image,
              decoration: const InputDecoration(
                labelText: 'Immagine',
                hintText: 'URL o nome illustrazione',
                isDense: true,
              ),
            ),
          ),
          const SizedBox(width: 4),
          Tooltip(
            message: 'Allergeni',
            child: TextButton(
              onPressed: () => _editAllergens(d),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    size: 18,
                    color: d.allergens.isEmpty ? S.muted : S.warning,
                  ),
                  Text(' ${d.allergens.length}'),
                ],
              ),
            ),
          ),
          Tooltip(
            message: 'Selezionata di default',
            child: Checkbox(
              value: d.selectedByDefault,
              onChanged: (v) =>
                  setState(() => d.selectedByDefault = v ?? false),
            ),
          ),
          Tooltip(
            message: d.enabled ? 'Attiva' : 'Disattivata',
            child: Switch(
              value: d.enabled,
              onChanged: (v) => setState(() => d.enabled = v),
            ),
          ),
          IconButton(
            tooltip: 'Rimuovi',
            onPressed: () => setState(() {
              _options.removeAt(i);
              WidgetsBinding.instance.addPostFrameCallback((_) => d.dispose());
            }),
            icon: const Icon(Icons.close_rounded, size: 20),
          ),
        ],
      ),
    );
  }

  /// A bare illustration name ("bacon") maps to the server's placeholder.
  static String _imagePath(String v) =>
      v.contains('/') ? v : '/media/placeholder/$v.svg';
}
