/// Configurable order lifecycle.
///
/// Every venue works differently: some only want the kiosk to take the
/// order and print a ticket to pay at the till, others send it straight to
/// the kitchen, others want the kiosk to take card payments and issue the
/// receipt. Instead of hard-coding one of these, the server runs a small
/// rule table: "when [FlowEvent] happens, run these [FlowAction]s".
library;

/// How (and whether) the customer pays.
enum PaymentMode {
  /// The kiosk does not deal with payment at all (e.g. table service,
  /// staff canteen, pay elsewhere). The order is never marked paid.
  none,

  /// The customer pays at the till; staff marks the order paid.
  counter,

  /// The customer pays on the kiosk through the integrated card terminal.
  kiosk,

  /// The kiosk asks the customer to choose between [counter] and [kiosk].
  customerChoice;

  static PaymentMode? tryParse(String code) {
    for (final m in values) {
      if (m.name == code) return m;
    }
    return null;
  }
}

/// Points in the life of an order that can trigger actions.
enum FlowEvent {
  /// The customer confirmed the order on the kiosk.
  submitted,

  /// The payment succeeded (on the kiosk or marked paid at the till).
  paid,

  /// The kitchen marked the order ready for pickup.
  ready;

  static FlowEvent? tryParse(String code) {
    for (final e in values) {
      if (e.name == code) return e;
    }
    return null;
  }
}

/// Things the server can do when an event happens.
enum FlowAction {
  /// Print the customer ticket (order number, items, total, "pay at the
  /// till" note when unpaid) on the kiosk printer.
  printCustomerTicket,

  /// Print the order on the kitchen printer.
  printKitchenTicket,

  /// Show the order on the kitchen display.
  sendToKitchenDisplay,

  /// Issue the fiscal document (receipt) through the fiscal adapter.
  issueFiscalDocument,

  /// Show the order number on the customer pickup screen.
  announceOnPickupScreen;

  static FlowAction? tryParse(String code) {
    for (final a in values) {
      if (a.name == code) return a;
    }
    return null;
  }
}

enum FlowIssueLevel { error, warning, info }

class FlowIssue {
  final FlowIssueLevel level;
  final String code;
  final String message;

  const FlowIssue(this.level, this.code, this.message);

  factory FlowIssue.fromJson(Map<String, Object?> json) => FlowIssue(
    FlowIssueLevel.values.firstWhere(
      (l) => l.name == json['level'],
      orElse: () => FlowIssueLevel.info,
    ),
    json['code'] as String? ?? '',
    json['message'] as String? ?? '',
  );

  Map<String, Object?> toJson() => {
    'level': level.name,
    'code': code,
    'message': message,
  };

  @override
  String toString() => '${level.name}: $message';
}

class FlowConfig {
  final PaymentMode paymentMode;
  final Map<FlowEvent, List<FlowAction>> rules;

  const FlowConfig({required this.paymentMode, required this.rules});

  List<FlowAction> actionsFor(FlowEvent event) => rules[event] ?? const [];

  bool get canPayOnKiosk =>
      paymentMode == PaymentMode.kiosk ||
      paymentMode == PaymentMode.customerChoice;

  bool get canPayAtCounter =>
      paymentMode == PaymentMode.counter ||
      paymentMode == PaymentMode.customerChoice;

  /// Ready-made configurations the admin panel offers as a starting point.
  static const presets = <String, FlowConfig>{
    'orderOnly': orderOnly,
    'payAtCounterKitchenAfterPayment': payAtCounterKitchenAfterPayment,
    'payAtCounterKitchenImmediately': payAtCounterKitchenImmediately,
    'fullService': fullService,
  };

  /// Take the order and print a ticket: the customer brings it to the till.
  static const orderOnly = FlowConfig(
    paymentMode: PaymentMode.counter,
    rules: {
      FlowEvent.submitted: [FlowAction.printCustomerTicket],
    },
  );

  /// Ticket to the till; the kitchen starts once the cashier marks it paid.
  static const payAtCounterKitchenAfterPayment = FlowConfig(
    paymentMode: PaymentMode.counter,
    rules: {
      FlowEvent.submitted: [FlowAction.printCustomerTicket],
      FlowEvent.paid: [FlowAction.sendToKitchenDisplay],
      FlowEvent.ready: [FlowAction.announceOnPickupScreen],
    },
  );

