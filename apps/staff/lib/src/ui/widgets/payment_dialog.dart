import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kiosk_core/kiosk_core.dart';

import '../../api.dart';
import '../../session.dart';
import '../theme.dart';
import 'cash_pad.dart';

/// Asks how the customer pays [totalCents] at the till: cash (tapping the
/// notes and coins handed over, with the change worked out), card on the venue's terminal, or part each.
///
/// With [fiscal] (a documento commerciale is issued) the cashier can also
/// add the customer's lottery code or tax code.
Future<CounterPayment?> showPaymentDialog(
  BuildContext context, {
  required Cents totalCents,
  bool fiscal = false,
}) {
  final session = context.staffRead;
  return showDialog<CounterPayment>(
    context: context,
    builder: (_) => StaffScope(
      session: session,
      child: _PaymentDialog(total: totalCents, fiscal: fiscal),
    ),
  );
}

enum _Method { cash, card, mixed }

class _PaymentDialog extends StatefulWidget {
  final Cents total;
  final bool fiscal;
  const _PaymentDialog({required this.total, required this.fiscal});

  @override
  State<_PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends State<_PaymentDialog> {
  _Method _method = _Method.cash;

  /// Amount in cents: cash received, or the cash part when mixed.
  Cents _typed = 0;

  /// Notes and coins tapped on the pad, in order, so the last one can be
  /// taken back. Typing on the keypad starts over from the typed amount.
  final List<Cents> _pieces = [];

  /// Notes and coins (the default) or the number keypad.
  bool _keypad = false;

  Cents get _total => widget.total;

  String _lottery = '';
  String _taxCode = '';
  bool _showCustomer = false;

  /// The receipts lottery only takes electronic payments.
  bool get _lotteryAllowed => _method != _Method.cash;

  FiscalCustomer get _customer => FiscalCustomer.fromJson({
    if (_lotteryAllowed) 'lotteryCode': _lottery,
    'taxCode': _taxCode,
  });

  bool get _valid =>
      _customer.validate().isEmpty &&
      switch (_method) {
        _Method.cash => _typed == 0 || _typed >= _total,
        _Method.card => true,
        _Method.mixed => _typed > 0 && _typed < _total,
      };

  Map<Cents, int> get _counts {
    final out = <Cents, int>{};
    for (final p in _pieces) {
      out[p] = (out[p] ?? 0) + 1;
    }
    return out;
  }

  void _key(String k) {
    setState(() {
      _pieces.clear();
      if (k == 'del') {
        _typed ~/= 10;
      } else if (k == 'C') {
        _typed = 0;
      } else {
        final next = int.parse('$_typed$k');
        if (next < 10000000) _typed = next;
      }
    });
  }

  void _add(Cents c) {
    if (_typed + c >= 10000000) return;
    HapticFeedback.selectionClick();
    setState(() {
      _pieces.add(c);
      _typed += c;
    });
  }

  void _remove(Cents c) {
    final i = _pieces.lastIndexOf(c);
    if (i < 0) return;
    HapticFeedback.selectionClick();
    setState(() {
      _pieces.removeAt(i);
      _typed -= c;
    });
  }

  void _undo() => _remove(_pieces.last);

  void _clear() => setState(() {
    _pieces.clear();
    _typed = 0;
  });

  void _confirm() {
    Navigator.pop(context, switch (_method) {
      _Method.cash => CounterPayment.cash(
        receivedCents: _typed == 0 ? null : _typed,
        customer: _customer,
      ),
      _Method.card => CounterPayment.card(customer: _customer),
      _Method.mixed => CounterPayment.mixed(
        cashCents: _typed,
        cardCents: _total - _typed,
        customer: _customer,
      ),
    });
  }

  /// Lottery code and buyer's tax code for the documento commerciale.
  Widget _customerFields() {
    final lotteryOk =
        _lottery.isEmpty || TaxId.isValidLotteryCode(_lottery.trim());
    final cfOk =
        _taxCode.isEmpty ||
        TaxId.isValidTaxCode(_taxCode.trim()) ||
        TaxId.isValidVatNumber(_taxCode.trim());
    if (!_showCustomer) {
      return Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          key: const ValueKey('pay-fiscal-customer'),
          onPressed: () => setState(() => _showCustomer = true),
          icon: const Icon(Icons.confirmation_number_outlined),
          label: const Text('Codice lotteria o codice fiscale del cliente'),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: S.line, width: 1.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Sul documento commerciale', style: ST.h3),
          const SizedBox(height: 10),
          TextField(
            key: const ValueKey('pay-lottery'),
            enabled: _lotteryAllowed,
            textCapitalization: TextCapitalization.characters,
            maxLength: 8,
            decoration: InputDecoration(
              labelText: 'Codice lotteria',
              counterText: '',
              helperText: _lotteryAllowed
                  ? 'Gli 8 caratteri del codice del cliente'
                  : 'Vale solo per i pagamenti con carta',
              errorText: lotteryOk || !_lotteryAllowed
                  ? null
                  : 'Servono 8 lettere o cifre',
            ),
            onChanged: (v) => setState(() => _lottery = v),
          ),
          const SizedBox(height: 10),
          TextField(
            key: const ValueKey('pay-taxcode'),
            textCapitalization: TextCapitalization.characters,
            maxLength: 16,
            decoration: InputDecoration(
              labelText: 'Codice fiscale o P.IVA del cliente',
              counterText: '',
              helperText: 'Solo se il cliente lo chiede',
              errorText: cfOk ? null : 'Codice non valido',
            ),
            onChanged: (v) => setState(() => _taxCode = v),
          ),
        ],
      ),
    );
  }

  /// Received amount, change (or what is missing) and the undo buttons.
  Widget _summary(String Function(Cents) money) {
    final cash = _method == _Method.cash;
    final Widget result;
    if (cash && _typed == 0) {
      result = const _Hint(
        key: ValueKey('hint'),
        text:
            'Tocca le banconote e le monete che ti dà il cliente: '
            'il resto appare da solo.',
      );
    } else if (cash && _typed >= _total) {
      result = _ChangeCard(
        key: const ValueKey('change'),
        change: _typed - _total,
        money: money,
      );
    } else if (cash) {
      result = _ResultRow(
        key: const ValueKey('missing'),
        label: 'Mancano',
        value: money(_total - _typed),
        ok: false,
      );
    } else {
      result = _ResultRow(
        key: const ValueKey('card'),
        label: 'Con carta',
        value: _typed > 0 && _typed < _total ? money(_total - _typed) : '—',
        ok: _valid,
        note: _typed >= _total ? 'Supera il totale: scegli Contanti' : null,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _AmountBox(
          label: cash ? 'Contanti ricevuti' : 'Parte in contanti',
          value: _typed == 0 && cash ? 'Importo esatto' : money(_typed),
        ),
        const SizedBox(height: 12),
        AnimatedSwitcher(
          duration: S.medium,
          switchInCurve: Curves.easeOutBack,
          transitionBuilder: (child, a) => FadeTransition(
            opacity: a,
            child: ScaleTransition(
              scale: Tween(begin: 0.94, end: 1.0).animate(a),
              child: child,
            ),
          ),
          layoutBuilder: (current, previous) => Stack(
            alignment: Alignment.topCenter,
            children: [...previous, ?current],
          ),
          child: result,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _SmallAction(
                key: const ValueKey('pay-undo'),
                onPressed: _pieces.isEmpty ? null : _undo,
                icon: Icons.undo_rounded,
                label: _pieces.isEmpty
                    ? 'Annulla ultimo'
                    : 'Togli ${money(_pieces.last)}',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _SmallAction(
                key: const ValueKey('pay-clear'),
                onPressed: _typed == 0 ? null : _clear,
                icon: Icons.restart_alt_rounded,
                label: 'Azzera',
              ),
            ),
          ],
        ),
        if (!_keypad && _pieces.isNotEmpty) ...[
          const SizedBox(height: 8),
          const Text(
            'Tieni premuto su una banconota o moneta per toglierla.',
            style: ST.small,
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }

  /// Notes and coins, or the keypad, with the switch between them.
  Widget _input() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      SegmentedButton<bool>(
        key: const ValueKey('pay-input'),
        showSelectedIcon: false,
        segments: const [
          ButtonSegment(
            value: false,
            icon: Icon(Icons.payments_outlined),
            label: Text('Banconote e monete', key: ValueKey('pay-input-pad')),
          ),
          ButtonSegment(
            value: true,
            icon: Icon(Icons.dialpad_rounded),
            label: Text('Tastierino', key: ValueKey('pay-input-keypad')),
          ),
        ],
        selected: {_keypad},
        onSelectionChanged: (s) => setState(() => _keypad = s.first),
      ),
      const SizedBox(height: 16),
      AnimatedSwitcher(
        duration: S.fast,
        child: _keypad
            ? _Keypad(key: const ValueKey('keypad'), onKey: _key)
            : CashPad(
                key: const ValueKey('pad'),
                counts: _counts,
                onAdd: _add,
                onRemove: _remove,
              ),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final money = context.staff.money;
    final screen = MediaQuery.sizeOf(context).width;
    final cashLike = _method != _Method.card;
    final wide = screen >= 1000;
    final width = cashLike
        ? math.min(screen - 120, wide ? 940.0 : 560.0)
        : 520.0;
    return AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(28, 24, 28, 0),
      contentPadding: const EdgeInsets.fromLTRB(28, 16, 28, 0),
      title: Row(
        children: [
          const Expanded(child: Text('Incassa', style: ST.h2)),
          Text(money(_total), style: ST.h1),
        ],
      ),
      content: AnimatedSize(
        duration: S.medium,
        curve: Curves.easeOutCubic,
        alignment: Alignment.topCenter,
        child: SizedBox(
          width: width,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SegmentedButton<_Method>(
                  key: const ValueKey('pay-method'),
                  segments: const [
                    ButtonSegment(
                      value: _Method.cash,
                      icon: Icon(Icons.payments_rounded),
                      label: Text('Contanti', key: ValueKey('pay-method-cash')),
                    ),
                    ButtonSegment(
                      value: _Method.card,
                      icon: Icon(Icons.credit_card_rounded),
                      label: Text('Carta', key: ValueKey('pay-method-card')),
                    ),
                    ButtonSegment(
                      value: _Method.mixed,
                      icon: Icon(Icons.call_split_rounded),
                      label: Text('Misto', key: ValueKey('pay-method-mixed')),
                    ),
                  ],
                  selected: {_method},
                  onSelectionChanged: (s) => setState(() {
                    _method = s.first;
                    _clear();
                  }),
                ),
                const SizedBox(height: 18),
                if (!cashLike)
                  const _Note(
                    icon: Icons.contactless_rounded,
                    text:
                        'Fai pagare il cliente sul terminale POS della cassa, '
                        'poi conferma.',
                  )
                else if (wide)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(width: 300, child: _summary(money)),
                      const SizedBox(width: 24),
                      Expanded(child: _input()),
                    ],
                  )
                else ...[
                  _summary(money),
                  const SizedBox(height: 16),
                  _input(),
                ],
                if (widget.fiscal) ...[
                  const SizedBox(height: 8),
                  _customerFields(),
                ],
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(28, 8, 28, 24),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annulla'),
        ),
        FilledButton.icon(
          key: const ValueKey('pay-confirm'),
          style: FilledButton.styleFrom(
            backgroundColor: S.success,
            minimumSize: const Size(220, 56),
          ),
          onPressed: _valid ? _confirm : null,
          icon: const Icon(Icons.check_rounded),
          label: const Text('Conferma incasso'),
        ),
      ],
    );
  }
}

