import 'package:kiosk_core/kiosk_core.dart';
import 'package:test/test.dart';

void main() {
  group('FlowConfig', () {
    test('all presets are valid', () {
      for (final e in FlowConfig.presets.entries) {
        expect(e.value.isValid, isTrue, reason: e.key);
      }
    });

    test('fiscal document before payment is an error', () {
      const flow = FlowConfig(
        paymentMode: PaymentMode.counter,
        rules: {
          FlowEvent.submitted: [FlowAction.issueFiscalDocument],
        },
      );
      expect(flow.isValid, isFalse);
      expect(
        flow.validate().map((i) => i.code),
        contains('fiscalBeforePayment'),
      );
    });

    test('paid actions without payment are unreachable', () {
      const flow = FlowConfig(
        paymentMode: PaymentMode.none,
        rules: {
          FlowEvent.paid: [FlowAction.sendToKitchenDisplay],
        },
      );
      expect(flow.validate().map((i) => i.code), contains('unreachablePaid'));
    });

    test('survives a JSON round trip and ignores unknown names', () {
      final json = FlowConfig.fullService.toJson();
      (json['rules'] as Map)['submitted'] = ['printCustomerTicket', 'teleport'];
      final back = FlowConfig.fromJson(json);
      expect(back.paymentMode, PaymentMode.kiosk);
      expect(back.actionsFor(FlowEvent.submitted), [
        FlowAction.printCustomerTicket,
      ]);
      expect(
        back.actionsFor(FlowEvent.paid),
        FlowConfig.fullService.actionsFor(FlowEvent.paid),
      );
    });
  });

  group('KioskSettings', () {
    test('defaults are valid and start in demo mode', () {
      const s = KioskSettings();
      expect(s.validate(), isEmpty);
      expect(s.demoMode, isTrue);
    });

    test('production kiosk payment needs a terminal', () {
      const s = KioskSettings(
        demoMode: false,
        flow: FlowConfig.fullService,
        payment: AdapterConfig.none,
        fiscal: AdapterConfig.demo,
      );
      expect(s.validate(), isNotEmpty);
    });

    test('public JSON hides the PIN and device settings', () {
      final json = const KioskSettings().toPublicJson();
      expect(json.containsKey('adminPin'), isFalse);
      expect(json.containsKey('payment'), isFalse);
    });
  });

  test('LocalizedText falls back to another language', () {
    const t = LocalizedText({'it': 'Patatine', 'en': ''});
    expect(t.resolve('en'), 'Patatine');
    expect(t.resolve('de'), 'Patatine');
  });

  test('order totals include options and VAT breakdown', () {
    final order = Order(
      id: 'x',
      number: 7,
      createdAt: DateTime(2026),
      serviceMode: ServiceMode.eatIn,
      language: 'it',
      paymentMode: PaymentMode.counter,
      lines: const [
        OrderLine(
          productId: 'b',
          name: LocalizedText({'it': 'Burger'}),
          quantity: 2,
          unitPriceCents: 650,
          options: [
            OrderLineOption(
              groupId: 'g',
              optionId: 'o',
              name: LocalizedText({'it': 'Bacon'}),
              priceDeltaCents: 100,
            ),
          ],
        ),
        OrderLine(
          productId: 'c',
          name: LocalizedText({'it': 'Cola'}),
          quantity: 1,
          unitPriceCents: 280,
          vatRate: 22,
        ),
      ],
    );
    expect(order.totalCents, 1780);
    expect(order.displayNumber, '007');
    expect(order.vatBreakdown[10], 136);
    expect(order.vatBreakdown[22], 50);
    expect(formatCents(order.totalCents), '17,80 €');
    final back = Order.fromJson(order.toJson());
    expect(back.totalCents, order.totalCents);
  });

  test('product badge and option pictures survive JSON', () {
    const product = Product(
      id: 'p',
      categoryId: 'c',
      name: LocalizedText({'it': 'Panino'}),
      priceCents: 500,
      badge: LocalizedText({'it': 'Novità', 'en': 'New'}),
    );
    final back = Product.fromJson(product.toJson());
    expect(back.badge.resolve('en'), 'New');
    const option = ModifierOption(
      id: 'o',
      name: LocalizedText({'it': 'Patatine'}),
      imageUrl: '/media/fries.png',
    );
    expect(
      ModifierOption.fromJson(option.toJson()).imageUrl,
      '/media/fries.png',
    );
  });

  test('the colour palette travels with the settings', () {
    const s = KioskSettings(palette: 'fresh');
    expect(s.toPublicJson()['palette'], 'fresh');
    expect(KioskSettings.fromJson(s.toJson()).colors, ColorPalette.fresh);
    expect(const KioskSettings().colors, ColorPalette.classic);
    expect(
      const KioskSettings(palette: 'nope').validate(),
      contains(contains('palette')),
    );
    final ids = {for (final p in ColorPalette.presets) p.id};
    expect(ids, hasLength(ColorPalette.presets.length));
  });

  test('artwork colours follow the palette', () {
    const p = ColorPalette.ocean;
    expect(p.recolor(0xFFD62300), p.primary);
    expect(p.recolor(0x80FFC72C), (p.accent & 0xFFFFFF) | 0x80000000);
    expect(p.recolor(0xFF5A2E14), 0xFF5A2E14, reason: 'food is kept');
  });
}
