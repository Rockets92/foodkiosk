import 'package:kiosk_core/kiosk_core.dart';

/// Issues the fiscal document (in Italy: "documento commerciale" through a
/// registratore telematico) for a paid order.
abstract class FiscalDevice {
  String get type;

  Future<FiscalDocument> issue(Order order);
}

class FiscalException implements Exception {
  final String message;
  FiscalException(this.message);
  @override
  String toString() => message;
}

/// Generates a fake, clearly marked document number.
class DemoFiscalDevice extends FiscalDevice {
  int _counter = 0;

  @override
  String get type => 'demo';

  @override
  Future<FiscalDocument> issue(Order order) async {
    _counter++;
    final now = DateTime.now();
    final day =
        '${now.year}${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}';
    return FiscalDocument(
      provider: type,
      number: 'DEMO-$day-${_counter.toString().padLeft(4, '0')}',
      issuedAt: now,
    );
  }
}

class NoFiscalDevice extends FiscalDevice {
  @override
  String get type => 'none';

  @override
  Future<FiscalDocument> issue(Order order) =>
      throw FiscalException('Nessun dispositivo fiscale configurato');
}
