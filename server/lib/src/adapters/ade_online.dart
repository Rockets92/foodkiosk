import 'package:kiosk_core/kiosk_core.dart';

import '../fiscal_account.dart';
import 'fiscal.dart';

/// "Documento commerciale online": the Agenzia delle Entrate's own
/// procedure (portal "Fatture e Corrispettivi") that records each sale and
/// sends the daily takings without a registratore telematico.
///
/// The Agenzia offers no public API for it: software reaches it through an
/// intermediary provider, which logs in with the venue's Fisconline
/// credentials. Each provider is a [DcOnlineProvider], chosen with the
/// `provider` option; the credentials come from the encrypted
/// [FiscalAccount], never from the options.
///
/// The Agenzia returns the document data but does not print it, so the
/// server prints the documento commerciale on the ticket printer.
class AdeOnlineFiscal extends FiscalDevice {
  final DcOnlineProvider provider;
  final FiscalAccount? account;
  final MerchantProfile merchant;

  AdeOnlineFiscal({
    required this.provider,
    required this.account,
    required this.merchant,
  });

  @override
  String get type => 'adeOnline';

  @override
  bool get printsDocument => false;

  AdeCredentials _credentials() {
    final c = account?.credentials;
    if (c == null) {
      throw FiscalException(
        'Account Agenzia delle Entrate non collegato: inserisci le '
        'credenziali Fisconline in Impostazioni',
      );
    }
    final problems = merchant.validate();
    if (problems.isNotEmpty) {
      throw FiscalException('Dati esercente incompleti: ${problems.first}');
    }
    return c;
  }

  Future<T> _call<T>(Future<T> Function(AdeCredentials c) body) async {
    final c = _credentials();
    try {
      final result = await body(c);
      account?.recordCheck(ok: true, message: 'Documento emesso');
      return result;
    } on FiscalException catch (e) {
      account?.recordCheck(ok: false, message: e.message);
      rethrow;
    }
  }

  @override
  Future<FiscalDocument> issue(Order order) => _call((c) async {
    final r = await provider.sale(DcSale.of(order), c, merchant);
    return _document(r, order);
  });

  @override
  Future<FiscalDocument> voidDocument(Order order) => _call((c) async {
    final sale = order.fiscalDocument!;
    final r = await provider.voidSale(sale, c, merchant);
    return _document(r, order, kind: FiscalDocumentKind.voiding, voids: sale);
  });

  FiscalDocument _document(
    DcResult r,
    Order order, {
    FiscalDocumentKind kind = FiscalDocumentKind.sale,
    FiscalDocument? voids,
  }) => FiscalDocument(
    provider: type,
    number: r.number,
    issuedAt: r.issuedAt,
    kind: kind,
    deviceId: r.deviceId,
    printedByDevice: false,
    test: provider.isTest,
    reference: r.reference,
    url: r.url,
    lotteryCode: kind == FiscalDocumentKind.sale
        ? order.fiscalCustomer.lotteryCode
        : null,
    customerTaxCode: kind == FiscalDocumentKind.sale
        ? order.fiscalCustomer.taxCode
        : null,
    voidsNumber: voids?.number,
    voidsIssuedAt: voids?.issuedAt,
  );

  @override
  Future<String> check() async {
    final c = _credentials();
    try {
      final message = await provider.verify(c, merchant);
      account?.recordCheck(ok: true, message: message);
      return message;
    } on FiscalException catch (e) {
      account?.recordCheck(ok: false, message: e.message);
      rethrow;
    }
  }
}

/// One line of the sale: VAT-inclusive prices, as on the document.
class DcItem {
  final String description;
  final int quantity;
  final Cents unitPriceCents;
  final double vatRate;

  const DcItem(
    this.description,
    this.quantity,
    this.unitPriceCents,
    this.vatRate,
  );

  Cents get totalCents => unitPriceCents * quantity;
}

/// A sale as the online procedure records it.
class DcSale {
  final String orderId;
  final int orderNumber;
  final List<DcItem> items;
  final Cents discountCents;
  final Cents totalCents;

  /// VAT included in the total, per rate.
  final Map<double, Cents> vat;
  final PaymentSplit payment;
  final FiscalCustomer customer;