/// Outlined button whose label shrinks to fit half the summary column.
class _SmallAction extends StatelessWidget {
  final VoidCallback? onPressed;
  final IconData icon;
  final String label;
  const _SmallAction({
    super.key,
    required this.onPressed,
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) => OutlinedButton(
    style: OutlinedButton.styleFrom(
      minimumSize: const Size(0, 50),
      padding: const EdgeInsets.symmetric(horizontal: 10),
    ),
    onPressed: onPressed,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: 6),
        Flexible(
          child: FittedBox(fit: BoxFit.scaleDown, child: Text(label)),
        ),
      ],
    ),
  );
}

/// Grey prompt shown before any cash is taken.
class _Hint extends StatelessWidget {
  final String text;
  const _Hint({super.key, required this.text});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      border: Border.all(color: S.line, width: 1.5),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      children: [
        const Icon(Icons.touch_app_outlined, color: S.muted, size: 28),
        const SizedBox(width: 12),
        Expanded(child: Text(text, style: ST.small)),
      ],
    ),
  );
}

/// The change to give back, big and green, with the notes and coins that
/// make it up.
class _ChangeCard extends StatelessWidget {
  final Cents change;
  final String Function(Cents) money;
  const _ChangeCard({super.key, required this.change, required this.money});

  @override
  Widget build(BuildContext context) {
    final pieces = <Cents, int>{};
    for (final p in changeBreakdown(change)) {
      pieces[p] = (pieces[p] ?? 0) + 1;
    }
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
      decoration: BoxDecoration(
        color: S.success.withValues(alpha: 0.1),
        border: Border.all(color: S.success.withValues(alpha: 0.5), width: 1.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: S.success),
              const SizedBox(width: 8),
              const Expanded(child: Text('Resto da dare', style: ST.h3)),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            money(change),
            key: const ValueKey('pay-result'),
            style: const TextStyle(
              fontSize: 40,
              height: 1.1,
              fontWeight: FontWeight.w900,
              color: S.success,
            ),
          ),
          if (pieces.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              key: const ValueKey('pay-change-pieces'),
              spacing: 10,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                for (final e in pieces.entries) CashChip(e.key, count: e.value),
              ],
            ),
          ] else
            const Text('Importo giusto, nessun resto', style: ST.small),
        ],
      ),
    );
  }
}

