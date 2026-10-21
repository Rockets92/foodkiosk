import 'allergen.dart';
import 'flow.dart';
import 'localized_text.dart';
import 'money.dart';

enum ServiceMode {
  eatIn,
  takeAway;

  static ServiceMode? tryParse(String code) {
    for (final m in values) {
      if (m.name == code) return m;
    }
    return null;
  }
}

/// Overall lifecycle; payment and kitchen progress are tracked separately
/// so that any combination required by the [FlowConfig] is representable.
enum OrderStatus {
  open,
  completed,
  cancelled;

  static OrderStatus parse(String code) =>
      values.firstWhere((s) => s.name == code, orElse: () => open);
}

enum PaymentStatus {
  /// Payment is not handled by the system for this order.
  notRequired,

  /// Waiting for payment at the till.
  awaitingCounter,

  /// Waiting for (or retrying) payment on the kiosk.
  awaitingKiosk,

  /// A kiosk payment is in progress on the terminal.
  processing,
  paid,
  failed,
  refunded;

  static PaymentStatus parse(String code) =>
      values.firstWhere((s) => s.name == code, orElse: () => notRequired);
}

/// Where the order was placed.
enum OrderOrigin {
  /// By the customer on a kiosk.
  kiosk,

  /// By the cashier in the staff app, for a customer at the till.
  counter;

  static OrderOrigin parse(String code) =>
      values.firstWhere((o) => o.name == code, orElse: () => kiosk);
}

enum KitchenStatus {
  /// Not (yet) sent to the kitchen.
  none,
  queued,
  preparing,
  ready,

  /// Handed over to the customer.
  collected;

  static KitchenStatus parse(String code) =>
      values.firstWhere((s) => s.name == code, orElse: () => none);
}

/// A chosen option, snapshotted at order time so later menu edits don't
/// change past orders.
class OrderLineOption {
  final String groupId;
  final String optionId;
  final LocalizedText name;
  final Cents priceDeltaCents;

  const OrderLineOption({
    required this.groupId,
    required this.optionId,
    required this.name,
    required this.priceDeltaCents,
  });

  factory OrderLineOption.fromJson(Map<String, Object?> json) =>
      OrderLineOption(
        groupId: json['groupId'] as String,
        optionId: json['optionId'] as String,
        name: LocalizedText.fromJson(json['name']),
        priceDeltaCents: json['priceDeltaCents'] as int? ?? 0,
      );

  Map<String, Object?> toJson() => {
    'groupId': groupId,
    'optionId': optionId,
    'name': name.toJson(),
    'priceDeltaCents': priceDeltaCents,
  };
}

class OrderLine {
  final String productId;
  final LocalizedText name;
  final int quantity;
  final Cents unitPriceCents;
  final double vatRate;
  final List<OrderLineOption> options;
  final List<Allergen> allergens;
  final String? note;

  const OrderLine({
    required this.productId,
    required this.name,
    required this.quantity,
    required this.unitPriceCents,
    this.vatRate = 10,
    this.options = const [],
    this.allergens = const [],
    this.note,
  });

  /// Price of one unit including options.
  Cents get unitTotalCents =>
      unitPriceCents + options.fold(0, (s, o) => s + o.priceDeltaCents);

  Cents get totalCents => unitTotalCents * quantity;

  factory OrderLine.fromJson(Map<String, Object?> json) => OrderLine(
    productId: json['productId'] as String,
    name: LocalizedText.fromJson(json['name']),
    quantity: json['quantity'] as int,
    unitPriceCents: json['unitPriceCents'] as int,
    vatRate: (json['vatRate'] as num? ?? 10).toDouble(),
    options: [
      for (final o in (json['options'] as List? ?? const []))
        OrderLineOption.fromJson((o as Map).cast()),
    ],
    allergens: [
      for (final a in (json['allergens'] as List? ?? const []))
        ?Allergen.tryParse(a as String),
    ],
    note: json['note'] as String?,
  );

  Map<String, Object?> toJson() => {
    'productId': productId,
    'name': name.toJson(),
    'quantity': quantity,
    'unitPriceCents': unitPriceCents,
    'vatRate': vatRate,
    'options': [for (final o in options) o.toJson()],
    'allergens': [for (final a in allergens) a.name],
    'note': note,
    'totalCents': totalCents,
  };
}

class PaymentInfo {
  final String provider;
  final String? transactionId;
  final String? authCode;
  final String? cardBrand;
  final String? maskedPan;
  final String? message;
  final DateTime at;

  /// At the till: the part paid in cash and by card (both set for a
  /// `mixed` payment), and the cash handed over, to work out the change.
  final Cents? cashCents;
  final Cents? cardCents;
  final Cents? receivedCents;

