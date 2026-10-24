import 'discount.dart';
import 'fiscal.dart';
import 'flow.dart';
import 'holiday.dart';
import 'order.dart';
import 'palette.dart';

/// Which implementation of a pluggable component to use, plus its options
/// (e.g. `{type: escposNetwork, options: {host: 192.168.1.50, port: 9100}}`).
class AdapterConfig {
  final String type;
  final Map<String, Object?> options;

  const AdapterConfig(this.type, [this.options = const {}]);

  static const none = AdapterConfig('none');
  static const demo = AdapterConfig('demo');

  factory AdapterConfig.fromJson(Object? json, AdapterConfig fallback) {
    if (json is! Map) return fallback;
    return AdapterConfig(
      json['type'] as String? ?? fallback.type,
      (json['options'] as Map? ?? const {}).cast<String, Object?>(),
    );
  }

  Map<String, Object?> toJson() => {'type': type, 'options': options};
}

final _secretOption = RegExp(
  r'password|pin|secret|apikey|token',
  caseSensitive: false,
);

class KioskSettings {
  final String venueName;

  /// Demo mode: payments and fiscal documents are simulated, stock is
  /// ignored and orders are flagged as demo. Lets the whole suite run on
  /// a PC or on a kiosk without any card terminal or fiscal printer.
  final bool demoMode;

  /// Languages offered on the kiosk, in display order.
  final List<String> languages;
  final String defaultLanguage;
  final String currencySymbol;

  /// Service modes offered; when only one is enabled the kiosk skips the
  /// "eat in / take away" question.
  final Set<ServiceMode> serviceModes;
  final FlowConfig flow;
  final bool stockTracking;
  final bool showAllergens;
  final bool showCalories;

  /// Seconds without interaction after which the kiosk resets.
  final int idleTimeoutSeconds;
  final int maxQuantityPerLine;

  /// When a kiosk payment fails, let the customer choose to pay at the
  /// till instead of abandoning the order.
  final bool counterFallback;

  /// Discount codes: whether they are accepted, and where and how.
  final DiscountSettings discounts;
  final AdapterConfig payment;
  final AdapterConfig fiscal;
  final AdapterConfig customerPrinter;
  final AdapterConfig kitchenPrinter;

  /// Printer at the till, for the fiscal documents of orders paid there.
  /// With `none` they come out of [customerPrinter].
  final AdapterConfig counterPrinter;

  /// Business details printed on the fiscal documents.
  final MerchantProfile merchant;

  /// PIN for the admin panel and the staff endpoints.
  final String adminPin;

  /// Id of the [ColorPalette] used by the kiosk and the staff app.
  final String palette;

  /// Holiday theme of the customer screens: [HolidayMode.none],
  /// [HolidayMode.auto] (from the calendar) or the id of a [HolidayTheme].
  final String holiday;

  const KioskSettings({
    this.venueName = 'Food Kiosk',
    this.demoMode = true,
    this.languages = const ['it', 'en'],
    this.defaultLanguage = 'it',
    this.currencySymbol = '€',
    this.serviceModes = const {ServiceMode.eatIn, ServiceMode.takeAway},
    this.flow = FlowConfig.payAtCounterKitchenAfterPayment,
    this.stockTracking = false,
    this.showAllergens = true,
    this.showCalories = true,
    this.idleTimeoutSeconds = 90,
    this.maxQuantityPerLine = 20,
    this.counterFallback = true,
    this.discounts = const DiscountSettings(),
    this.payment = AdapterConfig.demo,
    this.fiscal = AdapterConfig.none,
    this.customerPrinter = AdapterConfig.demo,
    this.kitchenPrinter = AdapterConfig.none,
    this.counterPrinter = AdapterConfig.none,
    this.merchant = const MerchantProfile(),
    this.adminPin = '1234',
    this.palette = 'classic',
    this.holiday = HolidayMode.none,
  });

  /// The holiday theme showing on [now], if any.
  HolidayTheme? holidayOn(DateTime now) => HolidayMode.resolve(holiday, now);

  /// The colours in use today: those of the holiday theme while one is
  /// showing, otherwise the venue palette.
  ColorPalette get colors => colorsOn(DateTime.now());

  ColorPalette colorsOn(DateTime now) =>
      holidayOn(now)?.palette ?? ColorPalette.byId(palette);

  /// Stock is only enforced in production mode.
  bool get enforcesStock => stockTracking && !demoMode;

