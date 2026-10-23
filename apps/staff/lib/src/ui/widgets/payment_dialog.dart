import 'package:flutter/material.dart';
import 'package:kiosk_core/kiosk_core.dart';

import '../../api.dart';
import '../../session.dart';
import '../theme.dart';

/// Asks how the customer pays [totalCents] at the till: cash (with the
/// change worked out), card on the venue's terminal, or part each.
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

  /// Typed amount in cents: cash received, or the cash part when mixed.
  Cents _typed = 0;

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

  /// Quick amounts: the exact total, the next whole euro and the notes
  /// that cover it.
  List<Cents> get _suggestions {
    final out = <Cents>{_total};
    final nextEuro = (_total + 99) ~/ 100 * 100;
    out.add(nextEuro);
    for (final note in [500, 1000, 2000, 5000, 10000, 20000]) {
      if (note >= _total) out.add(note);
    }
    return out.take(5).toList();
  }

  void _key(String k) {
    setState(() {
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

  @override
  Widget build(BuildContext context) {
    final money = context.staff.money;
    return AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(28, 24, 28, 0),
      contentPadding: const EdgeInsets.fromLTRB(28, 16, 28, 0),
      title: Row(
        children: [
          const Expanded(child: Text('Incassa', style: ST.h2)),
          Text(money(_total), style: ST.h1),
        ],
      ),
      content: SizedBox(
        width: 520,
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
                  _typed = 0;
                }),
              ),
              const SizedBox(height: 18),
              if (_method == _Method.card)
                const _Note(
                  icon: Icons.contactless_rounded,
                  text:
                      'Fai pagare il cliente sul terminale POS della cassa, '
                      'poi conferma.',
                )
              else ...[
                _AmountBox(
                  label: _method == _Method.cash
                      ? 'Contanti ricevuti'
                      : 'Parte in contanti',
                  value: _typed == 0 && _method == _Method.cash
                      ? 'Importo esatto'
                      : money(_typed),
                ),
                const SizedBox(height: 10),
                if (_method == _Method.cash)
                  _ResultRow(
                    label: 'Resto',
                    value: _typed == 0
                        ? money(0)
                        : _typed >= _total
                        ? money(_typed - _total)
                        : 'Mancano ${money(_total - _typed)}',
                    ok: _valid,
                  )
                else
                  _ResultRow(
                    label: 'Con carta',
                    value: _typed > 0 && _typed < _total
                        ? money(_total - _typed)
                        : '—',
                    ok: _valid,
                  ),
                const SizedBox(height: 12),
                if (_method == _Method.cash)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final (i, c) in _suggestions.indexed)
                        ActionChip(
                          key: ValueKey('pay-quick-$i'),
                          label: Text(i == 0 ? 'Esatto' : money(c)),
                          onPressed: () =>
                              setState(() => _typed = i == 0 ? 0 : c),
                        ),
                    ],
                  ),
                const SizedBox(height: 12),
                _Keypad(onKey: _key),
              ],
              if (widget.fiscal) ...[
                const SizedBox(height: 4),
                _customerFields(),
              ],
              const SizedBox(height: 8),
            ],
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
    child: Row(
      children: [
        Expanded(child: Text(label, style: ST.small)),
        Text(
          value,
          key: const ValueKey('pay-amount'),
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: S.ink,
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
  const _ResultRow({
    required this.label,
    required this.value,
    required this.ok,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 18),
    child: Row(
      children: [
        Expanded(child: Text(label, style: ST.h3)),
        Text(
          value,
          key: const ValueKey('pay-result'),
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: ok ? S.success : S.primary,
          ),
        ),
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
  const _Keypad({required this.onKey});

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
