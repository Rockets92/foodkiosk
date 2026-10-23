import 'localized_text.dart';
import 'money.dart';

/// What a discount code gives.
enum DiscountType {
  /// A percentage off the whole order.
  percent,

  /// A fixed amount off the whole order (never below zero).
  amount,

  /// One unit of a product for free (its base price; paid extras are
  /// still charged). The product must be in the order.
  freeProduct;

  static DiscountType? tryParse(String? code) {
    for (final t in values) {
      if (t.name == code) return t;
    }
    return null;
  }
}

/// Where discount codes are accepted and how the customer enters them.
/// Each venue picks what its hardware supports: a totem with a QR/barcode
/// reader, one with the on-screen keyboard only, or codes at the till only.
class DiscountSettings {
  /// Master switch: off hides every discount screen and refuses codes.
  final bool enabled;

  /// The customer can type a code on the totem's on-screen keyboard.
  final bool manualEntry;

  /// The totem has a QR/barcode reader (USB, in keyboard mode): scanning a
  /// coupon applies it at any point of the order.
  final bool scanner;

  /// The cashier can apply codes to orders at the till.
  final bool atCounter;

  const DiscountSettings({
    this.enabled = true,
    this.manualEntry = true,
    this.scanner = false,
    this.atCounter = true,
  });

  /// Whether customers can apply codes on the totem.
  bool get onKiosk => enabled && (manualEntry || scanner);

  /// Whether the cashier can apply codes at the till.
  bool get onCounter => enabled && atCounter;

  factory DiscountSettings.fromJson(Object? json) {
    const d = DiscountSettings();
    if (json is! Map) return d;
    return DiscountSettings(
      enabled: json['enabled'] as bool? ?? d.enabled,
      manualEntry: json['manualEntry'] as bool? ?? d.manualEntry,
      scanner: json['scanner'] as bool? ?? d.scanner,
      atCounter: json['atCounter'] as bool? ?? d.atCounter,
    );
  }

  Map<String, Object?> toJson() => {
    'enabled': enabled,
    'manualEntry': manualEntry,
    'scanner': scanner,
    'atCounter': atCounter,
  };
}

/// A discount code managed by the staff.
class DiscountCode {
  final String id;

  /// What the customer types or scans, see [normalize].
  final String code;

  /// Shown to the customer once applied ("Sconto benvenuto").
  final LocalizedText label;

  /// Internal note for the staff (campaign, who it was given to).
  final String note;
  final DiscountType type;

  /// 1-100, for [DiscountType.percent].
  final int percent;

  /// For [DiscountType.amount].
  final Cents amountCents;

  /// For [DiscountType.freeProduct].
  final String? productId;

  /// Minimum order (before the discount) for the code to apply; 0 = none.
  final Cents minOrderCents;

  /// How many orders may use the code; null = unlimited.
  final int? maxUses;

  /// Orders that used it so far (cancelled orders give their use back).
  final int usedCount;
  final DateTime? validFrom;
  final DateTime? validUntil;
  final bool enabled;

  const DiscountCode({
    required this.id,
    required this.code,
    required this.type,
    this.label = const LocalizedText.empty(),
    this.note = '',
    this.percent = 0,
    this.amountCents = 0,
    this.productId,
    this.minOrderCents = 0,
    this.maxUses,
    this.usedCount = 0,
    this.validFrom,
    this.validUntil,
    this.enabled = true,
  });

  static final _allowed = RegExp(r'^[A-Z0-9_-]{3,32}$');

  /// Codes are case-insensitive and ignore spaces. A scanned QR code may
  /// hold a link: its `code` query parameter (or last path segment) is
  /// the code.
  static String normalize(String raw) {
    var s = raw.trim();
    final uri = Uri.tryParse(s);
    if (uri != null && uri.hasScheme && uri.host.isNotEmpty) {
      s =
          uri.queryParameters['code'] ??
          uri.pathSegments.where((p) => p.isNotEmpty).lastOrNull ??
          s;
    }
    return s.replaceAll(RegExp(r'\s+'), '').toUpperCase();
  }

  static bool isValidCode(String code) => _allowed.hasMatch(code);

  int? get remainingUses =>
      maxUses == null ? null : (maxUses! - usedCount).clamp(0, maxUses!);

  bool get isExhausted => maxUses != null && usedCount >= maxUses!;

  /// Why the code cannot be used at [now] (`codeDisabled`,
  /// `codeNotYetValid`, `codeExpired`, `codeExhausted`), or null.
  String? unavailableReason(DateTime now) {
    if (!enabled) return 'codeDisabled';
    if (validFrom != null && now.isBefore(validFrom!)) {
      return 'codeNotYetValid';
    }
    if (validUntil != null && !now.isBefore(validUntil!)) return 'codeExpired';
    if (isExhausted) return 'codeExhausted';
    return null;
  }

  /// Applies the code to the order [lines]. The amount never exceeds the
  /// order total.
  DiscountResult evaluate(Iterable<DiscountableLine> lines) {
    final subtotal = lines.fold(0, (s, l) => s + l.totalCents);
    if (subtotal < minOrderCents) {
      return const DiscountResult.problem('minOrderNotReached');
    }
    final Cents value;
    switch (type) {
      case DiscountType.percent:
        value = (subtotal * percent / 100).round();
      case DiscountType.amount:
        value = amountCents;
      case DiscountType.freeProduct:
        final matching = [
          for (final l in lines)
            if (l.productId == productId && l.quantity > 0) l,
        ];
        if (matching.isEmpty) {
          return const DiscountResult.problem('freeProductMissing');
        }
        value = matching
            .map((l) => l.unitBaseCents)
            .reduce((a, b) => a > b ? a : b);
    }
    return DiscountResult(value.clamp(0, subtotal));
  }

