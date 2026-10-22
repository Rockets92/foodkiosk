import 'package:kiosk_core/kiosk_core.dart';

import 'adapters/printer.dart';

const _labels = {
  'it': {
    'order': 'ORDINE',
    'eatIn': 'Consumo sul posto',
    'takeAway': 'Da asporto',
    'total': 'TOTALE',
    'subtotal': 'Subtotale',
    'discount': 'Sconto',
    'vat': 'di cui IVA',
    'payAtCounter': 'Paga in cassa mostrando questo scontrino',
    'paid': 'PAGATO',
    'notFiscal': 'Non costituisce documento fiscale',
    'demo': '*** DEMO - NON VALIDO ***',
    'thanks': 'Grazie e buon appetito!',
    'document': 'Documento',
  },
  'en': {
    'order': 'ORDER',
    'eatIn': 'Eat in',
    'takeAway': 'Take away',
    'total': 'TOTAL',
    'subtotal': 'Subtotal',
    'discount': 'Discount',
    'vat': 'incl. VAT',
    'payAtCounter': 'Please pay at the counter with this ticket',
    'paid': 'PAID',
    'notFiscal': 'This is not a fiscal receipt',
    'demo': '*** DEMO - NOT VALID ***',
    'thanks': 'Thank you, enjoy your meal!',
    'document': 'Document',
  },
};

String _l(String lang, String key) =>
    (_labels[lang] ?? _labels['it']!)[key] ?? _labels['it']![key]!;

String _time(DateTime t) {
  final l = t.toLocal();
  return '${l.day.toString().padLeft(2, '0')}/${l.month.toString().padLeft(2, '0')}/${l.year} '
      '${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}';
}

/// Ticket the customer keeps: order number, items and total. When the
/// order still has to be paid it tells the customer to go to the till.
Ticket customerTicket(Order order, KioskSettings settings) {
  final lang = order.language;
  String money(Cents c) => formatCents(c, symbol: settings.currencySymbol);
  return Ticket([
    TicketText(settings.venueName, align: TicketAlign.center, bold: true),
    TicketText(_time(order.createdAt), align: TicketAlign.center),
    if (order.isDemo) TicketText(_l(lang, 'demo'), align: TicketAlign.center),
    const TicketSeparator(),
    TicketText(_l(lang, 'order'), align: TicketAlign.center),
    TicketText(
      order.displayNumber,
      align: TicketAlign.center,
      bold: true,
      large: true,
    ),
    TicketText(_l(lang, order.serviceMode.name), align: TicketAlign.center),
    const TicketSeparator(),
    for (final line in order.lines) ...[
      TicketRow(
        '${line.quantity}x ${line.name.resolve(lang)}',
        money(line.totalCents),
      ),
      for (final o in line.options)
        TicketRow(
          '   ${o.name.resolve(lang)}',
          o.priceDeltaCents == 0
              ? ''
              : '+${money(o.priceDeltaCents * line.quantity)}',
        ),
      if (line.note != null && line.note!.isNotEmpty)
        TicketText('   "${line.note}"'),
    ],
    const TicketSeparator(),
    if (order.discount case final d?) ...[
      TicketRow(_l(lang, 'subtotal'), money(order.subtotalCents)),
      TicketRow(
        '${_l(lang, 'discount')} ${d.code}',
        '-${money(d.amountCents)}',
      ),
      if (!d.label.isEmpty) TicketText('   ${d.label.resolve(lang)}'),
    ],
    TicketRow(_l(lang, 'total'), money(order.totalCents), bold: true),
    for (final e in order.vatBreakdown.entries)
      TicketRow(
        '${_l(lang, 'vat')} ${e.key.toStringAsFixed(0)}%',
        money(e.value),
      ),
    const TicketFeed(),
    if (order.paymentStatus == PaymentStatus.awaitingCounter)
      TicketText(
        _l(lang, 'payAtCounter'),
        align: TicketAlign.center,
        bold: true,
      ),
    if (order.paymentStatus == PaymentStatus.paid)
      TicketText(_l(lang, 'paid'), align: TicketAlign.center, bold: true),
    if (order.fiscalDocument case final doc?)
      TicketText(
        '${_l(lang, 'document')}: ${doc.number}',
        align: TicketAlign.center,
      )
    else
      TicketText(_l(lang, 'notFiscal'), align: TicketAlign.center),
    TicketText(_l(lang, 'thanks'), align: TicketAlign.center),
    const TicketFeed(3),
    const TicketCut(),
  ]);
}

/// Ticket for the kitchen: big number, items and options, no prices.
/// Always in the venue's default language.
Ticket kitchenTicket(Order order, KioskSettings settings) {
  final lang = settings.defaultLanguage;
  return Ticket([
    TicketText(
      '#${order.displayNumber}',
      align: TicketAlign.center,
      bold: true,
      large: true,
    ),
    TicketText(
      _l(lang, order.serviceMode.name).toUpperCase(),
      align: TicketAlign.center,
      bold: true,
    ),
    TicketText(_time(order.createdAt), align: TicketAlign.center),
    if (order.isDemo) TicketText(_l(lang, 'demo'), align: TicketAlign.center),
    const TicketSeparator(),
    for (final line in order.lines) ...[
      TicketText('${line.quantity}x ${line.name.resolve(lang)}', bold: true),
      for (final o in line.options) TicketText('   - ${o.name.resolve(lang)}'),
      if (line.note != null && line.note!.isNotEmpty)
        TicketText('   !! ${line.note}', bold: true),
    ],
    const TicketFeed(3),
    const TicketCut(),
  ]);
}
