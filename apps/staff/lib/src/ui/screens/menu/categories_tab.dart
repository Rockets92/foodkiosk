import 'package:flutter/material.dart';
import 'package:kiosk_core/kiosk_core.dart';

import '../../../session.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import 'form_helpers.dart';

/// Categories in kiosk order; drag to reorder.
class CategoriesTab extends StatefulWidget {
  const CategoriesTab({super.key});

  @override
  State<CategoriesTab> createState() => _CategoriesTabState();
}

class _CategoriesTabState extends State<CategoriesTab> {
  /// Order shown while a reorder is being saved.
  List<Category>? _pending;

  Future<void> _reorder(List<Category> list, int from, int to) async {
    final session = context.staffRead;
    final next = [...list];
    next.insert(to, next.removeAt(from));
    setState(() => _pending = next);
    for (var i = 0; i < next.length; i++) {
      final c = next[i];
      if (c.sortOrder == i * 10) continue;
      final ok = await guard(
        context,
        () => session.api.saveCategory(c.copyWith(sortOrder: i * 10)),
      );
      if (ok == null) break;
    }
    await session.reloadMenu();
    if (mounted) setState(() => _pending = null);
  }

  Future<void> _toggle(Category c, bool enabled) async {
    final session = context.staffRead;
    final ok = await guard(
      context,
      () => session.api.saveCategory(c.copyWith(enabled: enabled)),
    );
    if (ok != null) await session.reloadMenu();
  }

