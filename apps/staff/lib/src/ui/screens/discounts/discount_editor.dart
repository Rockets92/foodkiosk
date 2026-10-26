import 'dart:math';

import 'package:barcode_widget/barcode_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kiosk_core/kiosk_core.dart';

import '../../../session.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../menu/form_helpers.dart';

/// What a code gives, in a few words: "-10%", "-3,00 €", "Omaggio".
String discountValueLabel(DiscountCode c, String Function(Cents) money) =>
    switch (c.type) {
      DiscountType.percent => '-${c.percent}%',
      DiscountType.amount => '-${money(c.amountCents)}',
      DiscountType.freeProduct => 'Omaggio',
    };

String discountTypeLabel(DiscountType t) => switch (t) {
  DiscountType.percent => 'Percentuale',
  DiscountType.amount => 'Importo fisso',
  DiscountType.freeProduct => 'Prodotto omaggio',
};

IconData discountTypeIcon(DiscountType t) => switch (t) {
  DiscountType.percent => Icons.percent_rounded,
  DiscountType.amount => Icons.euro_rounded,
  DiscountType.freeProduct => Icons.card_giftcard_rounded,
};

/// A readable random code: no 0/O or 1/I to confuse when typed.
String randomCode([int length = 8]) {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  final r = Random.secure();
  return List.generate(length, (_) => chars[r.nextInt(chars.length)]).join();
}

Future<void> editDiscount(BuildContext context, {DiscountCode? code}) {
  final session = context.staffRead;
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => StaffScope(
      session: session,
      child: _DiscountEditor(code: code),
    ),
  );
}

class _DiscountEditor extends StatefulWidget {
  final DiscountCode? code;
  const _DiscountEditor({this.code});

  @override
  State<_DiscountEditor> createState() => _DiscountEditorState();
}

class _DiscountEditorState extends State<_DiscountEditor> {
  final _form = GlobalKey<FormState>();
  late final DiscountCode? _c = widget.code;
  late final _code = TextEditingController(text: _c?.code ?? randomCode());
  late final _label = LocalizedControllers(
    _c?.label ?? const LocalizedText.empty(),
  );
  late final _note = TextEditingController(text: _c?.note ?? '');
  late final _percent = TextEditingController(
    text: _c == null || _c.percent == 0 ? '10' : '${_c.percent}',
  );
  late final _amount = TextEditingController(
    text: _c == null || _c.amountCents == 0 ? '' : euroText(_c.amountCents),
  );
  late final _minOrder = TextEditingController(
    text: _c == null || _c.minOrderCents == 0 ? '' : euroText(_c.minOrderCents),
  );
  late final _maxUses = TextEditingController(
    text: _c?.maxUses?.toString() ?? '100',
  );
  late DiscountType _type = _c?.type ?? DiscountType.percent;
  late String? _productId = _c?.productId;
  late bool _limited = _c?.maxUses != null;
  late DateTime? _from = _c?.validFrom?.toLocal();
  // Stored as the start of the day after the last valid one.
  late DateTime? _until = _c?.validUntil?.toLocal().subtract(
    const Duration(hours: 12),
  );
  late bool _enabled = _c?.enabled ?? true;
  bool _busy = false;

  @override
  void dispose() {
    _label.dispose();
    for (final c in [_code, _note, _percent, _amount, _minOrder, _maxUses]) {
      c.dispose();
    }
    super.dispose();
  }

  DiscountCode _build() => DiscountCode(
    id: _c?.id ?? '',
    code: DiscountCode.normalize(_code.text),
    type: _type,
    label: _label.value,
    note: _note.text.trim(),
    percent: _type == DiscountType.percent
        ? int.tryParse(_percent.text.trim()) ?? 0
        : 0,
    amountCents: _type == DiscountType.amount
        ? parseEuro(_amount.text) ?? 0
        : 0,
    productId: _type == DiscountType.freeProduct ? _productId : null,
    minOrderCents: parseEuro(_minOrder.text) ?? 0,
    maxUses: _limited ? int.tryParse(_maxUses.text.trim()) : null,
    usedCount: _c?.usedCount ?? 0,
    validFrom: _from,
    // The end date is inclusive: valid until the end of that day.
    validUntil: _until == null
        ? null
        : DateTime(_until!.year, _until!.month, _until!.day + 1),
    enabled: _enabled,
  );

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final code = _build();
    final errors = code.validate();
    if (errors.isNotEmpty) {
      showMessage(context, errors.first, error: true);
      return;
    }
    final session = context.staffRead;
    setState(() => _busy = true);
    final saved = await guard(
      context,
      () => session.api.saveDiscount(code, isNew: _c == null),
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (saved == null) return;
    Navigator.pop(context);
    showMessage(context, 'Codice ${saved.code} salvato');
  }