  List<String> validate() {
    final errors = <String>[];
    if (languages.isEmpty) errors.add('At least one language is required.');
    if (!languages.contains(defaultLanguage)) {
      errors.add('The default language must be one of the enabled languages.');
    }
    if (serviceModes.isEmpty) {
      errors.add('At least one service mode is required.');
    }
    if (idleTimeoutSeconds < 15) {
      errors.add('The idle timeout must be at least 15 seconds.');
    }
    if (maxQuantityPerLine < 1) {
      errors.add('The maximum quantity per line must be at least 1.');
    }
    if (discounts.enabled && !discounts.onKiosk && !discounts.onCounter) {
      errors.add(
        'Discount codes are enabled but cannot be entered anywhere: '
        'enable typing or the reader on the kiosk, or the till.',
      );
    }
    if (adminPin.length < 4) errors.add('The admin PIN needs 4+ characters.');
    if (!ColorPalette.presets.any((p) => p.id == palette)) {
      errors.add('Unknown colour palette "$palette".');
    }
    if (!HolidayMode.isValid(holiday)) {
      errors.add('Unknown holiday theme "$holiday".');
    }
    for (final issue in flow.validate()) {
      if (issue.level == FlowIssueLevel.error) errors.add(issue.message);
    }
    if (!demoMode && flow.canPayOnKiosk && payment.type == 'none') {
      errors.add('Kiosk payment is enabled but no payment terminal is set.');
    }
    final usesFiscal = flow.rules.values.any(
      (a) => a.contains(FlowAction.issueFiscalDocument),
    );
    if (!demoMode && usesFiscal && fiscal.type == 'none') {
      errors.add(
        'The flow issues fiscal documents but no fiscal device is set.',
      );
    }
    // The suite prints these documents itself, so it needs the seller's
    // details; an RT has them in its own header.
    if (!demoMode && fiscal.type == 'adeOnline') {
      errors.addAll(merchant.validate());
    }
    final secret = fiscal.options.keys.where(_secretOption.hasMatch);
    if (secret.isNotEmpty) {
      errors.add(
        'Credentials ("${secret.first}") cannot be stored in the device '
        'options: enter them in the Agenzia delle Entrate section.',
      );
    }
    return errors;
  }

  factory KioskSettings.fromJson(Map<String, Object?> json) {
    const d = KioskSettings();
    return KioskSettings(
      venueName: json['venueName'] as String? ?? d.venueName,
      demoMode: json['demoMode'] as bool? ?? d.demoMode,
      languages: [
        for (final l in (json['languages'] as List? ?? d.languages))
          l as String,
      ],
      defaultLanguage: json['defaultLanguage'] as String? ?? d.defaultLanguage,
      currencySymbol: json['currencySymbol'] as String? ?? d.currencySymbol,
      serviceModes: json['serviceModes'] == null
          ? d.serviceModes
          : {
              for (final m in json['serviceModes'] as List)
                ?ServiceMode.tryParse(m as String),
            },
      flow: json['flow'] == null
          ? d.flow
          : FlowConfig.fromJson((json['flow'] as Map).cast()),
      stockTracking: json['stockTracking'] as bool? ?? d.stockTracking,
      showAllergens: json['showAllergens'] as bool? ?? d.showAllergens,
      showCalories: json['showCalories'] as bool? ?? d.showCalories,
      idleTimeoutSeconds:
          json['idleTimeoutSeconds'] as int? ?? d.idleTimeoutSeconds,
      maxQuantityPerLine:
          json['maxQuantityPerLine'] as int? ?? d.maxQuantityPerLine,
      counterFallback: json['counterFallback'] as bool? ?? d.counterFallback,
      discounts: json['discounts'] == null
          ? d.discounts
          : DiscountSettings.fromJson(json['discounts']),
      payment: AdapterConfig.fromJson(json['payment'], d.payment),
      fiscal: AdapterConfig.fromJson(json['fiscal'], d.fiscal),
      customerPrinter: AdapterConfig.fromJson(
        json['customerPrinter'],
        d.customerPrinter,
      ),
      kitchenPrinter: AdapterConfig.fromJson(
        json['kitchenPrinter'],
        d.kitchenPrinter,
      ),
      counterPrinter: AdapterConfig.fromJson(
        json['counterPrinter'],
        d.counterPrinter,
      ),
      merchant: MerchantProfile.fromJson(json['merchant']),
      adminPin: json['adminPin'] as String? ?? d.adminPin,
      palette: json['palette'] as String? ?? d.palette,
      holiday: json['holiday'] as String? ?? d.holiday,
    );
  }

  /// Full settings, for the admin panel.
  Map<String, Object?> toJson() => {
    ...toPublicJson(),
    'stockTracking': stockTracking,
    'payment': payment.toJson(),
    'fiscal': fiscal.toJson(),
    'customerPrinter': customerPrinter.toJson(),
    'kitchenPrinter': kitchenPrinter.toJson(),
    'counterPrinter': counterPrinter.toJson(),
    'merchant': merchant.toJson(),
    'adminPin': adminPin,
  };

  /// What the kiosk needs to know; no secrets or device addresses.
  Map<String, Object?> toPublicJson() => {
    'venueName': venueName,
    'demoMode': demoMode,
    'languages': languages,
    'defaultLanguage': defaultLanguage,
    'currencySymbol': currencySymbol,
    'serviceModes': [for (final m in serviceModes) m.name],
    'flow': flow.toJson(),
    'showAllergens': showAllergens,
    'showCalories': showCalories,
    'idleTimeoutSeconds': idleTimeoutSeconds,
    'maxQuantityPerLine': maxQuantityPerLine,
    'counterFallback': counterFallback,
    'discounts': discounts.toJson(),
    'palette': palette,
    'holiday': holiday,
  };
}
