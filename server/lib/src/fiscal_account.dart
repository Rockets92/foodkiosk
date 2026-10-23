import 'package:kiosk_core/kiosk_core.dart';

import 'database.dart';
import 'errors.dart';
import 'secrets.dart';

/// Fisconline credentials of the Agenzia delle Entrate account the
/// documents are issued with, plus the API keys of the provider that
/// talks to the Agenzia on the venue's behalf.
class AdeCredentials {
  /// Codice fiscale of the Fisconline user.
  final String taxCode;
  final String password;

  /// The full 10-digit Fisconline PIN.
  final String pin;

  /// Keys of the intermediary provider (`apiKey`, `apiSecret`), if it
  /// needs any.
  final Map<String, String> providerKeys;

  /// When the password was last entered here: Fisconline passwords expire
  /// every 90 days.
  final DateTime updatedAt;

  const AdeCredentials({
    required this.taxCode,
    required this.password,
    required this.pin,
    required this.updatedAt,
    this.providerKeys = const {},
  });
}

/// The venue's Agenzia delle Entrate account, kept encrypted in the
/// [SecretStore]. The API only ever reports its status, never the values.
class FiscalAccount {
  final SecretStore _store;
  final AppDatabase _db;
  final DateTime Function() _clock;

  static const _entry = 'ade';
  static const _checkKey = 'fiscalCheck';

  /// Fisconline passwords last 90 days; renew from the 60th.
  static const passwordLifetime = Duration(days: 90);
  static const renewAfter = Duration(days: 60);

  FiscalAccount(this._store, this._db, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  /// The stored credentials, or null when not connected.
  AdeCredentials? get credentials {
    final v = _store.read(_entry);
    if (v == null) return null;
    return AdeCredentials(
      taxCode: v['taxCode'] ?? '',
      password: v['password'] ?? '',
      pin: v['pin'] ?? '',
      updatedAt: DateTime.tryParse(v['updatedAt'] ?? '') ?? _clock(),
      providerKeys: {
        for (final e in v.entries)
          if (e.key.startsWith('provider.')) e.key.substring(9): e.value,
      },
    );
  }

  /// Stores new credentials. Empty fields keep the stored value, so a
  /// password renewal only needs the new password.
  void save({
    String? taxCode,
    String? password,
    String? pin,
    Map<String, String> providerKeys = const {},
  }) {
    final old = credentials;
    String pick(String? v, String? previous) =>
        (v ?? '').trim().isEmpty ? previous ?? '' : v!.trim();
    final cf = pick(taxCode, old?.taxCode).replaceAll(' ', '').toUpperCase();
    final pwd = (password ?? '').isEmpty ? old?.password ?? '' : password!;
    final p = pick(pin, old?.pin).replaceAll(' ', '');
    Never bad(String code, String message) =>
        throw ApiException.badRequest(code, message);
    if (!TaxId.isValidTaxCode(cf)) {
      bad('invalidTaxCode', 'The Fisconline tax code is not valid.');
    }
    if (pwd.length < 8) {
      bad('invalidPassword', 'The Fisconline password has 8+ characters.');
    }
    if (!RegExp(r'^\d{10}$').hasMatch(p)) {
      bad('invalidPin', 'The Fisconline PIN is the full 10-digit code.');
    }
    final keys = {...?old?.providerKeys};
    for (final e in providerKeys.entries) {
      if (e.value.trim().isNotEmpty) keys[e.key] = e.value.trim();
    }
    final passwordChanged = old == null || pwd != old.password;
    _store.write(_entry, {
      'taxCode': cf,
      'password': pwd,
      'pin': p,
      'updatedAt': (passwordChanged ? _clock() : old.updatedAt)
          .toUtc()
          .toIso8601String(),
      for (final e in keys.entries) 'provider.${e.key}': e.value,
    });
    _db.deleteSetting(_checkKey);
  }

  void clear() {
    _store.delete(_entry);
    _db.deleteSetting(_checkKey);
  }

  /// Remembers the outcome of the last check or document, for the status.
  void recordCheck({required bool ok, required String message}) =>
      _db.writeSetting(_checkKey, {
        'ok': ok,
        'message': message,
        'at': _clock().toUtc().toIso8601String(),
      });

  /// What the staff app shows: never the credentials themselves.
  Map<String, Object?> status() {
    final c = credentials;
    final stored = _store.contains(_entry);
    final check = _db.readSetting(_checkKey);
    if (c == null) {
      return {
        'connected': false,
        // Stored but unreadable: the key file was replaced.
        'unreadable': stored,
      };
    }
    final expires = c.updatedAt.add(passwordLifetime);
    final daysLeft = expires.difference(_clock()).inDays;
    return {
      'connected': true,
      'taxCode': _mask(c.taxCode),
      'updatedAt': c.updatedAt.toUtc().toIso8601String(),
      'passwordExpiresAt': expires.toUtc().toIso8601String(),
      'daysLeft': daysLeft,
      'renewSoon': _clock().isAfter(c.updatedAt.add(renewAfter)),
      'expired': daysLeft < 0,
      'providerKeys': c.providerKeys.keys.toList(),
      'lastCheck': ?check,
    };
  }

  static String _mask(String v) => v.length < 5
      ? '****'
      : '${v.substring(0, 3)}${'*' * (v.length - 4)}${v[v.length - 1]}';
}
