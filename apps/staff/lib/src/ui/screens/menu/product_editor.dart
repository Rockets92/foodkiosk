import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kiosk_core/kiosk_core.dart';

import '../../../session.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import 'form_helpers.dart';

/// Opens the product editor; [product] null creates a new one.
Future<void> editProduct(
  BuildContext context, {
  Product? product,
  String? categoryId,
}) {
  final session = context.staffRead;
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => StaffScope(
      session: session,
      child: _ProductEditor(product: product, categoryId: categoryId),
    ),
  );
}

class _ProductEditor extends StatefulWidget {
  final Product? product;
  final String? categoryId;
  const _ProductEditor({this.product, this.categoryId});

  @override
  State<_ProductEditor> createState() => _ProductEditorState();
}

class _ProductEditorState extends State<_ProductEditor> {
  final _form = GlobalKey<FormState>();
  late final Product? _p = widget.product;
  late final _name = LocalizedControllers(
    _p?.name ?? const LocalizedText.empty(),
  );
  late final _description = LocalizedControllers(
    _p?.description ?? const LocalizedText.empty(),
  );
  late final _badge = LocalizedControllers(
    _p?.badge ?? const LocalizedText.empty(),
  );
  late final _price = TextEditingController(
    text: _p == null ? '' : euroText(_p.priceCents),
  );
  late final _kcal = TextEditingController(text: _p?.kcal?.toString() ?? '');
  late final _sort = TextEditingController(text: '${_p?.sortOrder ?? 0}');
  late final _stock = TextEditingController(text: '${_p?.stockQty ?? 0}');
  late String? _imageUrl = _p?.imageUrl;
  late String? _categoryId;
  late double _vat = _p?.vatRate ?? 10;
  late Set<Allergen> _allergens = {...?_p?.allergens};
  late Set<DietaryTag> _tags = {...?_p?.tags};
  late List<String> _groups = [...?_p?.modifierGroupIds];
  late bool _enabled = _p?.enabled ?? true;
  late bool _soldOut = _p?.soldOut ?? false;
  late bool _trackStock = _p?.trackStock ?? false;
  bool _busy = false;
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    final cats = context.staffRead.menu.categories;
    _categoryId =
        _p?.categoryId ??
        widget.categoryId ??
        (cats.isEmpty ? null : cats.first.id);
  }

  @override
  void dispose() {
    for (final c in [_name, _description, _badge]) {
      c.dispose();
    }
    for (final c in [_price, _kcal, _sort, _stock]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickImage() async {
    final api = context.staffRead.api;
    final files = await FilePicker.pickFiles(type: FileType.image);
    final file = files.firstOrNull;
    if (file == null || !mounted) return;
    setState(() => _uploading = true);
    final url = await guard(
      context,
      () async => api.uploadImage(file.name, await file.readAsBytes()),
    );
    if (!mounted) return;
    setState(() {
      _uploading = false;
      if (url != null) _imageUrl = url;
    });
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate() || _categoryId == null) return;
    final session = context.staffRead;
    final product = Product(
      id: _p?.id ?? newId(_name.it.text),
      categoryId: _categoryId!,
      name: _name.value,
      description: _description.value,
      badge: _badge.value,
      imageUrl: _imageUrl,
      priceCents: parseEuro(_price.text)!,
      vatRate: _vat,
      allergens: [
        for (final a in Allergen.values)
          if (_allergens.contains(a)) a,
      ],
      tags: [
        for (final t in DietaryTag.values)
          if (_tags.contains(t)) t,
      ],
      kcal: int.tryParse(_kcal.text.trim()),
      sortOrder: int.tryParse(_sort.text.trim()) ?? 0,
      enabled: _enabled,
      soldOut: _soldOut,
      trackStock: _trackStock,
      stockQty: int.tryParse(_stock.text.trim()) ?? 0,
      modifierGroupIds: _groups,
    );
    setState(() => _busy = true);
    final saved = await guard(
      context,
      () => session.api.saveProduct(product, isNew: _p == null),
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (saved == null) return;
    await session.reloadMenu();
    if (!mounted) return;
    Navigator.pop(context);
    showMessage(context, 'Prodotto salvato');
  }

  Future<void> _delete() async {
    final session = context.staffRead;
    if (!await confirm(
      context,
      title: 'Eliminare "${_p!.name.resolve('it')}"?',
      message: 'Il prodotto sparisce dal menu. Gli ordini passati restano.',
      confirmLabel: 'Elimina',
      destructive: true,
    )) {
      return;
    }
    if (!mounted) return;
    final ok = await guard(context, () async {
      await session.api.deleteProduct(_p.id);
      return true;
    });
    if (ok != true || !mounted) return;
    await session.reloadMenu();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final menu = context.staff.menu;
    final groups = menu.modifierGroups;
    return EditorDialog(
      title: _p == null ? 'Nuovo prodotto' : 'Modifica prodotto',
      width: 920,
      body: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _PhotoBox(
                  imageUrl: _imageUrl,
                  uploading: _uploading,
                  onPick: _pickImage,
                  onRemove: () => setState(() => _imageUrl = null),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    children: [
                      LocalizedFields(
                        label: 'Nome',
                        controllers: _name,
                        requiredIt: true,
                        keyPrefix: 'product-name',
                      ),
                      const SizedBox(height: 12),
                      LocalizedFields(
                        label: 'Descrizione',
                        controllers: _description,
                        maxLines: 3,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const FormSection('Prezzo e categoria'),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: DropdownButtonFormField<String>(
                    initialValue: _categoryId,
                    decoration: const InputDecoration(labelText: 'Categoria *'),
                    items: [
                      for (final c in menu.categories)
                        DropdownMenuItem(
                          value: c.id,
                          child: Text(c.name.resolve('it')),
                        ),
                    ],
                    validator: (v) => v == null ? 'Obbligatoria' : null,
                    onChanged: (v) => setState(() => _categoryId = v),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    key: const ValueKey('product-price'),
                    controller: _price,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Prezzo *',
                      suffixText: '€',
                      hintText: '6,50',
                    ),
                    validator: (v) =>
                        parseEuro(v ?? '') == null ? 'Prezzo non valido' : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<double>(
                    initialValue: [4.0, 5.0, 10.0, 22.0].contains(_vat)
                        ? _vat
                        : 10.0,
                    decoration: const InputDecoration(labelText: 'IVA'),
                    items: [
                      for (final v in [4.0, 5.0, 10.0, 22.0])
                        DropdownMenuItem(
                          value: v,
                          child: Text('${v.toInt()}%'),
                        ),
                    ],
                    onChanged: (v) => setState(() => _vat = v ?? 10),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _kcal,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: 'Calorie',
                      suffixText: 'kcal',
                    ),
                  ),
                ),
              ],
            ),
            const FormSection(
              'Etichetta promozionale',
              hint: 'Es. "Novità": appare sulla scheda e nel banner del menu',
            ),
            LocalizedFields(label: 'Etichetta', controllers: _badge),
            const FormSection('Allergeni', hint: 'Regolamento UE 1169/2011'),
            AllergenPicker(
              selected: _allergens,
              onChanged: (v) => setState(() => _allergens = v),
            ),
            const FormSection('Caratteristiche'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final t in DietaryTag.values)
                  FilterChip(
                    label: Text(t.label.resolve('it')),
                    selected: _tags.contains(t),
                    selectedColor: S.success.withValues(alpha: 0.18),
                    onSelected: (on) => setState(
                      () => _tags = on ? {..._tags, t} : _tags.difference({t}),
                    ),
                  ),
              ],
            ),
            const FormSection(
              'Varianti',
              hint: 'Formati, contorni, aggiunte proposte al cliente',
            ),
            if (groups.isEmpty)
              const Text(
                'Nessun gruppo di varianti: creali nella scheda Varianti.',
                style: ST.small,
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final g in groups)
                    FilterChip(
                      avatar: g.required
                          ? const Icon(Icons.star_rounded, size: 16)
                          : null,
                      label: Text(g.name.resolve('it')),
                      selected: _groups.contains(g.id),
                      onSelected: (on) => setState(
                        () => _groups = on
                            ? [..._groups, g.id]
                            : [
                                for (final x in _groups)
                                  if (x != g.id) x,
                              ],
                      ),
                    ),
                ],
              ),
            const FormSection('Disponibilità'),
            Wrap(
              spacing: 24,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _Toggle(
                  label: 'Attivo sul totem',
                  value: _enabled,
                  onChanged: (v) => setState(() => _enabled = v),
                ),
                _Toggle(
                  label: 'Esaurito',
                  value: _soldOut,
                  onChanged: (v) => setState(() => _soldOut = v),
                ),
                _Toggle(
                  label: 'Gestisci scorte',
                  value: _trackStock,
                  onChanged: (v) => setState(() => _trackStock = v),
                ),
                if (_trackStock)
                  SizedBox(
                    width: 140,
                    child: TextFormField(
                      controller: _stock,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        labelText: 'Quantità',
                        isDense: true,
                      ),
                    ),
                  ),
                SizedBox(
                  width: 140,
                  child: TextFormField(
                    controller: _sort,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: 'Ordinamento',
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
            if (_trackStock)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Le scorte si scalano solo con il controllo scorte attivo '
                  'nelle impostazioni e fuori dalla modalità demo.',
                  style: ST.small,
                ),
              ),
          ],
        ),
      ),
      actions: [
        if (_p != null)
          TextButton.icon(
            key: const ValueKey('delete-product'),
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
          key: const ValueKey('save-product'),
          onPressed: _busy || _uploading ? null : _save,
          icon: const Icon(Icons.check_rounded),
          label: const Text('Salva'),
        ),
      ],
    );
  }
}

class _Toggle extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _Toggle({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Switch(value: value, onChanged: onChanged),
      const SizedBox(width: 6),
      Text(label, style: ST.body),
    ],
  );
}

class _PhotoBox extends StatelessWidget {
  final String? imageUrl;
  final bool uploading;
  final VoidCallback onPick;
  final VoidCallback onRemove;
  const _PhotoBox({
    required this.imageUrl,
    required this.uploading,
    required this.onPick,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Stack(
          children: [
            ServerImage(imageUrl, size: 168, radius: 20),
            if (uploading)
              const Positioned.fill(
                child: Center(child: CircularProgressIndicator()),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            TextButton.icon(
              key: const ValueKey('pick-photo'),
              onPressed: uploading ? null : onPick,
              icon: const Icon(Icons.upload_rounded, size: 18),
              label: Text(imageUrl == null ? 'Carica foto' : 'Cambia'),
            ),
            if (imageUrl != null)
              IconButton(
                tooltip: 'Rimuovi foto',
                onPressed: onRemove,
                icon: const Icon(Icons.delete_outline_rounded, size: 20),
              ),
          ],
        ),
      ],
    );
  }
}
