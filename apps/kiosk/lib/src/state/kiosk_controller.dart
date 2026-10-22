import 'dart:async';

import 'package:flutter/foundation.dart' hide Category;
import 'package:kiosk_core/kiosk_core.dart';

import '../api/kiosk_backend.dart';
import 'cart.dart';

enum KioskStep { attract, start, menu, cart, payment, done }

enum LoadState { loading, ready, offline }

/// All the state of one customer session on the kiosk, from the attract
/// screen to the order number.
class KioskController extends ChangeNotifier {
  final KioskBackend backend;

  KioskController(this.backend);

  LoadState loadState = LoadState.loading;
  KioskSettings settings = const KioskSettings();
  Menu menu = const Menu();

  KioskStep step = KioskStep.attract;
  late String language = settings.defaultLanguage;
  ServiceMode serviceMode = ServiceMode.eatIn;
  String? selectedCategoryId;
  List<CartLine> cart = const [];

  /// The order once sent to the server.
  Order? order;

  /// True while waiting for the server (sending, paying).
  bool busy = false;

  /// Key of the error message to show, see `i18n.dart`.
  String? errorKey;

  /// The discount code applied to the cart, priced again on every change.
  DiscountCode? coupon;

  /// True while a code is being checked with the server.
  bool checkingCoupon = false;

  /// Why the last code typed or scanned was refused (`i18n.dart` key).
  String? couponErrorKey;

  /// Bumped on every code typed or scanned, so the UI can celebrate a
  /// success or shake on a refusal even when the same code comes twice.
  int couponAttempt = 0;

  StreamSubscription<ServerEvent>? _events;
  Timer? _retry;

  // ---------------------------------------------------------------------
  // Loading

  Future<void> init() async {
    await reload();
    _events = backend.events().listen((e) {
      if (e.type == ServerEvent.menuUpdated ||
          e.type == ServerEvent.settingsUpdated) {
        reload();
      }
    });
  }

  Future<void> reload() async {
    _retry?.cancel();
    try {
      final results = await Future.wait([backend.settings(), backend.menu()]);
      settings = results[0] as KioskSettings;
      menu = results[1] as Menu;
      loadState = LoadState.ready;
      if (!settings.languages.contains(language)) {
        language = settings.defaultLanguage;
      }
      _dropUnavailableFromCart();
      _ensureCategory();
      if (!discountsEnabled) coupon = null;
    } on BackendException {
      if (loadState != LoadState.ready) loadState = LoadState.offline;
      _retry = Timer(const Duration(seconds: 5), reload);
    }
    notifyListeners();
  }

  void _ensureCategory() {
    final cats = visibleCategories;
    if (cats.isEmpty) {
      selectedCategoryId = null;
    } else if (!cats.any((c) => c.id == selectedCategoryId)) {
      selectedCategoryId = cats.first.id;
    }
  }

  void _dropUnavailableFromCart() {
    cart = [
      for (final l in cart)
        if (menu.product(l.productId) case final p? when !p.soldOut) l,
    ];
  }

  // ---------------------------------------------------------------------
  // Menu helpers

  List<Category> get visibleCategories => [
    for (final c in menu.categories)
      if (c.visibleFor(serviceMode) && menu.productsIn(c.id).isNotEmpty) c,
  ]..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

  List<Product> get productsInSelectedCategory => selectedCategoryId == null
      ? const []
      : menu.productsIn(selectedCategoryId!);

  void selectCategory(String id) {
    selectedCategoryId = id;
    notifyListeners();
  }

  // ---------------------------------------------------------------------
  // Navigation

  /// Steps where an idle customer means an abandoned session.
  bool get idleSensitive =>
      step == KioskStep.start ||
      step == KioskStep.menu ||
      step == KioskStep.cart;

  void start() {
    if (loadState != LoadState.ready) return;
    final singleChoice =
        settings.serviceModes.length == 1 && settings.languages.length == 1;
    if (singleChoice) {
      serviceMode = settings.serviceModes.first;
      step = KioskStep.menu;
      _ensureCategory();
    } else {
      step = KioskStep.start;
    }
    notifyListeners();
  }

  void setLanguage(String code) {
    if (!settings.languages.contains(code)) return;
    language = code;
    notifyListeners();
  }

  void chooseServiceMode(ServiceMode mode) {
    serviceMode = mode;
    _ensureCategory();
    step = KioskStep.menu;
    notifyListeners();
  }

  void openCart() {
    step = KioskStep.cart;
    notifyListeners();
  }

