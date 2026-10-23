import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiosk_app/src/state/cart.dart';
import 'package:kiosk_app/src/state/kiosk_controller.dart';
import 'package:kiosk_app/src/ui/kiosk_app.dart';
import 'package:kiosk_app/src/ui/theme.dart';
import 'package:kiosk_app/src/ui/widgets/pressable.dart';
import 'package:kiosk_core/kiosk_core.dart';

import 'fake_backend.dart';

Future<KioskController> pumpKiosk(
  WidgetTester tester,
  FakeBackend backend,
) async {
  tester.view.physicalSize = const Size(1080, 1920);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final controller = KioskController(backend);
  await controller.init();
  await tester.pumpWidget(
    KioskApp(controller: controller, onServerChanged: (_) async {}),
  );
  await tester.pump();
  return controller;
}

/// Lets transitions finish. The kiosk has animations that repeat forever
/// (attract screen, demo badge), so `pumpAndSettle` would never return.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> tapKey(WidgetTester tester, String key) async {
  await tester.ensureVisible(find.byKey(ValueKey(key)));
  await tester.pump();
  await tester.tap(find.byKey(ValueKey(key)));
  await settle(tester);
}

/// Attract -> eat in -> menu.
Future<void> goToMenu(WidgetTester tester) async {
  await tapKey(tester, 'attract');
  await tapKey(tester, 'mode-eatIn');
}