  Future<void> _pickDate({required bool start}) async {
    final now = DateTime.now();
    final current = start ? _from : _until;
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
      locale: const Locale('it'),
    );
    if (picked == null) return;
    setState(() => start ? _from = picked : _until = picked);
  }

  @override
  Widget build(BuildContext context) {
    final session = context.staff;
    final products = [...session.menu.products]
      ..sort((a, b) => a.name.resolve('it').compareTo(b.name.resolve('it')));
    String date(DateTime? d) => d == null
        ? '—'
        : '${d.day.toString().padLeft(2, '0')}/'
              '${d.month.toString().padLeft(2, '0')}/${d.year}';
    final preview = _build();
    return EditorDialog(
      title: _c == null ? 'Nuovo codice sconto' : 'Modifica codice sconto',
      width: 820,
      body: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    key: const ValueKey('discount-code'),
                    controller: _code,
                    textCapitalization: TextCapitalization.characters,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(r'[A-Za-z0-9_-]'),
                      ),
                      LengthLimitingTextInputFormatter(32),
                      _UpperCase(),
                    ],
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 3,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Codice *',
                      helperText:
                          'Quello che il cliente scrive o scansiona. '
                          'Lettere, numeri, - e _',
                      prefixIcon: Icon(Icons.local_offer_rounded),
                    ),
                    onChanged: (_) => setState(() {}),
                    validator: (v) =>
                        DiscountCode.isValidCode(
                          DiscountCode.normalize(v ?? ''),
                        )
                        ? null
                        : 'Da 3 a 32 caratteri',
                  ),
                ),
                const SizedBox(width: 12),
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: OutlinedButton.icon(
                    key: const ValueKey('discount-generate'),
                    onPressed: () => setState(() => _code.text = randomCode()),
                    icon: const Icon(Icons.casino_rounded),
                    label: const Text('Genera'),
                  ),
                ),
              ],
            ),
            const FormSection('Cosa offre'),
            SegmentedButton<DiscountType>(
              key: const ValueKey('discount-type'),
              segments: [
                for (final t in DiscountType.values)
                  ButtonSegment(
                    value: t,
                    icon: Icon(discountTypeIcon(t)),
                    label: Text(discountTypeLabel(t)),
                  ),
              ],
              selected: {_type},
              onSelectionChanged: (s) => setState(() => _type = s.first),
            ),
            const SizedBox(height: 16),
            switch (_type) {
              DiscountType.percent => _Narrow(
                TextFormField(
                  key: const ValueKey('discount-percent'),
                  controller: _percent,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'Percentuale di sconto',
                    suffixText: '%',
                    helperText: 'Su tutto l\'ordine',
                  ),
                  onChanged: (_) => setState(() {}),
                  validator: (v) {
                    final n = int.tryParse(v ?? '');
                    return n == null || n < 1 || n > 100 ? 'Da 1 a 100' : null;
                  },
                ),
              ),
              DiscountType.amount => _Narrow(
                TextFormField(
                  key: const ValueKey('discount-amount'),
                  controller: _amount,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Importo dello sconto',
                    suffixText: session.settings.currencySymbol,
                    helperText: 'Mai oltre il totale dell\'ordine',
                  ),
                  onChanged: (_) => setState(() {}),
                  validator: (v) => (parseEuro(v ?? '') ?? 0) <= 0
                      ? 'Importo non valido'
                      : null,
                ),
              ),
              DiscountType.freeProduct => DropdownButtonFormField<String>(
                key: const ValueKey('discount-product'),
                initialValue: products.any((p) => p.id == _productId)
                    ? _productId
                    : null,
                decoration: const InputDecoration(
                  labelText: 'Prodotto in omaggio',
                  helperText:
                      'Il prezzo base di una unità è gratis; le aggiunte a '
                      'pagamento restano. Se non richiede scelte, il totem '
                      'lo aggiunge da solo al carrello.',
                  helperMaxLines: 2,
                ),
                items: [
                  for (final p in products)
                    DropdownMenuItem(
                      value: p.id,
                      child: Text(
                        '${p.name.resolve('it')} · '
                        '${session.money(p.priceCents)}',
                      ),
                    ),
                ],
                onChanged: (v) => setState(() => _productId = v),
                validator: (v) => v == null ? 'Scegli il prodotto' : null,
              ),
            },
            const FormSection(
              'Testo per il cliente',
              hint: 'facoltativo: se vuoto si usa una descrizione automatica',
            ),
            LocalizedFields(
              label: 'Nome promozione',
              controllers: _label,
              keyPrefix: 'discount-label',
            ),
            const FormSection('Condizioni'),
            Wrap(
              spacing: 16,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 220,
                  child: TextFormField(
                    key: const ValueKey('discount-min'),
                    controller: _minOrder,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Spesa minima',
                      hintText: 'nessuna',
                      suffixText: session.settings.currencySymbol,
                    ),
                    validator: (v) =>
                        (v ?? '').trim().isNotEmpty && parseEuro(v!) == null
                        ? 'Importo non valido'
                        : null,
                  ),
                ),
                FilterChip(
                  key: const ValueKey('discount-limited'),
                  avatar: const Icon(Icons.confirmation_number_rounded),
                  label: const Text('Limita gli utilizzi'),
                  selected: _limited,
                  onSelected: (v) => setState(() => _limited = v),
                ),
                if (_limited)
                  SizedBox(
                    width: 160,
                    child: TextFormField(
                      key: const ValueKey('discount-max-uses'),
                      controller: _maxUses,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        labelText: 'Utilizzi massimi',
                        helperText: '1 = monouso',
                      ),
                      validator: (v) =>
                          (int.tryParse(v ?? '') ?? 0) < 1 ? 'Almeno 1' : null,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Text('Validità', style: ST.h3),
                _DateButton(
                  label: 'Dal ${date(_from)}',
                  onTap: () => _pickDate(start: true),
                  onClear: _from == null
                      ? null
                      : () => setState(() => _from = null),
                ),
                _DateButton(
                  label: 'Al ${date(_until)}',
                  onTap: () => _pickDate(start: false),
                  onClear: _until == null
                      ? null
                      : () => setState(() => _until = null),
                ),
                if (_from == null && _until == null)
                  const Text('sempre valido', style: ST.small),
              ],
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _note,
              decoration: const InputDecoration(
                labelText: 'Nota interna',
                hintText: 'Es. volantino ottobre, cliente Rossi…',
              ),
            ),
            const SizedBox(height: 6),
            SwitchListTile(
              key: const ValueKey('discount-enabled'),
              contentPadding: EdgeInsets.zero,
              title: const Text('Attivo', style: ST.h3),
              subtitle: const Text(
                'Spento, il codice viene rifiutato senza perderne i dati',
                style: ST.small,
              ),
              value: _enabled,
              onChanged: (v) => setState(() => _enabled = v),
            ),
            if (_c != null && _c.usedCount > 0)
              Text('Utilizzato ${_c.usedCount} volte finora.', style: ST.small),
            const FormSection('Anteprima'),
            DiscountTicket(code: preview, compact: true),
          ],
        ),
      ),
      actions: [
        const Spacer(),
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('Annulla'),
        ),
        const SizedBox(width: 8),
        FilledButton.icon(
          key: const ValueKey('discount-save'),
          onPressed: _busy ? null : _save,
          icon: const Icon(Icons.save_rounded),
          label: const Text('Salva codice'),
        ),
      ],
    );
  }
}