  void backToMenu() {
    step = KioskStep.menu;
    errorKey = null;
    notifyListeners();
  }

  void clearError() {
    errorKey = null;
    notifyListeners();
  }

  // ---------------------------------------------------------------------
  // Cart

  int get itemCount => cart.fold(0, (s, l) => s + l.quantity);

  Cents lineTotal(CartLine line) {
    final p = menu.product(line.productId);
    return p == null ? 0 : unitPrice(menu, p, line.optionIds) * line.quantity;
  }

  Cents get cartTotal => cart.fold(0, (s, l) => s + lineTotal(l));

  // ---------------------------------------------------------------------
  // Discount codes

  bool get discountsEnabled => settings.discounts.onKiosk;

  /// The coupon applied to the current cart; `problem` tells why it does
  /// not apply (yet), e.g. the free product is not in the cart.
  DiscountResult? get couponResult {
    final c = coupon;
    if (c == null) return null;
    return c.evaluate([
      for (final l in cart)
        if (menu.product(l.productId) case final p?)
          (
            productId: l.productId,
            quantity: l.quantity,
            unitBaseCents: p.priceCents,
            totalCents: lineTotal(l),
          ),
    ]);
  }

  Cents get discountCents {
    final r = couponResult;
    return r != null && r.ok ? r.amountCents : 0;
  }

  /// What the customer pays: the cart minus the discount.
  Cents get payableTotal => cartTotal - discountCents;

  /// The product a "free product" coupon gives, if any.
  Product? get couponProduct {
    final c = coupon;
    if (c == null || c.type != DiscountType.freeProduct) return null;
    return menu.product(c.productId ?? '');
  }

  /// Checks [raw] with the server and applies it. A free product that
  /// needs no choices goes straight into the cart. Returns success.
  Future<bool> applyCoupon(String raw, {bool scanned = false}) async {
    if (!discountsEnabled || checkingCoupon) return false;
    final code = DiscountCode.normalize(raw);
    if (code.isEmpty) return false;
    // Scanning a coupon on the attract screen starts the order.
    if (step == KioskStep.attract) start();
    checkingCoupon = true;
    couponErrorKey = null;
    notifyListeners();
    try {
      final found = await backend.checkDiscount(code);
      coupon = found;
      final free = couponProduct;
      if (free != null &&
          !free.soldOut &&
          !cart.any((l) => l.productId == free.id) &&
          !free.modifierGroupIds
              .map(menu.modifierGroup)
              .any((g) => g != null && g.required)) {
        cart = [
          ...cart,
          CartLine(productId: free.id, optionIds: defaultOptions(menu, free)),
        ];
      }
    } on BackendException catch (e) {
      couponErrorKey = _couponErrorKeyFor(e);
    }
    checkingCoupon = false;
    couponAttempt++;
    notifyListeners();
    return couponErrorKey == null;
  }

  void removeCoupon() {
    coupon = null;
    couponErrorKey = null;
    notifyListeners();
  }

  void clearCouponError() {
    if (couponErrorKey == null) return;
    couponErrorKey = null;
    notifyListeners();
  }

  String _couponErrorKeyFor(BackendException e) {
    if (e.isNetwork) return 'errorNetwork';
    return switch (e.code) {
      'codeNotFound' => 'couponNotFound',
      'codeExpired' => 'couponExpired',
      'codeNotYetValid' => 'couponNotYetValid',
      'codeExhausted' => 'couponExhausted',
      'codeDisabled' => 'couponNotFound',
      'tooManyAttempts' => 'couponTooMany',
      'discountsDisabled' => 'couponUnavailable',
      'minOrderNotReached' => 'couponMinOrder',
      'freeProductMissing' => 'couponFreeMissing',
      _ => 'errorGeneric',
    };
  }

  static const _couponErrors = {
    'codeNotFound',
    'codeExpired',
    'codeNotYetValid',
    'codeExhausted',
    'codeDisabled',
    'discountsDisabled',
    'minOrderNotReached',
    'freeProductMissing',
  };

  int get maxQuantity => settings.maxQuantityPerLine;

  void addToCart(CartLine line) {
    final i = cart.indexWhere((l) => l.sameItemAs(line));
    if (i >= 0) {
      final merged = (cart[i].quantity + line.quantity).clamp(1, maxQuantity);
      cart = [...cart]..[i] = cart[i].copyWith(quantity: merged);
    } else {
      cart = [...cart, line];
    }
    notifyListeners();
  }

  void replaceLine(int index, CartLine line) {
    cart = [...cart]..[index] = line;
    notifyListeners();
  }