void main() {
  testWidgets('order and pay at the counter', (tester) async {
    final backend = FakeBackend();
    final k = await pumpKiosk(tester, backend);
    expect(find.byKey(const ValueKey('demo-badge')), findsOneWidget);

    await goToMenu(tester);
    await tapKey(tester, 'product-burger');
    expect(find.text('Glutine'), findsOneWidget);
    await tapKey(tester, 'option-bacon');
    await tapKey(tester, 'qty-plus');
    await tapKey(tester, 'add-to-cart');
    expect(k.cart.single.optionIds, ['bacon']);
    expect(find.text('15,00 €'), findsWidgets);

    await tapKey(tester, 'view-order');
    await tapKey(tester, 'submit-default');
    expect(find.byKey(const ValueKey('order-number')), findsOneWidget);
    expect(find.text('001'), findsOneWidget);
    expect(find.textContaining('paga in cassa'), findsOneWidget);
    expect(backend.requests.single.serviceMode, ServiceMode.eatIn);

    // The attract screen animates forever: pump instead of settling.
    await tapKey(tester, 'new-order');
    expect(k.step, KioskStep.attract);
    expect(k.cart, isEmpty);
  });

  testWidgets('required options block the add button until chosen', (
    tester,
  ) async {
    await pumpKiosk(tester, FakeBackend());
    await goToMenu(tester);
    await tapKey(tester, 'product-meal');
    final add = find.byKey(const ValueKey('add-to-cart'));
    expect(tester.widget<KButton>(add).onTap, isNull);
    await tapKey(tester, 'option-salad');
    expect(tester.widget<KButton>(add).onTap, isNotNull);
  });

  testWidgets('quick add skips the sheet unless a choice is required', (
    tester,
  ) async {
    final k = await pumpKiosk(tester, FakeBackend());
    await goToMenu(tester);
    await tapKey(tester, 'quick-add-burger');
    expect(find.byKey(const ValueKey('product-sheet')), findsNothing);
    expect(k.cart.single.productId, 'burger');
    expect(find.text('6,50 €'), findsWidgets);

    await tapKey(tester, 'quick-add-meal');
    expect(find.byKey(const ValueKey('product-sheet')), findsOneWidget);
    expect(k.cart, hasLength(1));
  });

  testWidgets('sold out products cannot be opened', (tester) async {
    final k = await pumpKiosk(tester, FakeBackend());
    await goToMenu(tester);
    await tapKey(tester, 'cat-drinks');
    expect(find.text('ESAURITO'), findsOneWidget);
    await tapKey(tester, 'product-water');
    expect(find.byKey(const ValueKey('product-sheet')), findsNothing);
    expect(k.cart, isEmpty);
  });

  testWidgets('declined card payment can move to the counter', (tester) async {
    final backend = FakeBackend(
      settings: const KioskSettings(flow: FlowConfig.fullService),
    )..paymentResults.add(false);
    await pumpKiosk(tester, backend);
    await goToMenu(tester);
    await tapKey(tester, 'cat-drinks');
    await tapKey(tester, 'product-cola');
    await tapKey(tester, 'add-to-cart');
    await tapKey(tester, 'view-order');
    expect(find.text('Conferma e paga'), findsOneWidget);
    await tapKey(tester, 'submit-default');

    expect(find.byKey(const ValueKey('payment-failed')), findsOneWidget);
    await tapKey(tester, 'pay-counter-instead');
    expect(find.text('001'), findsOneWidget);
    expect(find.textContaining('paga in cassa'), findsOneWidget);
  });

  testWidgets('customer chooses how to pay', (tester) async {
    final backend = FakeBackend(
      settings: const KioskSettings(
        flow: FlowConfig(
          paymentMode: PaymentMode.customerChoice,
          rules: {
            FlowEvent.submitted: [FlowAction.printCustomerTicket],
          },
        ),
      ),
    );
    await pumpKiosk(tester, backend);
    await goToMenu(tester);
    await tapKey(tester, 'cat-drinks');
    await tapKey(tester, 'product-cola');
    await tapKey(tester, 'add-to-cart');
    await tapKey(tester, 'view-order');
    await tapKey(tester, 'submit-default');
    await tapKey(tester, 'submit-kiosk');
    expect(backend.requests.single.paymentChoice, PaymentMode.kiosk);
    expect(find.textContaining('Pagamento riuscito'), findsOneWidget);
  });

  testWidgets('switching language translates menu and labels', (tester) async {
    await pumpKiosk(tester, FakeBackend());
    await tapKey(tester, 'attract');
    await tapKey(tester, 'lang-en');
    expect(find.text('Take away'), findsOneWidget);
    await tapKey(tester, 'mode-takeAway');
    expect(find.text('Burgers'), findsWidgets);
    expect(find.text('Pick something from the menu'), findsOneWidget);
  });

  testWidgets('an idle customer is asked, then the kiosk resets', (
    tester,
  ) async {
    final k = await pumpKiosk(
      tester,
      FakeBackend(settings: const KioskSettings(idleTimeoutSeconds: 30)),
    );
    await goToMenu(tester);
    k.addToCart(const CartLine(productId: 'cola'));
    await tester.pump();

    await tester.pump(const Duration(seconds: 31));
    expect(find.byKey(const ValueKey('idle-dialog')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('idle-continue')));
    await tester.pump();
    expect(find.byKey(const ValueKey('idle-dialog')), findsNothing);
    expect(k.step, KioskStep.menu);

    await tester.pump(const Duration(seconds: 31));
    await tester.pump(const Duration(seconds: 16));
    await tester.pump(const Duration(milliseconds: 500));
    expect(k.step, KioskStep.attract);
    expect(k.cart, isEmpty);
  });

  test('cart merges identical items and prices options', () async {
    final k = KioskController(FakeBackend());
    await k.init();
    k.addToCart(const CartLine(productId: 'meal', optionIds: ['l', 'fries']));
    k.addToCart(const CartLine(productId: 'meal', optionIds: ['fries', 'l']));
    k.addToCart(const CartLine(productId: 'meal', optionIds: ['m', 'fries']));
    expect(k.cart, hasLength(2));
    expect(k.cart.first.quantity, 2);
    expect(k.cartTotal, (990 + 80) * 2 + 990);
    k.setQuantity(1, 0);
    expect(k.cart, hasLength(1));
  });

  test('tickets left by the server come out of the totem printer', () async {
    final backend =
        FakeBackend(settings: const KioskSettings(flow: FlowConfig.fullService))
          ..receiptsPerReply = [
            Uint8List.fromList([0x1b, 0x40]),
          ];
    final printed = <Uint8List>[];
    var fail = false;
    final k = KioskController(
      backend,
      printReceipt: (t) async {
        if (fail) throw StateError('carta finita');
        printed.add(t);
      },
    );
    await k.init();
    k.addToCart(const CartLine(productId: 'cola'));
    await k.submit();
    await Future<void>.delayed(Duration.zero);
    // One with the order, one once paid on the totem.
    expect(printed, hasLength(2));
    expect(printed.first, [0x1b, 0x40]);
    expect(k.lastPrintError, isNull);

    fail = true;
    k.reset();
    k.addToCart(const CartLine(productId: 'cola'));
    await k.submit();
    await Future<void>.delayed(Duration.zero);
    expect(k.step, KioskStep.done, reason: 'a printer problem never blocks');
    expect(k.lastPrintError, contains('carta finita'));
  });

  group('discount codes', () {
    Future<void> type(WidgetTester tester, String code) async {
      for (final c in code.split('')) {
        await tester.tap(find.byKey(ValueKey('kb-$c')));
        await tester.pump();
      }
    }

    testWidgets('a code typed on the on-screen keyboard discounts the order', (
      tester,
    ) async {
      final backend = FakeBackend();
      final k = await pumpKiosk(tester, backend);
      await goToMenu(tester);
      k.addToCart(const CartLine(productId: 'cola', quantity: 5));
      await tester.pump();
      await tapKey(tester, 'view-order');

      await tapKey(tester, 'coupon-open');
      // Wrong code first: the field shakes and says why.
      await type(tester, 'NOPE');
      await tapKey(tester, 'coupon-apply');
      expect(find.byKey(const ValueKey('coupon-error')), findsOneWidget);
      expect(find.textContaining('non valido'), findsOneWidget);

      for (var i = 0; i < 4; i++) {
        await tester.tap(find.byKey(const ValueKey('kb-back')));
      }
      await type(tester, 'SCONTO10');
      await tester.tap(find.byKey(const ValueKey('coupon-apply')));
      await settle(tester);
      expect(find.byKey(const ValueKey('coupon-success')), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
      await settle(tester);

      expect(k.discountCents, 140);
      expect(find.byKey(const ValueKey('coupon-applied')), findsOneWidget);
      expect(find.text('-1,40 €'), findsWidgets);
      expect(find.text('12,60 €'), findsWidgets);

      await tapKey(tester, 'submit-default');
      expect(backend.requests.single.discountCode, 'SCONTO10');
      expect(k.order!.totalCents, 1260);
    });

    testWidgets('a free product goes into the cart with its badge', (
      tester,
    ) async {
      final k = await pumpKiosk(tester, FakeBackend());
      await goToMenu(tester);
      k.addToCart(const CartLine(productId: 'burger'));
      await tester.pump();
      await tapKey(tester, 'view-order');
      await k.applyCoupon('colagratis');
      await settle(tester);
      expect(k.cart.map((l) => l.productId), ['burger', 'cola']);
      expect(k.discountCents, 280);
      expect(find.byKey(const ValueKey('free-badge')), findsOneWidget);

      // Removing the product keeps the code but explains what is missing.
      k.setQuantity(1, 0);
      await settle(tester);
      expect(k.discountCents, 0);
      expect(find.textContaining('per averlo in omaggio'), findsOneWidget);
      await tapKey(tester, 'coupon-add-free');
      expect(k.discountCents, 280);
    });

    testWidgets('a minimum order is explained until reached', (tester) async {
      final k = await pumpKiosk(tester, FakeBackend());
      await goToMenu(tester);
      k.addToCart(const CartLine(productId: 'burger'));
      await tester.pump();
      await tapKey(tester, 'view-order');
      await k.applyCoupon('MENO5');
      await settle(tester);
      expect(find.textContaining('aggiungi ancora 13,50'), findsOneWidget);
      k.setQuantity(0, 4);
      await settle(tester);
      expect(k.discountCents, 500);
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('scanning a coupon on the attract screen starts the order', (
      tester,
    ) async {
      final k = await pumpKiosk(
        tester,
        FakeBackend(
          settings: const KioskSettings(
            discounts: DiscountSettings(scanner: true, manualEntry: false),
          ),
        ),
      );
      expect(find.byKey(const ValueKey('attract-scan')), findsOneWidget);
      for (final c in 'SCONTO10'.split('')) {
        await tester.sendKeyEvent(
          LogicalKeyboardKey(c.toLowerCase().codeUnitAt(0)),
          character: c,
        );
      }
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await settle(tester);
      expect(k.step, isNot(KioskStep.attract));
      expect(k.coupon?.code, 'SCONTO10');
      expect(find.byKey(const ValueKey('coupon-toast')), findsOneWidget);
      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets('slow typing is not taken for a scan', (tester) async {
      final k = await pumpKiosk(
        tester,
        FakeBackend(
          settings: const KioskSettings(
            discounts: DiscountSettings(scanner: true),
          ),
        ),
      );
      for (final c in 'SCONTO10'.split('')) {
        await tester.sendKeyEvent(
          LogicalKeyboardKey(c.toLowerCase().codeUnitAt(0)),
          character: c,
        );
        await tester.runAsync(
          () => Future.delayed(const Duration(milliseconds: 90)),
        );
      }
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump(const Duration(milliseconds: 300));
      expect(k.coupon, isNull);
      expect(k.step, KioskStep.attract);
    });

    testWidgets('with codes off nothing about coupons is shown', (
      tester,
    ) async {
      final k = await pumpKiosk(
        tester,
        FakeBackend(
          settings: const KioskSettings(
            discounts: DiscountSettings(enabled: false),
          ),
        ),
      );
      await goToMenu(tester);
      expect(find.byKey(const ValueKey('menu-coupon')), findsNothing);
      k.addToCart(const CartLine(productId: 'cola'));
      await tester.pump();
      await tapKey(tester, 'view-order');
      expect(find.byKey(const ValueKey('coupon-open')), findsNothing);
      expect(await k.applyCoupon('SCONTO10'), isFalse);
    });
  });

  testWidgets('the palette from the server restyles the kiosk live', (
    tester,
  ) async {
    final backend = FakeBackend(
      settings: const KioskSettings(palette: 'ocean'),
    );
    final k = await pumpKiosk(tester, backend);
    await goToMenu(tester);
    Color primary() => Theme.of(
      tester.element(find.byType(Scaffold).first),
    ).colorScheme.primary;
    expect(K.palette.id, 'ocean');
    expect(primary(), Color(ColorPalette.ocean.primary));

    backend.settingsValue = const KioskSettings(palette: 'berry');
    await k.reload();
    await settle(tester);
    expect(K.palette.id, 'berry');
    expect(primary(), Color(ColorPalette.berry.primary));
    expect(k.step, KioskStep.menu, reason: 'the customer keeps their place');
  });
}
