import 'package:shelf/shelf.dart';

import 'adapters/registry.dart';
import 'api.dart';
import 'database.dart';
import 'demo_data.dart';
import 'discount_service.dart';
import 'event_bus.dart';
import 'fiscal_account.dart';
import 'menu_service.dart';
import 'order_service.dart';
import 'repositories.dart';
import 'secrets.dart';
import 'settings_service.dart';

/// Wires the server together; used by `bin/server.dart` and by the tests.
class KioskApp {
  final AppDatabase db;
  final EventBus bus;
  final AdapterRegistry registry;
  final SettingsService settings;
  final MenuService menu;
  final OrderService orders;
  final DiscountService discounts;
  final PrintJobRepository printJobs;
  final FiscalAccount fiscalAccount;
  final Handler handler;

  KioskApp._(
    this.db,
    this.bus,
    this.registry,
    this.settings,
    this.menu,
    this.orders,
    this.discounts,
    this.printJobs,
    this.fiscalAccount,
    this.handler,
  );

  factory KioskApp(
    AppDatabase db, {
    AdapterRegistry? registry,
    bool seedDemo = true,
    Handler? mediaHandler,
    String? mediaDir,
    DateTime Function()? clock,
    SecretStore? secrets,
  }) {
    final bus = EventBus();
    final reg = registry ?? AdapterRegistry();
    final menuRepo = MenuRepository(db);
    final printJobs = PrintJobRepository(db);
    final account = FiscalAccount(
      secrets ?? SecretStore.ephemeral(db),
      db,
      clock: clock,
    );
    final settings = SettingsService(
      SettingsRepository(db),
      reg,
      bus,
      account: account,
    )..ensureInitialized();
    final discountRepo = DiscountRepository(db);
    if (seedDemo && menuRepo.isEmpty) {
      seedDemoMenu(menuRepo);
      if (discountRepo.isEmpty) seedDemoDiscounts(discountRepo);
    }
    final menu = MenuService(menuRepo, bus);
    final discounts = DiscountService(
      discountRepo,
      menuRepo,
      settings,
      bus,
      clock: clock,
    );
    final orders = OrderService(
      db,
      menuRepo,
      OrderRepository(db),
      printJobs,
      settings,
      bus,
      discounts,
      clock: clock,
    );
    final api = Api(
      settings: settings,
      menu: menu,
      orders: orders,
      discounts: discounts,
      printJobs: printJobs,
      fiscalAccount: account,
      registry: reg,
      bus: bus,
      mediaHandler: mediaHandler,
      mediaDir: mediaDir,
    );
    return KioskApp._(
      db,
      bus,
      reg,
      settings,
      menu,
      orders,
      discounts,
      printJobs,
      account,
      api.handler,
    );
  }

  Future<void> close() async {
    await bus.close();
    db.close();
  }
}