  void setQuantity(int index, int quantity) {
    if (quantity <= 0) {
      cart = [...cart]..removeAt(index);
    } else {
      cart = [...cart]
        ..[index] = cart[index].copyWith(
          quantity: quantity.clamp(1, maxQuantity),
        );
    }
    notifyListeners();
  }

  // ---------------------------------------------------------------------
  // Submission and payment

  /// Payment modes the customer can pick at checkout; one entry means no
  /// question is asked.
  List<PaymentMode> get paymentOptions => switch (settings.flow.paymentMode) {
    PaymentMode.customerChoice => const [
      PaymentMode.kiosk,
      PaymentMode.counter,
    ],
    final m => [m],
  };

  Future<void> submit({PaymentMode? paymentChoice}) async {
    if (cart.isEmpty || busy) return;
    busy = true;
    errorKey = null;
    notifyListeners();
    try {
      order = await backend.createOrder(
        OrderRequest(
          serviceMode: serviceMode,
          language: language,
          lines: [for (final l in cart) l.toRequest()],
          paymentChoice: paymentChoice,
          discountCode: couponResult?.ok ?? false ? coupon!.code : null,
        ),
      );
      busy = false;
      if (order!.paymentStatus == PaymentStatus.awaitingKiosk) {
        step = KioskStep.payment;
        notifyListeners();
        await pay();
      } else {
        step = KioskStep.done;
        notifyListeners();
      }
    } on BackendException catch (e) {
      busy = false;
      errorKey = _errorKeyFor(e);
      if (_couponErrors.contains(e.code)) {
        // The code ran out (or changed) since it was applied.
        coupon = null;
        errorKey = 'couponNoLongerValid';
      }
      if (e.code == 'soldOut' ||
          e.code == 'insufficientStock' ||
          e.code == 'productUnavailable') {
        await reload();
      }
      notifyListeners();
    }
  }

  Future<void> pay() async {
    final current = order;
    if (current == null || busy) return;
    busy = true;
    errorKey = null;
    notifyListeners();
    try {
      order = await backend.pay(current.id);
    } on BackendException catch (e) {
      errorKey = _errorKeyFor(e);
      // The server may have recorded a result even if the reply was lost.
      try {
        order = await backend.order(current.id);
      } on BackendException {
        // keep what we have
      }
    }
    busy = false;
    if (order!.paymentStatus == PaymentStatus.paid) {
      errorKey = null;
      step = KioskStep.done;
    }
    notifyListeners();
  }

  bool get paymentFailed =>
      step == KioskStep.payment &&
      !busy &&
      order != null &&
      order!.paymentStatus != PaymentStatus.paid &&
      order!.paymentStatus != PaymentStatus.processing;

  bool get canPayAtCounterInstead =>
      settings.counterFallback || settings.flow.canPayAtCounter;

  Future<void> payAtCounterInstead() async {
    final current = order;
    if (current == null || busy) return;
    busy = true;
    notifyListeners();
    try {
      order = await backend.switchToCounter(current.id);
      errorKey = null;
      step = KioskStep.done;
    } on BackendException catch (e) {
      errorKey = _errorKeyFor(e);
    }
    busy = false;
    notifyListeners();
  }

  String _errorKeyFor(BackendException e) {
    if (e.isNetwork) return 'errorNetwork';
    return switch (e.code) {
      'soldOut' ||
      'insufficientStock' ||
      'productUnavailable' => 'errorSoldOut',
      _ => 'errorGeneric',
    };
  }

  // ---------------------------------------------------------------------
  // Reset

  /// Abandons the session. An order not yet paid is cancelled so that it
  /// does not wait forever at the till or in the kitchen.
  Future<void> cancelAndReset() async {
    final current = order;
    if (current != null &&
        step != KioskStep.done &&
        current.paymentStatus != PaymentStatus.paid) {
      try {
        await backend.cancel(current.id);
      } on BackendException {
        // Staff can still cancel it from the admin panel.
      }
    }
    reset();
  }

  void reset() {
    step = KioskStep.attract;
    language = settings.defaultLanguage;
    serviceMode = settings.serviceModes.isEmpty
        ? ServiceMode.eatIn
        : settings.serviceModes.first;
    cart = const [];
    order = null;
    busy = false;
    errorKey = null;
    coupon = null;
    checkingCoupon = false;
    couponErrorKey = null;
    selectedCategoryId = null;
    _ensureCategory();
    notifyListeners();
  }

  @override
  void dispose() {
    _events?.cancel();
    _retry?.cancel();
    backend.dispose();
    super.dispose();
  }
}