class _AmountBox extends StatelessWidget {
  final String label;
  final String value;
  const _AmountBox({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
    decoration: BoxDecoration(
      color: S.background,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: ST.small),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: AnimatedSwitcher(
            duration: S.fast,
            transitionBuilder: (child, a) => FadeTransition(
              opacity: a,
              child: SlideTransition(
                position: Tween(
                  begin: const Offset(0, 0.25),
                  end: Offset.zero,
                ).animate(a),
                child: child,
              ),
            ),
            child: Text(
              value,
              key: ValueKey(value),
              style: const TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.w800,
                color: S.ink,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _ResultRow extends StatelessWidget {
  final String label;
  final String value;
  final bool ok;
  final String? note;
  const _ResultRow({
    super.key,
    required this.label,
    required this.value,
    required this.ok,
    this.note,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Text(label, style: ST.h3)),
            Text(
              value,
              key: const ValueKey('pay-result'),
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: ok ? S.success : S.primary,
              ),
            ),
          ],
        ),
        if (note != null) ...[
          const SizedBox(height: 4),
          Text(note!, style: ST.small.copyWith(color: S.danger)),
        ],
      ],
    ),
  );
}

class _Note extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Note({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: S.info.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      children: [
        Icon(icon, color: S.info, size: 32),
        const SizedBox(width: 14),
        Expanded(child: Text(text, style: ST.body)),
      ],
    ),
  );
}