  const DcSale({
    required this.orderId,
    required this.orderNumber,
    required this.items,
    required this.discountCents,
    required this.totalCents,
    required this.vat,
    required this.payment,
    this.customer = const FiscalCustomer(),
  });

  factory DcSale.of(Order order) => DcSale(
    orderId: order.id,
    orderNumber: order.number,
    items: [
      for (final l in order.lines)
        DcItem(documentDescription(l), l.quantity, l.unitTotalCents, l.vatRate),
    ],
    discountCents: order.discountCents,
    totalCents: order.totalCents,
    vat: order.vatBreakdown,
    payment: PaymentSplit.of(order),
    customer: order.fiscalCustomer,
  );

  /// The item and its paid extras, in Italian, as the document shows it.
  static String documentDescription(OrderLine l) {
    final extras = [
      for (final o in l.options)
        if (o.priceDeltaCents != 0) o.name.resolve('it'),
    ];
    final name = l.name.resolve('it');
    return extras.isEmpty ? name : '$name + ${extras.join(' + ')}';
  }
}

/// What the Agenzia returned for a document.
class DcResult {
  /// "zzzz-nnnn".
  final String number;
  final DateTime issuedAt;

  /// Id of the online procedure for this seller ("DCW2026/1234").
  final String? deviceId;

  /// The provider's id of the document, to void it later.
  final String? reference;
  final String? url;

  const DcResult({
    required this.number,
    required this.issuedAt,
    this.deviceId,
    this.reference,
    this.url,
  });
}

/// An intermediary that records documents in the Agenzia's online
/// procedure with the venue's credentials.
abstract class DcOnlineProvider {
  String get id;

  /// Test environment: documents are not sent to the Agenzia.
  bool get isTest;

  /// Logs in with the credentials; returns what was checked.
  Future<String> verify(AdeCredentials c, MerchantProfile merchant);

  Future<DcResult> sale(DcSale sale, AdeCredentials c, MerchantProfile m);

  Future<DcResult> voidSale(
    FiscalDocument original,
    AdeCredentials c,
    MerchantProfile m,
  );
}

/// Simulates the Agenzia: same checks on the data and the credentials,
/// numbered test documents, nothing sent anywhere. For trying the whole
/// flow, printed documents included, before a provider contract.
///
/// The password `errata` is refused, to try the error path.
class SandboxDcProvider extends DcOnlineProvider {
  final DateTime Function() _clock;
  int _counter = 0;

  SandboxDcProvider({DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  @override
  String get id => 'sandbox';

  @override
  bool get isTest => true;

  void _login(AdeCredentials c) {
    if (c.password == 'errata') {
      throw FiscalException(
        'Agenzia delle Entrate (prova): credenziali Fisconline rifiutate',
      );
    }
  }

  @override
  Future<String> verify(AdeCredentials c, MerchantProfile merchant) async {
    _login(c);
    return 'Ambiente di prova: credenziali e dati esercente corretti '
        '(P.IVA ${merchant.vatNumber})';
  }

  @override
  Future<DcResult> sale(
    DcSale sale,
    AdeCredentials c,
    MerchantProfile m,
  ) async {
    _login(c);
    if (sale.totalCents <= 0) {
      throw FiscalException('Documento con totale a zero non ammesso');
    }
    if (sale.customer.lotteryCode != null &&
        sale.payment.electronicCents == 0) {
      throw FiscalException(
        'Il codice lotteria vale solo per i pagamenti elettronici',
      );
    }
    return _next();
  }

  @override
  Future<DcResult> voidSale(
    FiscalDocument original,
    AdeCredentials c,
    MerchantProfile m,
  ) async {
    _login(c);
    if (original.reference == null) {
      throw FiscalException('Documento da annullare senza riferimento');
    }
    return _next();
  }

  DcResult _next() {
    _counter++;
    final now = _clock();
    final day = now.difference(DateTime(now.year)).inDays + 1;
    return DcResult(
      number:
          '${day.toString().padLeft(4, '0')}-'
          '${_counter.toString().padLeft(4, '0')}',
      issuedAt: now,
      deviceId: 'DCW${now.year}/PROVA',
      reference: 'sandbox-${now.microsecondsSinceEpoch}-$_counter',
    );
  }
}
