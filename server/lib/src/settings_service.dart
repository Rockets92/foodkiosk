import 'package:kiosk_core/kiosk_core.dart';

import 'adapters/fiscal.dart';
import 'adapters/payment.dart';
import 'adapters/printer.dart';
import 'adapters/registry.dart';
import 'errors.dart';
import 'event_bus.dart';
import 'repositories.dart';

/// Holds the current settings and the adapters built from them.
class SettingsService {
  final SettingsRepository _repo;
  final AdapterRegistry registry;
  final EventBus _bus;

  late KioskSettings _settings;
  late PaymentTerminal _payment;
  late FiscalDevice _fiscal;
  late TicketPrinter _customerPrinter;
  late TicketPrinter _kitchenPrinter;

  SettingsService(this._repo, this.registry, this._bus) {
    _apply(_repo.load());
  }

  KioskSettings get current => _settings;

  /// In demo mode payments and fiscal documents are always simulated,
  /// whatever device is configured. Printers stay as configured so a demo
  /// on the real kiosk still prints.
  PaymentTerminal get payment => _payment;
  FiscalDevice get fiscal => _fiscal;
  TicketPrinter get customerPrinter => _customerPrinter;
  TicketPrinter get kitchenPrinter => _kitchenPrinter;

  void _apply(KioskSettings s) {
    final payment = s.demoMode
        ? registry.buildPayment(
            s.payment.type == 'demo' ? s.payment : AdapterConfig.demo,
          )
        : registry.buildPayment(s.payment);
    final fiscal = s.demoMode
        ? registry.buildFiscal(AdapterConfig.demo)
        : registry.buildFiscal(s.fiscal);
    final customerPrinter = registry.buildPrinter(s.customerPrinter);
    final kitchenPrinter = registry.buildPrinter(s.kitchenPrinter);
    _settings = s;
    _payment = payment;
    _fiscal = fiscal;
    _customerPrinter = customerPrinter;
    _kitchenPrinter = kitchenPrinter;
  }

  KioskSettings update(KioskSettings next) {
    final errors = next.validate();
    if (errors.isNotEmpty) {
      throw ApiException.badRequest('invalidSettings', errors.first, {
        'errors': errors,
      });
    }
    try {
      _apply(next);
    } on ArgumentError catch (e) {
      throw ApiException.badRequest('invalidAdapter', '${e.message}');
    }
    _repo.save(next);
    _bus.emit(ServerEvent.settingsUpdated, next.toPublicJson());
    return next;
  }

  /// Persists the defaults on first start.
  void ensureInitialized() {
    if (!_repo.isInitialized) _repo.save(_settings);
  }
}
