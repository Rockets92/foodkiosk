import 'package:kiosk_core/kiosk_core.dart';

import 'adapters/fiscal.dart';
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
    'notFiscal': 'Promemoria ordine: non è un documento commerciale',
    'demo': '*** DEMO - NON VALIDO ***',
    'thanks': 'Grazie e buon appetito!',
    'document': 'Documento commerciale N.',
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
    'notFiscal': 'Order reminder: this is not a fiscal receipt',
    'demo': '*** DEMO - NOT VALID ***',
    'thanks': 'Thank you, enjoy your meal!',
    'document': 'Fiscal receipt no.',
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
///
/// Once the order has a fiscal document that the suite prints itself
/// (online procedure), the ticket is that [commercialDocument].
Ticket customerTicket(
  Order order,
  KioskSettings settings, {
  bool reprint = false,
}) {
  if (order.fiscalDocument case final doc? when !doc.printedByDevice) {
    return commercialDocument(order, settings, reprint: reprint);
  }
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
    // The registratore telematico printed the documento commerciale:
    // this ticket is only the order reminder.
    if (order.fiscalDocument case final doc?)
      TicketText(
        '${_l(lang, 'document')}: ${doc.number}',
        align: TicketAlign.center,
      ),
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

String _date(DateTime t) {
  final l = t.toLocal();
  return '${l.day.toString().padLeft(2, '0')}-${l.month.toString().padLeft(2, '0')}-${l.year}';
}

String _dateTime(DateTime t) {
  final l = t.toLocal();
  return '${_date(t)} ${l.hour.toString().padLeft(2, '0')}:'
      '${l.minute.toString().padLeft(2, '0')}';
}

/// Amounts on fiscal documents: "11,70", the currency is in the header.
String _amount(Cents c) => formatCents(c, symbol: '').trimRight();

String _rate(double vat) => vat == vat.roundToDouble()
    ? '${vat.toInt()}%'
    : '${vat.toStringAsFixed(1).replaceAll('.', ',')}%';

/// Seller, as every documento commerciale starts.
List<TicketLine> _merchantHeader(KioskSettings s) {
  final m = s.merchant;
  return [
    TicketText(
      m.legalName.isEmpty ? s.venueName : m.legalName,
      align: TicketAlign.center,
      bold: true,
    ),
    if (m.legalName.isNotEmpty && m.legalName != s.venueName)
      TicketText(s.venueName, align: TicketAlign.center),
    if (m.address.isNotEmpty) TicketText(m.address, align: TicketAlign.center),
    if (m.city.isNotEmpty)
      TicketText(
        [
          m.zip,
          m.city,
          if (m.province.isNotEmpty) '(${m.province})',
        ].where((e) => e.isNotEmpty).join(' '),
        align: TicketAlign.center,
      ),
    if (m.vatNumber.isNotEmpty)
      TicketText('P.IVA ${m.vatNumber}', align: TicketAlign.center),
    if (m.taxCode.isNotEmpty && m.taxCode != m.vatNumber)
      TicketText('C.F. ${m.taxCode}', align: TicketAlign.center),
  ];
}

/// Items with VAT rate and price, then discount, total and VAT.
List<TicketLine> _fiscalBody(Order order, KioskSettings s) {
  String cur(String label) => '$label(${s.currencySymbol.trim()})';
  final vat = order.vatBreakdown;
  return [
    TicketRow(
      'DESCRIZIONE',
      '${'IVA'.padLeft(4)}  ${cur('Prezzo').padLeft(9)}',
    ),
    for (final l in order.lines) ...[
      if (l.quantity > 1)
        TicketText('${l.quantity} x ${_amount(l.unitTotalCents)}'),
      TicketRow(
        _fiscalDescription(l),
        '${_rate(l.vatRate).padLeft(4)}  ${_amount(l.totalCents).padLeft(9)}',
      ),
    ],
    if (order.discount case final d?) ...[
      TicketRow('SUBTOTALE', _amount(order.subtotalCents)),
      TicketRow('SCONTO ${d.code}', '-${_amount(order.discountCents)}'),
    ],
    const TicketSeparator(),
    TicketRow(
      cur('TOTALE COMPLESSIVO '),
      _amount(order.totalCents),
      bold: true,
    ),
    if (vat.length == 1)
      TicketRow('di cui IVA', _amount(vat.values.single))
    else
      for (final e in vat.entries)
        TicketRow('di cui IVA ${_rate(e.key)}', _amount(e.value)),
  ];
}

/// Italian, with the paid extras: the document is always in Italian.
String _fiscalDescription(OrderLine l) {
  final extras = [
    for (final o in l.options)
      if (o.priceDeltaCents != 0) o.name.resolve('it'),
  ];
  final name = l.name.resolve('it');
  return extras.isEmpty ? name : '$name + ${extras.join(' + ')}';
}

/// Number, date, device and the customer's codes.
List<TicketLine> _fiscalFooter(FiscalDocument doc) => [
  TicketText(_dateTime(doc.issuedAt), align: TicketAlign.center),
  TicketText(
    'DOCUMENTO N. ${doc.number}',
    align: TicketAlign.center,
    bold: true,
  ),
  if (doc.deviceId case final id?)
    TicketText(
      doc.provider == 'epsonRt' ? 'RT $id' : id,
      align: TicketAlign.center,
    ),
  if (doc.lotteryCode case final code?)
    TicketText('Codice lotteria: $code', align: TicketAlign.center),
  if (doc.customerTaxCode case final cf?)
    TicketText('C.F./P.IVA acquirente: $cf', align: TicketAlign.center),
  if (doc.test) ...[
    const TicketText(
      '*** DOCUMENTO DI PROVA ***',
      align: TicketAlign.center,
      bold: true,
    ),
    const TicketText('NON VALIDO AI FINI FISCALI', align: TicketAlign.center),
  ],
];

/// The "documento commerciale" for a sale, printed by the suite when the
/// fiscal device does not print it (Agenzia's online procedure, demo).
///
/// Content as DM 7 dicembre 2016 (art. 2) and the Agenzia's technical
/// specifications require: seller's name, address and VAT number; the
/// heading "DOCUMENTO COMMERCIALE di vendita o prestazione"; each item
/// with its VAT rate and price; total and VAT included; how it was paid;
/// date, time and document number; the lottery code or the buyer's tax
/// code when given. The order number follows, for the pickup.
Ticket commercialDocument(
  Order order,
  KioskSettings settings, {
  bool reprint = false,
}) {
  final doc = order.fiscalDocument!;
  final pay = PaymentSplit.of(order);
  return Ticket([
    ..._merchantHeader(settings),
    const TicketSeparator(),
    const TicketText(
      'DOCUMENTO COMMERCIALE',
      align: TicketAlign.center,
      bold: true,
    ),
    const TicketText('di vendita o prestazione', align: TicketAlign.center),
    if (reprint)
      const TicketText('COPIA - RISTAMPA', align: TicketAlign.center),
    const TicketSeparator(),
    ..._fiscalBody(order, settings),
    if (pay.cashCents > 0)
      TicketRow('Pagamento contante', _amount(pay.cashCents)),
    if (pay.electronicCents > 0)
      TicketRow('Pagamento elettronico', _amount(pay.electronicCents)),
    if (pay.receivedCents case final r? when r > pay.cashCents) ...[
      TicketRow('Importo pagato', _amount(r + pay.electronicCents)),
      TicketRow('Resto', _amount(pay.changeCents!)),
    ],
    const TicketSeparator(),
    ..._fiscalFooter(doc),
    if (order.isDemo) TicketText(_l('it', 'demo'), align: TicketAlign.center),
    const TicketSeparator(),
    TicketText(_l(order.language, 'order'), align: TicketAlign.center),
    TicketText(
      order.displayNumber,
      align: TicketAlign.center,
      bold: true,
      large: true,
    ),
    TicketText(
      _l(order.language, order.serviceMode.name),
      align: TicketAlign.center,
    ),
    TicketText(_l(order.language, 'thanks'), align: TicketAlign.center),
    const TicketFeed(3),
    const TicketCut(),
  ]);
}

/// The "documento commerciale emesso per ANNULLAMENTO" of a cancelled
/// order, with the reference to the document it cancels.
Ticket voidCommercialDocument(Order order, KioskSettings settings) {
  final doc = order.fiscalVoid!;
  return Ticket([
    ..._merchantHeader(settings),
    const TicketSeparator(),
    const TicketText(
      'DOCUMENTO COMMERCIALE',
      align: TicketAlign.center,
      bold: true,
    ),
    const TicketText(
      'emesso per ANNULLAMENTO',
      align: TicketAlign.center,
      bold: true,
    ),
    const TicketText('Documento di riferimento:', align: TicketAlign.center),
    TicketText(
      'N. ${doc.voidsNumber ?? '-'}'
      '${doc.voidsIssuedAt == null ? '' : ' del ${_date(doc.voidsIssuedAt!)}'}',
      align: TicketAlign.center,
    ),
    const TicketSeparator(),
    ..._fiscalBody(order, settings),
    const TicketSeparator(),
    ..._fiscalFooter(doc),
    if (order.isDemo) TicketText(_l('it', 'demo'), align: TicketAlign.center),
    const TicketFeed(3),
    const TicketCut(),
  ]);
}
