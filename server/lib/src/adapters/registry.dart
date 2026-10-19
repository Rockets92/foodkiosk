import 'package:kiosk_core/kiosk_core.dart';

import 'fiscal.dart';
import 'payment.dart';
import 'printer.dart';

typedef AdapterFactory<T> = T Function(Map<String, Object?> options);

/// Maps adapter type names (as stored in [KioskSettings]) to
/// implementations. A new terminal, printer or fiscal device is added by
/// registering one more factory; nothing else in the server changes.
class AdapterRegistry {
  final Map<String, AdapterFactory<PaymentTerminal>> payment = {
    'none': (_) => NoPaymentTerminal(),
    'demo': DemoPaymentTerminal.fromOptions,
  };

  final Map<String, AdapterFactory<FiscalDevice>> fiscal = {
    'none': (_) => NoFiscalDevice(),
    'demo': (_) => DemoFiscalDevice(),
  };

  final Map<String, AdapterFactory<TicketPrinter>> printer = {
    'none': (_) => NoPrinter(),
    'demo': (o) => DemoPrinter(width: (o['width'] as num?)?.toInt() ?? 42),
    'escposNetwork': EscPosNetworkPrinter.fromOptions,
  };

  T _build<T>(
    Map<String, AdapterFactory<T>> factories,
    AdapterConfig config,
    String kind,
  ) {
    final factory = factories[config.type];
    if (factory == null) {
      throw ArgumentError('Unknown $kind adapter "${config.type}"');
    }
    return factory(config.options);
  }

  PaymentTerminal buildPayment(AdapterConfig c) =>
      _build(payment, c, 'payment');
  FiscalDevice buildFiscal(AdapterConfig c) => _build(fiscal, c, 'fiscal');
  TicketPrinter buildPrinter(AdapterConfig c) => _build(printer, c, 'printer');

  Map<String, List<String>> describe() => {
    'payment': payment.keys.toList(),
    'fiscal': fiscal.keys.toList(),
    'printer': printer.keys.toList(),
  };
}
