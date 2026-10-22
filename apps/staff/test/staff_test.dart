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
}