class _Narrow extends StatelessWidget {
  final Widget child;
  const _Narrow(this.child);

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: SizedBox(width: 280, child: child),
  );
}

class _DateButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final VoidCallback? onClear;
  const _DateButton({required this.label, required this.onTap, this.onClear});

  @override
  Widget build(BuildContext context) => InputChip(
    avatar: const Icon(Icons.event_rounded, size: 18),
    label: Text(label),
    onPressed: onTap,
    onDeleted: onClear,
  );
}

class _UpperCase extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) => newValue.copyWith(text: newValue.text.toUpperCase());
}

/// The code drawn as a coupon: the value on a coloured stub, then the code
/// and its conditions. Used in the list and as the editor's preview.
class DiscountTicket extends StatelessWidget {
  final DiscountCode code;
  final bool compact;
  final Widget? footer;
  const DiscountTicket({
    super.key,
    required this.code,
    this.compact = false,
    this.footer,
  });

  static Color colorOf(DiscountType t) => switch (t) {
    DiscountType.percent => S.primary,
    DiscountType.amount => const Color(0xFF2F6FEB),
    DiscountType.freeProduct => S.success,
  };

  @override
  Widget build(BuildContext context) {
    final session = context.staff;
    final color = colorOf(code.type);
    final product = code.productId == null
        ? null
        : session.menu.product(code.productId!);
    final label = code.label.resolve('it');
    final description = label.isNotEmpty
        ? label
        : switch (code.type) {
            DiscountType.percent => 'Sconto del ${code.percent}%',
            DiscountType.amount =>
              'Sconto di ${session.money(code.amountCents)}',
            DiscountType.freeProduct =>
              '${product?.name.resolve('it') ?? 'Prodotto'} in omaggio',
          };
    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          width: 120,
          decoration: ShapeDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color.lerp(color, Colors.white, 0.15)!, color],
            ),
            shape: const _CouponShape(stub: 120, stubOnly: true),
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (code.type == DiscountType.freeProduct && product != null)
                ServerImage(product.imageUrl, size: 54, radius: 27)
              else
                Icon(
                  discountTypeIcon(code.type),
                  color: Colors.white70,
                  size: 26,
                ),
              const SizedBox(height: 4),
              FittedBox(
                child: Text(
                  discountValueLabel(code, session.money),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 26,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, compact ? 12 : 14, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  code.code.isEmpty ? '—' : code.code,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2.5,
                    color: S.ink,
                  ),
                ),
                Text(
                  description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: ST.body.copyWith(color: S.inkSoft),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    if (code.minOrderCents > 0)
                      Pill(
                        'Spesa min. ${session.money(code.minOrderCents)}',
                        color: S.inkSoft,
                        icon: Icons.shopping_basket_rounded,
                      ),
                    if (code.validFrom != null || code.validUntil != null)
                      Pill(
                        _validity(code),
                        color: S.inkSoft,
                        icon: Icons.event_rounded,
                      ),
                    if (code.maxUses == 1)
                      const Pill(
                        'Monouso',
                        color: S.inkSoft,
                        icon: Icons.looks_one_rounded,
                      ),
                  ],
                ),
                if (footer != null) Expanded(child: footer!),
              ],
            ),
          ),
        ),
      ],
    );
    return Container(
      decoration: ShapeDecoration(
        color: Colors.white,
        shape: const _CouponShape(stub: 120),
        shadows: S.shadow,
      ),
      child: footer == null ? IntrinsicHeight(child: row) : row,
    );
  }

  static String _validity(DiscountCode c) {
    String d(DateTime t) {
      final l = t.toLocal();
      return '${l.day.toString().padLeft(2, '0')}/'
          '${l.month.toString().padLeft(2, '0')}/${l.year % 100}';
    }

    final until = c.validUntil?.subtract(const Duration(seconds: 1));
    if (c.validFrom != null && until != null) {
      return '${d(c.validFrom!)} → ${d(until)}';
    }
    if (until != null) return 'Fino al ${d(until)}';
    return 'Dal ${d(c.validFrom!)}';
  }
}

