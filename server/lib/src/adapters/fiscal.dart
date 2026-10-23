import 'package:kiosk_core/kiosk_core.dart';

/// Issues the fiscal document (in Italy the "documento commerciale") for a
/// paid order, through a registratore telematico or the Agenzia delle
/// Entrate's online procedure.
abstract class FiscalDevice {
  String get type;

  /// The device prints the document itself (an RT does). Otherwise the
  /// server prints it on the ticket printer from the returned data.
  bool get printsDocument => true;

  Future<FiscalDocument> issue(Order order);

  /// Issues the "documento commerciale di annullo" for the order's
  /// document.
  Future<FiscalDocument> voidDocument(Order order) => throw FiscalException(
    'Annullo non disponibile da qui: annulla il documento dal registratore',
  );

  /// Checks that the device or the account can issue documents; returns a
  /// short description of what was checked.
  Future<String> check() async => 'Nessuna verifica disponibile';
}

class FiscalException implements Exception {
  final String message;
  FiscalException(this.message);
  @override
  String toString() => message;
}

/// How the customer paid, as the fiscal document reports it: cash,
/// electronic (card, kiosk terminal) and, for the change, the cash handed
/// over.
class PaymentSplit {
  final Cents cashCents;
  final Cents electronicCents;
  final Cents? receivedCents;

  const PaymentSplit(this.cashCents, this.electronicCents, this.receivedCents);

  factory PaymentSplit.of(Order order) {
    final pay = order.payment;
    final total = order.totalCents;
    if (pay?.cashCents case final cash? when pay?.cardCents != null) {
      return PaymentSplit(cash, total - cash, pay!.receivedCents);
    }
    // "counter" is a till payment recorded without a method: cash, as the
    // register would take it.
    final cash = pay?.provider == 'cash' || pay?.provider == 'counter';
    return PaymentSplit(
      cash ? total : 0,
      cash ? 0 : total,
      cash ? pay?.receivedCents : null,
    );
  }

  Cents? get changeCents =>
      receivedCents == null ? null : receivedCents! - cashCents;
}

/// Generates a fake, clearly marked document. [printsDocument] follows the
/// device configured for production, so a demo shows the same tickets.
class DemoFiscalDevice extends FiscalDevice {
  @override
  final bool printsDocument;
  int _counter = 0;

  DemoFiscalDevice({this.printsDocument = false});

  @override
  String get type => 'demo';

  @override
  Future<FiscalDocument> issue(Order order) async => FiscalDocument(
    provider: type,
    number: _next(),
    issuedAt: DateTime.now(),
    deviceId: 'DEMO',
    printedByDevice: printsDocument,
    test: true,
    lotteryCode: order.fiscalCustomer.lotteryCode,
    customerTaxCode: order.fiscalCustomer.taxCode,
  );

  @override
  Future<FiscalDocument> voidDocument(Order order) async {
    final sale = order.fiscalDocument!;
    return FiscalDocument(
      provider: type,
      number: _next(),
      issuedAt: DateTime.now(),
      kind: FiscalDocumentKind.voiding,
      deviceId: 'DEMO',
      printedByDevice: printsDocument,
      test: true,
      voidsNumber: sale.number,
      voidsIssuedAt: sale.issuedAt,
    );
  }

  @override
  Future<String> check() async => 'Modalità demo: documenti simulati';

  String _next() {
    _counter++;
    return '0001-${_counter.toString().padLeft(4, '0')}';
  }
}

class NoFiscalDevice extends FiscalDevice {
  @override
  String get type => 'none';

  @override
  Future<FiscalDocument> issue(Order order) =>
      throw FiscalException('Nessun dispositivo fiscale configurato');
}
