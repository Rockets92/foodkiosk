import 'dart:async';
import 'dart:math';

import 'package:kiosk_core/kiosk_core.dart';

class PaymentResult {
  final bool approved;
  final PaymentInfo info;

  const PaymentResult({required this.approved, required this.info});
}

/// A card terminal (POS) able to charge an amount.
///
/// Real terminals (Nexi, Ingenico, SumUp, ...) each get their own
/// implementation registered in the adapter registry; the rest of the
/// system only sees this interface.
abstract class PaymentTerminal {
  String get type;

  Future<PaymentResult> charge({
    required String orderId,
    required Cents amountCents,
    required String reference,
  });

  /// Aborts a charge in progress, when the terminal supports it.
  Future<void> cancel(String orderId) async {}
}

/// Simulates a terminal: waits a bit and approves.
///
/// Options: `delayMs` (default 2500), `failureRate` 0..1 (default 0),
/// `declineCentsSuffix` e.g. "13" declines amounts ending in ,13 so the
/// failure path can be shown on demand during a demo.
class DemoPaymentTerminal extends PaymentTerminal {
  final Duration delay;
  final double failureRate;
  final String? declineCentsSuffix;
  final Random _random;

  DemoPaymentTerminal({
    this.delay = const Duration(milliseconds: 2500),
    this.failureRate = 0,
    this.declineCentsSuffix,
    Random? random,
  }) : _random = random ?? Random();

  factory DemoPaymentTerminal.fromOptions(Map<String, Object?> o) =>
      DemoPaymentTerminal(
        delay: Duration(milliseconds: (o['delayMs'] as num?)?.toInt() ?? 2500),
        failureRate: (o['failureRate'] as num?)?.toDouble() ?? 0,
        declineCentsSuffix: o['declineCentsSuffix'] as String?,
      );

  @override
  String get type => 'demo';

  @override
  Future<PaymentResult> charge({
    required String orderId,
    required Cents amountCents,
    required String reference,
  }) async {
    await Future<void>.delayed(delay);
    final suffix = declineCentsSuffix;
    final declined =
        (suffix != null &&
            amountCents.toString().padLeft(2, '0').endsWith(suffix)) ||
        _random.nextDouble() < failureRate;
    final now = DateTime.now();
    return PaymentResult(
      approved: !declined,
      info: PaymentInfo(
        provider: type,
        at: now,
        transactionId: 'DEMO-${now.millisecondsSinceEpoch}',
        authCode: declined
            ? null
            : (100000 + _random.nextInt(899999)).toString(),
        cardBrand: 'DEMO',
        maskedPan: '**** **** **** 4242',
        message: declined ? 'Pagamento rifiutato (demo)' : 'Approvato (demo)',
      ),
    );
  }
}

/// Used when no terminal is configured: every charge is refused.
class NoPaymentTerminal extends PaymentTerminal {
  @override
  String get type => 'none';

  @override
  Future<PaymentResult> charge({
    required String orderId,
    required Cents amountCents,
    required String reference,
  }) async => PaymentResult(
    approved: false,
    info: PaymentInfo(
      provider: type,
      at: DateTime.now(),
      message: 'Nessun terminale di pagamento configurato',
    ),
  );
}