class _Keypad extends StatelessWidget {
  final ValueChanged<String> onKey;
  const _Keypad({super.key, required this.onKey});

  @override
  Widget build(BuildContext context) {
    const rows = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['C', '0', 'del'],
    ];
    return Column(
      children: [
        for (final row in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                for (final (i, k) in row.indexed) ...[
                  if (i > 0) const SizedBox(width: 8),
                  Expanded(
                    child: SizedBox(
                      height: 54,
                      child: OutlinedButton(
                        key: ValueKey('pay-key-$k'),
                        onPressed: () => onKey(k),
                        child: k == 'del'
                            ? const Icon(Icons.backspace_outlined)
                            : Text(
                                k,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

/// How a till payment reads in the order detail.
String paymentSummary(PaymentInfo p, String Function(Cents) money) {
  final parts = <String>[
    switch (p.provider) {
      'cash' => 'Contanti',
      'card' => 'Carta',
      'mixed' =>
        'Contanti ${money(p.cashCents ?? 0)} + carta ${money(p.cardCents ?? 0)}',
      final other => other,
    },
  ];
  if (p.receivedCents != null) {
    parts.add('ricevuti ${money(p.receivedCents!)}');
    parts.add('resto ${money(p.changeCents ?? 0)}');
  }
  return parts.join(' · ');
}
