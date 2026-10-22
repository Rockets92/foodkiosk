import 'package:kiosk_core/kiosk_core.dart';

import 'errors.dart';
import 'event_bus.dart';
import 'ids.dart';
import 'repositories.dart';
import 'settings_service.dart';

/// Where a code is being used: the totem or the till.
enum DiscountChannel { kiosk, counter }

/// Discount codes: staff management, and the checks the totem and the
/// till run before applying a code.
class DiscountService {
  final DiscountRepository _repo;
  final MenuRepository _menu;
  final SettingsService _settings;
  final EventBus _bus;
  final DateTime Function() _clock;

  /// Recent wrong codes per client, to stop guessing codes by brute force.
  final _misses = <String, List<DateTime>>{};
  static const _maxMisses = 10;
  static const _missWindow = Duration(minutes: 1);

  DiscountService(
    this._repo,
    this._menu,
    this._settings,
    this._bus, {
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  DiscountRepository get repository => _repo;

  // ---------------------------------------------------------------------
  // Staff management

  List<DiscountCode> all() => _repo.all();

  DiscountCode get(String id) =>
      _repo.byId(id) ?? (throw ApiException.notFound('Discount code'));

  DiscountCode save(Map<String, Object?> json, {String? id}) {
    final existing = id == null ? null : get(id);
    final code = DiscountCode.fromJson({
      ...json,
      'id': existing?.id ?? newId(),
    });
    final errors = code.validate();
    if (code.type == DiscountType.freeProduct &&
        code.productId != null &&
        _menu.product(code.productId!) == null) {
      errors.add('Il prodotto in omaggio non esiste più');
    }
    if (errors.isNotEmpty) {
      throw ApiException.badRequest('invalidDiscount', errors.first, {
        'errors': errors,
      });
    }
    final clash = _repo.byCode(code.code);
    if (clash != null && clash.id != code.id) {
      throw ApiException.conflict(
        'codeTaken',
        'Il codice ${code.code} esiste già',
      );
    }
    _repo.upsert(code);
    _changed();
    return get(code.id);
  }

  void delete(String id) {
    if (!_repo.delete(id)) throw ApiException.notFound('Discount code');
    _changed();
  }

  DiscountCode resetUses(String id) {
    get(id);
    _repo.resetUses(id);
    _changed();
    return get(id);
  }

  void _changed() => _bus.emit(ServerEvent.discountsUpdated);

  // ---------------------------------------------------------------------
  // Checks

  /// The code a customer or cashier entered, if it can be used now.
  /// [client] identifies the caller for the brute-force limit.
  DiscountCode lookup(
    String raw, {
    required DiscountChannel channel,
    String client = '',
  }) {
    final s = _settings.current.discounts;
    final allowed = switch (channel) {
      DiscountChannel.kiosk => s.onKiosk,
      DiscountChannel.counter => s.onCounter,
    };
    if (!allowed) {
      throw ApiException.conflict(
        'discountsDisabled',
        'Discount codes are not accepted here.',
      );
    }
    final now = _clock();
    final misses = (_misses[client] ?? [])
      ..removeWhere((t) => now.difference(t) > _missWindow);
    if (misses.length >= _maxMisses) {
      throw ApiException(429, 'tooManyAttempts', 'Too many wrong codes.');
    }
    final code = _repo.byCode(DiscountCode.normalize(raw));
    if (code == null) {
      _misses[client] = misses..add(now);
      throw ApiException(404, 'codeNotFound', 'Unknown discount code.');
    }
    final reason = code.unavailableReason(now);
    if (reason != null) {
      throw ApiException.conflict(reason, 'The code cannot be used now.');
    }
    return code;
  }

  /// The discount [code] gives on [lines], or a 400 explaining why it
  /// does not apply.
  OrderDiscount apply(DiscountCode code, List<OrderLine> lines) {
    final result = code.evaluate(lines.map((l) => l.discountable));
    if (!result.ok) {
      throw ApiException.badRequest(
        result.problem!,
        'The code does not apply to this order.',
        {
          'code': code.code,
          if (code.productId != null) 'productId': code.productId,
          'minOrderCents': code.minOrderCents,
        },
      );
    }
    return OrderDiscount.of(code, result.amountCents);
  }

  /// Takes one use of the code; must run inside the order transaction.
  void claim(DiscountCode code) {
    if (!_repo.claim(code.id, code.maxUses)) {
      throw ApiException.conflict('codeExhausted', 'The code is used up.');
    }
    _changed();
  }

  void release(String codeId) {
    _repo.release(codeId);
    _changed();
  }
}