  DiscountCode copyWith({int? usedCount}) => DiscountCode(
    id: id,
    code: code,
    type: type,
    label: label,
    note: note,
    percent: percent,
    amountCents: amountCents,
    productId: productId,
    minOrderCents: minOrderCents,
    maxUses: maxUses,
    usedCount: usedCount ?? this.usedCount,
    validFrom: validFrom,
    validUntil: validUntil,
    enabled: enabled,
  );

  /// Problems that prevent saving, in Italian for the staff app.
  List<String> validate() => [
    if (!isValidCode(code))
      'Il codice deve avere da 3 a 32 caratteri: lettere, numeri, - e _',
    if (type == DiscountType.percent && (percent < 1 || percent > 100))
      'La percentuale deve essere tra 1 e 100',
    if (type == DiscountType.amount && amountCents <= 0)
      'L\'importo dello sconto deve essere maggiore di zero',
    if (type == DiscountType.freeProduct &&
        (productId == null || productId!.isEmpty))
      'Scegli il prodotto in omaggio',
    if (minOrderCents < 0) 'L\'ordine minimo non può essere negativo',
    if (maxUses != null && maxUses! < 1)
      'Il limite di utilizzi deve essere almeno 1',
    if (validFrom != null &&
        validUntil != null &&
        !validUntil!.isAfter(validFrom!))
      'La fine validità deve essere dopo l\'inizio',
  ];

  factory DiscountCode.fromJson(Map<String, Object?> json) => DiscountCode(
    id: json['id'] as String? ?? '',
    code: normalize(json['code'] as String? ?? ''),
    type:
        DiscountType.tryParse(json['type'] as String?) ?? DiscountType.percent,
    label: LocalizedText.fromJson(json['label']),
    note: json['note'] as String? ?? '',
    percent: (json['percent'] as num?)?.toInt() ?? 0,
    amountCents: json['amountCents'] as int? ?? 0,
    productId: json['productId'] as String?,
    minOrderCents: json['minOrderCents'] as int? ?? 0,
    maxUses: json['maxUses'] as int?,
    usedCount: json['usedCount'] as int? ?? 0,
    validFrom: DateTime.tryParse(json['validFrom'] as String? ?? ''),
    validUntil: DateTime.tryParse(json['validUntil'] as String? ?? ''),
    enabled: json['enabled'] as bool? ?? true,
  );

  Map<String, Object?> toJson() => {
    ...toPublicJson(),
    'note': note,
    'maxUses': maxUses,
    'usedCount': usedCount,
    'validFrom': validFrom?.toUtc().toIso8601String(),
    'validUntil': validUntil?.toUtc().toIso8601String(),
    'enabled': enabled,
  };

  /// What a kiosk needs to show and price the code; no usage stats.
  Map<String, Object?> toPublicJson() => {
    'id': id,
    'code': code,
    'type': type.name,
    'label': label.toJson(),
    'percent': percent,
    'amountCents': amountCents,
    'productId': productId,
    'minOrderCents': minOrderCents,
  };
}

/// The part of an order line a discount looks at.
typedef DiscountableLine = ({
  String productId,
  int quantity,
  Cents unitBaseCents,
  Cents totalCents,
});

/// Outcome of [DiscountCode.evaluate]: the amount off, or why the code
/// does not apply to this order (`minOrderNotReached`,
/// `freeProductMissing`).
class DiscountResult {
  final Cents amountCents;
  final String? problem;

  const DiscountResult(this.amountCents) : problem = null;
  const DiscountResult.problem(this.problem) : amountCents = 0;

  bool get ok => problem == null;
}

/// A discount applied to an order, snapshotted so later edits of the code
/// don't change past orders.
class OrderDiscount {
  final String codeId;
  final String code;
  final LocalizedText label;
  final DiscountType type;
  final int percent;
  final String? productId;
  final Cents amountCents;

  const OrderDiscount({
    required this.codeId,
    required this.code,
    required this.type,
    required this.amountCents,
    this.label = const LocalizedText.empty(),
    this.percent = 0,
    this.productId,
  });

  factory OrderDiscount.of(DiscountCode c, Cents amount) => OrderDiscount(
    codeId: c.id,
    code: c.code,
    label: c.label,
    type: c.type,
    percent: c.percent,
    productId: c.productId,
    amountCents: amount,
  );

  factory OrderDiscount.fromJson(Map<String, Object?> json) => OrderDiscount(
    codeId: json['codeId'] as String? ?? '',
    code: json['code'] as String? ?? '',
    label: LocalizedText.fromJson(json['label']),
    type: DiscountType.tryParse(json['type'] as String?) ?? DiscountType.amount,
    percent: (json['percent'] as num?)?.toInt() ?? 0,
    productId: json['productId'] as String?,
    amountCents: json['amountCents'] as int? ?? 0,
  );

  Map<String, Object?> toJson() => {
    'codeId': codeId,
    'code': code,
    'label': label.toJson(),
    'type': type.name,
    'percent': percent,
    'productId': productId,
    'amountCents': amountCents,
  };
}