  /// Ticket to the till and order straight to the kitchen.
  static const payAtCounterKitchenImmediately = FlowConfig(
    paymentMode: PaymentMode.counter,
    rules: {
      FlowEvent.submitted: [
        FlowAction.printCustomerTicket,
        FlowAction.sendToKitchenDisplay,
      ],
      FlowEvent.ready: [FlowAction.announceOnPickupScreen],
    },
  );

  /// Card payment on the kiosk, receipt, kitchen, pickup screen.
  static const fullService = FlowConfig(
    paymentMode: PaymentMode.kiosk,
    rules: {
      FlowEvent.paid: [
        FlowAction.issueFiscalDocument,
        FlowAction.printCustomerTicket,
        FlowAction.sendToKitchenDisplay,
      ],
      FlowEvent.ready: [FlowAction.announceOnPickupScreen],
    },
  );

  /// Checks the configuration for combinations that would leave orders
  /// stuck or behave in a surprising way. Errors block saving.
  List<FlowIssue> validate() {
    final issues = <FlowIssue>[];
    final submitted = actionsFor(FlowEvent.submitted);
    final paid = actionsFor(FlowEvent.paid);
    final all = rules.values.expand((a) => a).toSet();

    for (final entry in rules.entries) {
      final seen = <FlowAction>{};
      for (final a in entry.value) {
        if (!seen.add(a)) {
          issues.add(
            FlowIssue(
              FlowIssueLevel.error,
              'duplicateAction',
              '"${a.name}" is listed twice for "${entry.key.name}".',
            ),
          );
        }
      }
    }

    if (submitted.contains(FlowAction.issueFiscalDocument) ||
        actionsFor(FlowEvent.ready).contains(FlowAction.issueFiscalDocument)) {
      issues.add(
        const FlowIssue(
          FlowIssueLevel.error,
          'fiscalBeforePayment',
          'The fiscal document can only be issued when the order is paid.',
        ),
      );
    }

    if (paymentMode == PaymentMode.none && paid.isNotEmpty) {
      issues.add(
        const FlowIssue(
          FlowIssueLevel.error,
          'unreachablePaid',
          'Payment is disabled, so actions on "paid" would never run.',
        ),
      );
    }

    final kitchenOnPaid =
        paid.contains(FlowAction.sendToKitchenDisplay) ||
        paid.contains(FlowAction.printKitchenTicket);
    final kitchenOnSubmit =
        submitted.contains(FlowAction.sendToKitchenDisplay) ||
        submitted.contains(FlowAction.printKitchenTicket);
    if (kitchenOnPaid && kitchenOnSubmit) {
      issues.add(
        const FlowIssue(
          FlowIssueLevel.warning,
          'kitchenTwice',
          'The kitchen receives the order both on submission and on payment.',
        ),
      );
    }

    if (!all.contains(FlowAction.sendToKitchenDisplay) &&
        actionsFor(FlowEvent.ready).isNotEmpty) {
      issues.add(
        const FlowIssue(
          FlowIssueLevel.warning,
          'readyWithoutKitchen',
          'No order reaches the kitchen display, so nobody can mark it ready.',
        ),
      );
    }

    if (paymentMode == PaymentMode.kiosk &&
        !submitted.contains(FlowAction.printCustomerTicket) &&
        !paid.contains(FlowAction.printCustomerTicket)) {
      issues.add(
        const FlowIssue(
          FlowIssueLevel.info,
          'noTicket',
          'The customer gets no printed ticket; the number is only on screen.',
        ),
      );
    }

    if (paymentMode == PaymentMode.counter ||
        paymentMode == PaymentMode.customerChoice) {
      if (!submitted.contains(FlowAction.printCustomerTicket)) {
        issues.add(
          const FlowIssue(
            FlowIssueLevel.warning,
            'counterNoTicket',
            'Customers paying at the till get no ticket to show the cashier.',
          ),
        );
      }
    }

    return issues;
  }

  bool get isValid => validate().every((i) => i.level != FlowIssueLevel.error);

  factory FlowConfig.fromJson(Map<String, Object?> json) => FlowConfig(
    paymentMode:
        PaymentMode.tryParse(json['paymentMode'] as String? ?? '') ??
        PaymentMode.counter,
    rules: {
      for (final e in (json['rules'] as Map? ?? const {}).entries)
        ?FlowEvent.tryParse(e.key as String): [
          for (final a in (e.value as List)) ?FlowAction.tryParse(a as String),
        ],
    },
  );

  Map<String, Object?> toJson() => {
    'paymentMode': paymentMode.name,
    'rules': {
      for (final e in rules.entries)
        e.key.name: [for (final a in e.value) a.name],
    },
  };
}