  const PaymentInfo({
    required this.provider,
    required this.at,
    this.transactionId,
    this.authCode,
    this.cardBrand,
    this.maskedPan,
    this.message,
    this.cashCents,
    this.cardCents,
    this.receivedCents,
  });

  /// Change given back for the cash part.
  Cents? get changeCents => receivedCents == null || cashCents == null
      ? null
      : receivedCents! - cashCents!;

  factory PaymentInfo.fromJson(Map<String, Object?> json) => PaymentInfo(
    provider: json['provider'] as String,
    at: DateTime.parse(json['at'] as String),
    transactionId: json['transactionId'] as String?,
    authCode: json['authCode'] as String?,
    cardBrand: json['cardBrand'] as String?,
    maskedPan: json['maskedPan'] as String?,
    message: json['message'] as String?,
    cashCents: json['cashCents'] as int?,
    cardCents: json['cardCents'] as int?,
    receivedCents: json['receivedCents'] as int?,
  );

  Map<String, Object?> toJson() => {
    'provider': provider,
    'at': at.toUtc().toIso8601String(),
    'transactionId': transactionId,
    'authCode': authCode,
    'cardBrand': cardBrand,
    'maskedPan': maskedPan,
    'message': message,
    'cashCents': ?cashCents,
    'cardCents': ?cardCents,
    'receivedCents': ?receivedCents,
  };
}

class FiscalDocument {
  final String provider;
  final String number;
  final DateTime issuedAt;

  const FiscalDocument({
    required this.provider,
    required this.number,
    required this.issuedAt,
  });

  factory FiscalDocument.fromJson(Map<String, Object?> json) => FiscalDocument(
    provider: json['provider'] as String,
    number: json['number'] as String,
    issuedAt: DateTime.parse(json['issuedAt'] as String),
  );

  Map<String, Object?> toJson() => {
    'provider': provider,
    'number': number,
    'issuedAt': issuedAt.toUtc().toIso8601String(),
  };
}

/// One entry of the order's audit trail.
class OrderEvent {
  final DateTime at;
  final String type;
  final String? detail;

  const OrderEvent({required this.at, required this.type, this.detail});

  factory OrderEvent.fromJson(Map<String, Object?> json) => OrderEvent(
    at: DateTime.parse(json['at'] as String),
    type: json['type'] as String,
    detail: json['detail'] as String?,
  );

  Map<String, Object?> toJson() => {
    'at': at.toUtc().toIso8601String(),
    'type': type,
    'detail': detail,
  };
}

class Order {
  final String id;

  /// Short number shown to the customer, restarts every day.
  final int number;
  final DateTime createdAt;
  final ServiceMode serviceMode;
  final String language;
  final List<OrderLine> lines;

  /// How this order is paid; resolved from the [FlowConfig] and, with
  /// [PaymentMode.customerChoice], from the customer's choice.
  final PaymentMode paymentMode;
  final OrderStatus status;
  final PaymentStatus paymentStatus;
  final KitchenStatus kitchenStatus;

  /// Created while the system was in demo mode: no real payment, no real
  /// fiscal document, no stock movement, excluded from reports.
  final bool isDemo;
  final OrderOrigin origin;
  final PaymentInfo? payment;
  final FiscalDocument? fiscalDocument;
  final List<OrderEvent> history;

  const Order({
    required this.id,
    required this.number,
    required this.createdAt,
    required this.serviceMode,
    required this.language,
    required this.lines,
    required this.paymentMode,
    this.status = OrderStatus.open,
    this.paymentStatus = PaymentStatus.notRequired,
    this.kitchenStatus = KitchenStatus.none,
    this.isDemo = false,
    this.origin = OrderOrigin.kiosk,
    this.payment,
    this.fiscalDocument,
    this.history = const [],
  });

  Cents get totalCents => lines.fold(0, (s, l) => s + l.totalCents);

  int get itemCount => lines.fold(0, (s, l) => s + l.quantity);

  /// VAT included in the total, grouped by rate (prices are VAT-inclusive).
  Map<double, Cents> get vatBreakdown {
    final result = <double, Cents>{};
    for (final l in lines) {
      final gross = l.totalCents;
      final vat = (gross - gross / (1 + l.vatRate / 100)).round();
      result[l.vatRate] = (result[l.vatRate] ?? 0) + vat;
    }
    return result;
  }

  String get displayNumber => number.toString().padLeft(3, '0');

  Order copyWith({
    ServiceMode? serviceMode,
    List<OrderLine>? lines,
    OrderStatus? status,
    PaymentStatus? paymentStatus,
    KitchenStatus? kitchenStatus,
    PaymentMode? paymentMode,
    PaymentInfo? payment,
    FiscalDocument? fiscalDocument,
    List<OrderEvent>? history,
  }) => Order(
    id: id,
    number: number,
    createdAt: createdAt,
    serviceMode: serviceMode ?? this.serviceMode,
    language: language,
    lines: lines ?? this.lines,
    paymentMode: paymentMode ?? this.paymentMode,
    status: status ?? this.status,
    paymentStatus: paymentStatus ?? this.paymentStatus,
    kitchenStatus: kitchenStatus ?? this.kitchenStatus,
    isDemo: isDemo,
    origin: origin,
    payment: payment ?? this.payment,
    fiscalDocument: fiscalDocument ?? this.fiscalDocument,
    history: history ?? this.history,
  );