/// Rounded card with two half-circle notches where the stub ends.
class _CouponShape extends ShapeBorder {
  final double stub;
  final bool stubOnly;
  const _CouponShape({required this.stub, this.stubOnly = false});

  static const _r = 18.0;
  static const _notch = 10.0;

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.zero;

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      getOuterPath(rect);

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    final card = Path()
      ..addRRect(
        stubOnly
            ? RRect.fromRectAndCorners(
                rect,
                topLeft: const Radius.circular(_r),
                bottomLeft: const Radius.circular(_r),
              )
            : RRect.fromRectAndRadius(rect, const Radius.circular(_r)),
      );
    final x = stubOnly ? rect.right : rect.left + stub;
    final holes = Path()
      ..addOval(Rect.fromCircle(center: Offset(x, rect.top), radius: _notch))
      ..addOval(
        Rect.fromCircle(center: Offset(x, rect.bottom), radius: _notch),
      );
    return Path.combine(PathOperation.difference, card, holes);
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {}

  @override
  ShapeBorder scale(double t) => this;
}

/// QR code and barcode of a code, to print on flyers or show on a phone.
Future<void> showDiscountQr(BuildContext context, DiscountCode code) {
  final session = context.staffRead;
  return showDialog<void>(
    context: context,
    builder: (ctx) => StaffScope(
      session: session,
      child: AlertDialog(
        title: Text('Coupon ${code.code}', style: ST.h2),
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DiscountTicket(code: code, compact: true),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        BarcodeWidget(
                          key: const ValueKey('discount-qr'),
                          barcode: Barcode.qrCode(),
                          data: code.code,
                          width: 190,
                          height: 190,
                        ),
                        const SizedBox(height: 8),
                        const Text('QR code', style: ST.small),
                      ],
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      children: [
                        BarcodeWidget(
                          barcode: Barcode.code128(),
                          data: code.code,
                          height: 110,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            letterSpacing: 2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text('Codice a barre', style: ST.small),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'Stampali sui volantini o mostrali dal telefono: il lettore '
                'del totem e della cassa li riconosce entrambi.',
                textAlign: TextAlign.center,
                style: ST.small,
              ),
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Chiudi'),
          ),
        ],
      ),
    ),
  );
}
