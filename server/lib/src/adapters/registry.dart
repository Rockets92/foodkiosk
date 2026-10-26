import 'dart:convert';

import 'package:kiosk_core/kiosk_core.dart';

import '../fiscal_account.dart';
import 'ade_online.dart';
import 'epson_fiscal.dart';
import 'fiscal.dart';
import 'payment.dart';
import 'printer.dart';

typedef AdapterFactory<T> = T Function(Map<String, Object?> options);

/// What a fiscal device may need besides its options.
class FiscalContext {
  final MerchantProfile merchant;

  /// The encrypted Agenzia delle Entrate account, when the server has one.
  final FiscalAccount? account;

  const FiscalContext({this.merchant = const MerchantProfile(), this.account});
}

typedef FiscalFactory =
    FiscalDevice Function(Map<String, Object?> options, FiscalContext context);

/// Maps adapter type names (as stored in [KioskSettings]) to
/// implementations. A new terminal, printer or fiscal device is added by
/// registering one more factory; nothing else in the server changes.
class AdapterRegistry {
  final Map<String, AdapterFactory<PaymentTerminal>> payment = {
    'none': (_) => NoPaymentTerminal(),
    'demo': DemoPaymentTerminal.fromOptions,
  };

  late final Map<String, FiscalFactory> fiscal = {
    'none': (_, _) => NoFiscalDevice(),
    'demo': (_, _) => DemoFiscalDevice(),
    'epsonRt': (o, _) => EpsonFiscalPrinter.fromOptions(o),
    'adeOnline': (o, ctx) => AdeOnlineFiscal(
      provider: dcOnlineProvider('${o['provider'] ?? 'sandbox'}', o),
      account: ctx.account,
      merchant: ctx.merchant,
    ),
  };

  /// Intermediaries for the Agenzia's online procedure ("adeOnline"),
  /// by the `provider` option.
  final Map<String, AdapterFactory<DcOnlineProvider>> dcOnline = {
    'sandbox': (_) => SandboxDcProvider(),
  };

  /// Providers keep their state (numbering, login) across settings saves
  /// that leave their options alone.
  final _dcOnline = <String, DcOnlineProvider>{};

  DcOnlineProvider dcOnlineProvider(String id, Map<String, Object?> options) {
    final factory = dcOnline[id];
    if (factory == null) {
      throw ArgumentError('Unknown online fiscal provider "$id"');
    }
    return _dcOnline['$id ${jsonEncode(options)}'] ??= factory(options);
  }

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
  FiscalDevice buildFiscal(
    AdapterConfig c, [
    FiscalContext context = const FiscalContext(),
  ]) {
    final factory = fiscal[c.type];
    if (factory == null) {
      throw ArgumentError('Unknown fiscal adapter "${c.type}"');
    }
    return factory(c.options, context);
  }

  TicketPrinter buildPrinter(AdapterConfig c) => _build(printer, c, 'printer');

  Map<String, List<String>> describe() => {
    'payment': payment.keys.toList(),
    'fiscal': fiscal.keys.toList(),
    'dcOnline': dcOnline.keys.toList(),
    'printer': printer.keys.toList(),
  };
}
