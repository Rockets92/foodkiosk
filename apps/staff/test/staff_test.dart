import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiosk_core/kiosk_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:staff_app/src/session.dart';
import 'package:staff_app/src/ui/screens/pickup_screen.dart';
import 'package:staff_app/src/ui/shell.dart';
import 'package:staff_app/src/ui/staff_app.dart';
import 'package:staff_app/src/ui/theme.dart';

import 'fake_server.dart';

final server = Uri.parse('http://fake/');

void useDesktop(WidgetTester tester) {
  tester.view.physicalSize = const Size(1600, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// Lets transitions and entrance animations finish.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> tapKey(WidgetTester tester, String key) async {
  await tester.ensureVisible(find.byKey(ValueKey(key)));
  await tester.pump();
  await tester.tap(find.byKey(ValueKey(key)));
  await settle(tester);
}

Future<void> openShell(
  WidgetTester tester,
  FakeServer fake,
  Section section,
) async {
  useDesktop(tester);
  final session = await StaffSession.open(fake.api(server, '1234'));
  addTearDown(session.dispose);
  await tester.pumpWidget(
    MaterialApp(
      theme: staffTheme(ColorPalette.fallback),
      home: StaffScope(
        session: session,
        child: StaffShell(onLogout: () {}, initial: section),
      ),
    ),
  );
  await settle(tester);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('a wrong PIN is refused, the right one opens the cashier', (
    tester,
  ) async {
    useDesktop(tester);
    final fake = FakeServer()..orders = [makeOrder(1)];
    await tester.pumpWidget(StaffApp(apiFactory: fake.api));
    await settle(tester);

    for (final k in '9999'.split('')) {
      await tapKey(tester, 'key-$k');
    }
    await tapKey(tester, 'login');
    expect(find.byKey(const ValueKey('login-error')), findsOneWidget);

    for (final k in '1234'.split('')) {
      await tapKey(tester, 'key-$k');
    }
    await tapKey(tester, 'login');
    expect(find.byKey(const ValueKey('nav-orders')), findsOneWidget);
    expect(find.byKey(const ValueKey('order-row-1')), findsOneWidget);
  });

  testWidgets('the cashier takes a cash payment', (tester) async {
    final fake = FakeServer()..orders = [makeOrder(7)];
    await openShell(tester, fake, Section.orders);
    await tapKey(tester, 'order-row-7');
    await tapKey(tester, 'pay-open');
    for (final k in '1000'.split('')) {
      await tapKey(tester, 'pay-key-$k');
    }
    expect(find.text('Mancano 5,00 €'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const ValueKey('pay-confirm')))
          .onPressed,
      isNull,
    );
    await tapKey(tester, 'pay-key-C');
    for (final k in '2000'.split('')) {
      await tapKey(tester, 'pay-key-$k');
    }
    expect(find.text('5,00 €'), findsOneWidget, reason: 'change');
    await tapKey(tester, 'pay-confirm');
    expect(fake.requests, contains('POST /api/staff/orders/o7/mark-paid'));
    final paid = fake.orders.single;
    expect(paid.paymentStatus, PaymentStatus.paid);
    expect(paid.payment?.receivedCents, 2000);
  });

  testWidgets('a failed print can be retried', (tester) async {
    final fake = FakeServer()
      ..orders = [
        makeOrder(
          3,
          payment: PaymentStatus.paid,
          history: [
            OrderEvent(
              at: DateTime.now(),
              type: 'actionFailed',
              detail: 'printCustomerTicket: printer offline',
            ),
          ],
        ),
      ];
    await openShell(tester, fake, Section.orders);
    await tapKey(tester, 'order-row-3');
    await tapKey(tester, 'retry-printCustomerTicket');
    expect(
      fake.requests,
      contains('POST /api/staff/orders/o3/actions/printCustomerTicket'),
    );
  });

  testWidgets('kitchen tickets move to ready', (tester) async {
    final fake = FakeServer()
      ..orders = [makeOrder(12, kitchen: KitchenStatus.queued)];
    await openShell(tester, fake, Section.kitchen);
    expect(find.text('Bacon'), findsOneWidget);
    await tapKey(tester, 'advance-12');
    expect(fake.orders.single.kitchenStatus, KitchenStatus.preparing);
    await tapKey(tester, 'advance-12');
    expect(fake.orders.single.kitchenStatus, KitchenStatus.ready);
  });

  testWidgets('the pickup screen shows ready numbers', (tester) async {
    useDesktop(tester);
    final fake = FakeServer()
      ..orders = [
        makeOrder(4, kitchen: KitchenStatus.preparing),
        makeOrder(5, kitchen: KitchenStatus.ready),
      ];
    await tester.pumpWidget(
      MaterialApp(home: PickupScreen(api: fake.api(server, ''))),
    );
    await settle(tester);
    expect(find.text('004'), findsOneWidget);
    expect(find.text('005'), findsOneWidget);
    // The screen polls: stop it before the test ends.
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('settings: a flow change is validated and saved', (tester) async {
    final fake = FakeServer();
    await openShell(tester, fake, Section.settings);
    await tapKey(tester, 'rule-submitted-sendToKitchenDisplay');
    await tester.pump(const Duration(seconds: 1));
    await settle(tester);
    // Kitchen on submission and on payment: the server warns about it.
    expect(fake.requests, contains('POST /api/admin/flow/validate'));
    await tapKey(tester, 'save-settings');
    expect(
      fake.settings.flow.actionsFor(FlowEvent.submitted),
      contains(FlowAction.sendToKitchenDisplay),
    );
    // The network section polls: stop it before the test ends.
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('settings: the network section shows the server address', (
    tester,
  ) async {
    final fake = FakeServer();
    await openShell(tester, fake, Section.settings);
    await tester.ensureVisible(find.text('Rete').last);
    await settle(tester);
    expect(
      find.byKey(const ValueKey('address-http://192.168.1.20:80')),
      findsOneWidget,
    );
    expect(find.text('Collegati ora (1)'), findsOneWidget);
    expect(find.text('Totem'), findsOneWidget);
    expect(find.text('192.168.1.31'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('settings: a colour palette is picked and saved', (tester) async {
    final fake = FakeServer();
    await openShell(tester, fake, Section.settings);
    for (final p in ColorPalette.presets) {
      expect(find.byKey(ValueKey('palette-${p.id}')), findsOneWidget);
    }
    await tapKey(tester, 'palette-midnight');
    await tapKey(tester, 'save-settings');
    expect(fake.settings.palette, 'midnight');
  });

  testWidgets('menu: a product can be marked sold out', (tester) async {
    final fake = FakeServer();
    await openShell(tester, fake, Section.menu);
    expect(find.byKey(const ValueKey('product-tile-burger')), findsOneWidget);
    await tapKey(tester, 'product-available-burger');
    expect(fake.menu.product('burger')!.soldOut, isTrue);
  });

  testWidgets('the cashier enters an order and cashes it', (tester) async {
    final fake = FakeServer();
    await openShell(tester, fake, Section.orders);

    await tapKey(tester, 'orders-new');
    expect(find.byKey(const ValueKey('new-order')), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const ValueKey('new-order-pay')))
          .onPressed,
      isNull,
      reason: 'nothing to cash yet',
    );

    await tapKey(tester, 'new-order-product-burger');
    await tapKey(tester, 'option-bacon');
    await tapKey(tester, 'options-add');
    await tapKey(tester, 'line-plus');
    expect(find.text('15,00 €'), findsWidgets);

    await tapKey(tester, 'new-order-cat-drinks');
    await tapKey(tester, 'new-order-product-cola');
    await tapKey(tester, 'new-order-pay');
    await tapKey(tester, 'pay-method-mixed');
    for (final k in '500'.split('')) {
      await tapKey(tester, 'pay-key-$k');
    }
    await tapKey(tester, 'pay-confirm');

    final order = fake.orders.single;
    expect(order.origin, OrderOrigin.counter);
    expect(order.payment?.provider, 'mixed');
    expect(order.payment?.cashCents, 500);
    expect(order.payment?.cardCents, 1500 + 280 - 500);
    expect(order.lines.first.quantity, 2);
    expect(order.lines.first.options.single.optionId, 'bacon');
    expect(order.lines.last.productId, 'cola');
    expect(find.byKey(const ValueKey('new-order')), findsNothing);
    expect(find.byKey(ValueKey('order-row-${order.number}')), findsOneWidget);
  });

  testWidgets('kitchen and pickup are hidden when the flow does not use them', (
    tester,
  ) async {
    final fake = FakeServer()
      ..settings = const KioskSettings(flow: FlowConfig.orderOnly);
    await openShell(tester, fake, Section.kitchen);
    expect(find.byKey(const ValueKey('nav-kitchen')), findsNothing);
    expect(find.byKey(const ValueKey('nav-pickup')), findsNothing);
    expect(find.byKey(const ValueKey('orders')), findsOneWidget);
  });

  testWidgets('an unpaid order can be saved, then extended before paying', (
    tester,
  ) async {
    final fake = FakeServer();
    await openShell(tester, fake, Section.orders);
    await tapKey(tester, 'orders-new');
    await tapKey(tester, 'new-order-cat-drinks');
    await tapKey(tester, 'new-order-product-cola');
    await tapKey(tester, 'new-order-save');
    final saved = fake.orders.single;
    expect(saved.paymentStatus, PaymentStatus.awaitingCounter);

    await tapKey(tester, 'edit-order');
    expect(find.text('Ordine ${saved.number}'), findsOneWidget);
    await tapKey(tester, 'line-plus');
    await tapKey(tester, 'new-order-pay');
    await tapKey(tester, 'pay-method-card');
    await tapKey(tester, 'pay-confirm');

    final paid = fake.orders.single;
    expect(paid.lines.single.quantity, 2);
    expect(paid.paymentStatus, PaymentStatus.paid);
    expect(paid.payment?.provider, 'card');
  });

  group('discount codes', () {
    testWidgets('the list shows uses and a new code can be created', (
      tester,
    ) async {
      final fake = FakeServer();
      await openShell(tester, fake, Section.discounts);
      expect(find.byKey(const ValueKey('discount-SCONTO10')), findsOneWidget);
      expect(find.text('12 / 50 utilizzi'), findsOneWidget);
      expect(find.text('-10%'), findsOneWidget);

      await tapKey(tester, 'new-discount');
      await tester.enterText(
        find.byKey(const ValueKey('discount-code')),
        'estate5',
      );
      await tapKey(tester, 'discount-type');
      await tester.tap(find.text('Importo fisso'));
      await settle(tester);
      await tester.enterText(
        find.byKey(const ValueKey('discount-amount')),
        '5',
      );
      await tapKey(tester, 'discount-limited');
      await tester.enterText(
        find.byKey(const ValueKey('discount-max-uses')),
        '1',
      );
      await tapKey(tester, 'discount-save');
      final created = fake.discounts.first;
      expect(created.code, 'ESTATE5');
      expect(created.type, DiscountType.amount);
      expect(created.amountCents, 500);
      expect(created.maxUses, 1);

      await tapKey(tester, 'discount-qr-SCONTO10');
      expect(find.byKey(const ValueKey('discount-qr')), findsOneWidget);
    });

    testWidgets('the cashier applies a code to a new order', (tester) async {
      final fake = FakeServer();
      await openShell(tester, fake, Section.orders);
      await tapKey(tester, 'orders-new');
      await tapKey(tester, 'new-order-cat-drinks');
      await tapKey(tester, 'new-order-product-cola');
      await tapKey(tester, 'new-order-product-cola');
      await tester.enterText(
        find.byKey(const ValueKey('new-order-code')),
        'colagratis',
      );
      await tapKey(tester, 'new-order-code-apply');
      expect(find.byKey(const ValueKey('new-order-coupon')), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('new-order-total'))).data,
        '2,80 €',
      );
      await tapKey(tester, 'new-order-save');
      expect(fake.counterOrders.single['discountCode'], 'COLAGRATIS');
      expect(fake.orders.single.totalCents, 280);
    });

    testWidgets('settings choose how codes are entered', (tester) async {
      final fake = FakeServer();
      await openShell(tester, fake, Section.settings);
      await tapKey(tester, 'discounts-scanner');
      expect(find.byKey(const ValueKey('scanner-test')), findsOneWidget);
      await tapKey(tester, 'discounts-manual');
      await tapKey(tester, 'save-settings');
      expect(fake.settings.discounts.scanner, isTrue);
      expect(fake.settings.discounts.manualEntry, isFalse);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('with codes off the section is hidden', (tester) async {
      final fake = FakeServer()
        ..settings = const KioskSettings(
          discounts: DiscountSettings(enabled: false),
        );
      await openShell(tester, fake, Section.orders);
      expect(find.byKey(const ValueKey('nav-discounts')), findsNothing);
      await tapKey(tester, 'orders-new');
      expect(find.byKey(const ValueKey('new-order-code')), findsNothing);
    });
  });

  group('Agenzia delle Entrate', () {
    testWidgets('online documents: business details and the account', (
      tester,
    ) async {
      final fake = FakeServer();
      await openShell(tester, fake, Section.settings);
      await tapKey(tester, 'fiscal-mode-adeOnline');
      expect(find.byKey(const ValueKey('fiscal-not-in-flow')), findsOneWidget);
      expect(find.byKey(const ValueKey('merchant-problems')), findsOneWidget);

      await tester.enterText(
        find.descendant(
          of: find.byKey(const ValueKey('merchant-legalName')),
          matching: find.byType(TextField),
        ),
        'Burger Bros S.r.l.',
      );
      await tester.enterText(
        find.descendant(
          of: find.byKey(const ValueKey('merchant-vatNumber')),
          matching: find.byType(TextField),
        ),
        '01234567897',
      );
      for (final (k, v) in [('address', 'Via Roma 1'), ('city', 'Milano')]) {
        await tester.enterText(
          find.descendant(
            of: find.byKey(ValueKey('merchant-$k')),
            matching: find.byType(TextField),
          ),
          v,
        );
      }
      await settle(tester);
      expect(find.byKey(const ValueKey('merchant-problems')), findsNothing);

      // Credentials are sent at once, on their own.
      await tester.enterText(
        find.byKey(const ValueKey('ade-taxcode')),
        'RSSMRA80A01H501U',
      );
      await tester.enterText(
        find.byKey(const ValueKey('ade-password')),
        'Segreta!2026',
      );
      await tester.enterText(find.byKey(const ValueKey('ade-pin')), '12345');
      // A focused field scrolls itself back into view, under the tap.
      FocusManager.instance.primaryFocus?.unfocus();
      await settle(tester);
      await tapKey(tester, 'ade-save');
      expect(fake.fiscalCredentials, isNull, reason: 'PIN too short');
      // Let the error message go away from the buttons.
      await tester.pump(const Duration(seconds: 6));
      await settle(tester);
      await tester.enterText(
        find.byKey(const ValueKey('ade-pin')),
        '1234567890',
      );
      FocusManager.instance.primaryFocus?.unfocus();
      await settle(tester);
      await tapKey(tester, 'ade-save');
      expect(fake.fiscalCredentials?['pin'], '1234567890');
      expect(find.textContaining('Collegato ·'), findsOneWidget);
      expect(find.byKey(const ValueKey('ade-password')), findsNothing);

      await tapKey(tester, 'ade-check');
      expect(find.byKey(const ValueKey('ade-check-result')), findsOneWidget);

      await tester.pump(const Duration(seconds: 6));
      await settle(tester);
      await tapKey(tester, 'save-settings');
      expect(fake.settings.fiscal.type, 'adeOnline');
      expect(fake.settings.merchant.vatNumber, '01234567897');
      expect(
        fake.settings.toJson().toString(),
        isNot(contains('Segreta')),
        reason: 'credentials never travel with the settings',
      );
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('the lottery code goes with a card payment', (tester) async {
      final fake = FakeServer()
        ..orders = [makeOrder(7)]
        ..settings = KioskSettings(
          fiscal: const AdapterConfig('adeOnline'),
          flow: FlowConfig(
            paymentMode: PaymentMode.counter,
            rules: {
              FlowEvent.submitted: const [FlowAction.printCustomerTicket],
              FlowEvent.paid: const [FlowAction.issueFiscalDocument],
            },
          ),
        );
      await openShell(tester, fake, Section.orders);
      await tapKey(tester, 'order-row-7');
      await tapKey(tester, 'pay-open');
      await tapKey(tester, 'pay-fiscal-customer');
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('pay-lottery')))
            .enabled,
        isFalse,
        reason: 'cash takes no lottery code',
      );
      await tapKey(tester, 'pay-method-card');
      await tester.enterText(find.byKey(const ValueKey('pay-lottery')), 'ab12');
      await settle(tester);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('pay-confirm')))
            .onPressed,
        isNull,
      );
      await tester.enterText(
        find.byKey(const ValueKey('pay-lottery')),
        'ab12cd34',
      );
      await settle(tester);
      await tapKey(tester, 'pay-confirm');
      expect(fake.payments.single['fiscalCustomer'], {
        'lotteryCode': 'AB12CD34',
      });
    });
  });
}