  Order withEvent(String type, {String? detail, DateTime? at}) => copyWith(
    history: [
      ...history,
      OrderEvent(at: at ?? DateTime.now(), type: type, detail: detail),
    ],
  );

  factory Order.fromJson(Map<String, Object?> json) => Order(
    id: json['id'] as String,
    number: json['number'] as int,
    createdAt: DateTime.parse(json['createdAt'] as String),
    serviceMode:
        ServiceMode.tryParse(json['serviceMode'] as String) ??
        ServiceMode.eatIn,
    language: json['language'] as String? ?? 'it',
    lines: [
      for (final l in (json['lines'] as List? ?? const []))
        OrderLine.fromJson((l as Map).cast()),
    ],
    paymentMode:
        PaymentMode.tryParse(json['paymentMode'] as String? ?? '') ??
        PaymentMode.none,
    status: OrderStatus.parse(json['status'] as String? ?? ''),
    paymentStatus: PaymentStatus.parse(json['paymentStatus'] as String? ?? ''),
    kitchenStatus: KitchenStatus.parse(json['kitchenStatus'] as String? ?? ''),
    isDemo: json['isDemo'] as bool? ?? false,
    origin: OrderOrigin.parse(json['origin'] as String? ?? ''),
    payment: json['payment'] == null
        ? null
        : PaymentInfo.fromJson((json['payment'] as Map).cast()),
    fiscalDocument: json['fiscalDocument'] == null
        ? null
        : FiscalDocument.fromJson((json['fiscalDocument'] as Map).cast()),
    history: [
      for (final e in (json['history'] as List? ?? const []))
        OrderEvent.fromJson((e as Map).cast()),
    ],
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'number': number,
    'displayNumber': displayNumber,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'serviceMode': serviceMode.name,
    'language': language,
    'lines': [for (final l in lines) l.toJson()],
    'paymentMode': paymentMode.name,
    'status': status.name,
    'paymentStatus': paymentStatus.name,
    'kitchenStatus': kitchenStatus.name,
    'isDemo': isDemo,
    'origin': origin.name,
    'payment': payment?.toJson(),
    'fiscalDocument': fiscalDocument?.toJson(),
    'history': [for (final e in history) e.toJson()],
    'totalCents': totalCents,
  };
}

/// What the kiosk sends to create an order. Prices are never taken from
/// the client: the server re-prices everything from the menu.
class OrderRequest {
  final ServiceMode serviceMode;
  final String language;
  final List<OrderRequestLine> lines;

  /// Only used with [PaymentMode.customerChoice]: [PaymentMode.kiosk] or
  /// [PaymentMode.counter].
  final PaymentMode? paymentChoice;

  const OrderRequest({
    required this.serviceMode,
    required this.language,
    required this.lines,
    this.paymentChoice,
  });

  factory OrderRequest.fromJson(Map<String, Object?> json) => OrderRequest(
    serviceMode:
        ServiceMode.tryParse(json['serviceMode'] as String? ?? '') ??
        ServiceMode.eatIn,
    language: json['language'] as String? ?? 'it',
    lines: [
      for (final l in (json['lines'] as List? ?? const []))
        OrderRequestLine.fromJson((l as Map).cast()),
    ],
    paymentChoice: json['paymentChoice'] == null
        ? null
        : PaymentMode.tryParse(json['paymentChoice'] as String),
  );

  Map<String, Object?> toJson() => {
    'serviceMode': serviceMode.name,
    'language': language,
    'lines': [for (final l in lines) l.toJson()],
    'paymentChoice': paymentChoice?.name,
  };
}

class OrderRequestLine {
  final String productId;
  final int quantity;
  final List<String> optionIds;
  final String? note;

  const OrderRequestLine({
    required this.productId,
    this.quantity = 1,
    this.optionIds = const [],
    this.note,
  });

  factory OrderRequestLine.fromJson(Map<String, Object?> json) =>
      OrderRequestLine(
        productId: json['productId'] as String,
        quantity: json['quantity'] as int? ?? 1,
        optionIds: [
          for (final o in (json['optionIds'] as List? ?? const [])) o as String,
        ],
        note: json['note'] as String?,
      );

  Map<String, Object?> toJson() => {
    'productId': productId,
    'quantity': quantity,
    'optionIds': optionIds,
    'note': note,
  };
}