  @override
  Widget build(BuildContext context) {
    final menu = context.staff.menu;
    final list = _pending ?? menu.categories;
    if (list.isEmpty) {
      return EmptyState(
        icon: Icons.category_outlined,
        title: 'Nessuna categoria',
        message: 'Crea la prima categoria per iniziare a comporre il menu.',
        action: FilledButton.icon(
          onPressed: () => editCategory(context),
          icon: const Icon(Icons.add_rounded),
          label: const Text('Nuova categoria'),
        ),
      );
    }
    return Align(
      alignment: Alignment.topLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 980),
        child: ReorderableListView.builder(
          padding: const EdgeInsets.fromLTRB(28, 8, 28, 28),
          buildDefaultDragHandles: false,
          itemCount: list.length,
          onReorderItem: (from, to) => _reorder(list, from, to),
          itemBuilder: (context, i) {
            final c = list[i];
            final count = menu.productsIn(c.id).length;
            return Padding(
              key: ValueKey('category-${c.id}'),
              padding: const EdgeInsets.only(bottom: 10),
              child: Panel(
                padding: const EdgeInsets.fromLTRB(8, 10, 16, 10),
                child: Row(
                  children: [
                    ReorderableDragStartListener(
                      index: i,
                      child: const Padding(
                        padding: EdgeInsets.all(8),
                        child: Icon(
                          Icons.drag_indicator_rounded,
                          color: S.muted,
                        ),
                      ),
                    ),
                    ServerImage(
                      c.imageUrl ?? menu.productsIn(c.id).firstOrNull?.imageUrl,
                      size: 52,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            c.name.resolve('it'),
                            style: ST.h3.copyWith(
                              color: c.enabled ? S.ink : S.muted,
                            ),
                          ),
                          Text(
                            [
                              ?c.name.values['en'],
                              '$count prodotti',
                              if (c.serviceModes.length == 1)
                                'solo ${serviceModeLabel(c.serviceModes.first).toLowerCase()}',
                            ].join(' · '),
                            style: ST.small,
                          ),
                        ],
                      ),
                    ),
                    Text(c.enabled ? 'Visibile' : 'Nascosta', style: ST.small),
                    Switch(value: c.enabled, onChanged: (v) => _toggle(c, v)),
                    const SizedBox(width: 4),
                    IconButton(
                      key: ValueKey('edit-category-${c.id}'),
                      tooltip: 'Modifica',
                      onPressed: () => editCategory(context, category: c),
                      icon: const Icon(Icons.edit_outlined),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

Future<void> editCategory(BuildContext context, {Category? category}) {
  final session = context.staffRead;
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => StaffScope(
      session: session,
      child: _CategoryEditor(category: category),
    ),
  );
}

class _CategoryEditor extends StatefulWidget {
  final Category? category;
  const _CategoryEditor({this.category});

  @override
  State<_CategoryEditor> createState() => _CategoryEditorState();
}

class _CategoryEditorState extends State<_CategoryEditor> {
  final _form = GlobalKey<FormState>();
  late final Category? _c = widget.category;
  late final _name = LocalizedControllers(
    _c?.name ?? const LocalizedText.empty(),
  );
  late final _description = LocalizedControllers(
    _c?.description ?? const LocalizedText.empty(),
  );
  late bool _enabled = _c?.enabled ?? true;
  late Set<ServiceMode> _modes = _c == null || _c.serviceModes.isEmpty
      ? ServiceMode.values.toSet()
      : {..._c.serviceModes};
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    if (_modes.isEmpty) {
      showMessage(context, 'Scegli almeno una modalità', error: true);
      return;
    }
    final session = context.staffRead;
    final menu = session.menu;
    final category = Category(
      id: _c?.id ?? newId(_name.it.text),
      name: _name.value,
      description: _description.value,
      imageUrl: _c?.imageUrl,
      sortOrder:
          _c?.sortOrder ??
          (menu.categories.isEmpty
              ? 0
              : menu.categories
                        .map((c) => c.sortOrder)
                        .reduce((a, b) => a > b ? a : b) +
                    10),
      enabled: _enabled,
      // All modes selected is stored as "no restriction".
      serviceModes: _modes.length == ServiceMode.values.length ? {} : _modes,
    );
    setState(() => _busy = true);
    final saved = await guard(
      context,
      () => session.api.saveCategory(category, isNew: _c == null),
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (saved == null) return;
    await session.reloadMenu();
    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    final session = context.staffRead;
    if (!await confirm(
      context,
      title: 'Eliminare la categoria "${_c!.name.resolve('it')}"?',
      message: 'Si possono eliminare solo le categorie senza prodotti.',
      confirmLabel: 'Elimina',
      destructive: true,
    )) {
      return;
    }
    if (!mounted) return;
    final ok = await guard(context, () async {
      await session.api.deleteCategory(_c.id);
      return true;
    });
    if (ok != true || !mounted) return;
    await session.reloadMenu();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return EditorDialog(
      title: _c == null ? 'Nuova categoria' : 'Modifica categoria',
      width: 720,
      body: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 12),
            LocalizedFields(
              label: 'Nome',
              controllers: _name,
              requiredIt: true,
              keyPrefix: 'category-name',
            ),
            const SizedBox(height: 12),
            LocalizedFields(
              label: 'Descrizione',
              controllers: _description,
              maxLines: 2,
            ),
            const FormSection('Mostra per'),
            Wrap(
              spacing: 8,
              children: [
                for (final m in ServiceMode.values)
                  FilterChip(
                    avatar: Icon(serviceModeIcon(m), size: 18),
                    label: Text(serviceModeLabel(m)),
                    selected: _modes.contains(m),
                    onSelected: (on) => setState(
                      () =>
                          _modes = on ? {..._modes, m} : _modes.difference({m}),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Visibile sul totem'),
              value: _enabled,
              onChanged: (v) => setState(() => _enabled = v),
            ),
          ],
        ),
      ),
      actions: [
        if (_c != null)
          TextButton.icon(
            style: TextButton.styleFrom(foregroundColor: S.primary),
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
          key: const ValueKey('save-category'),
          onPressed: _busy ? null : _save,
          icon: const Icon(Icons.check_rounded),
          label: const Text('Salva'),
        ),
      ],
    );
  }
}
