import 'package:shelf/shelf.dart';

import 'adapters/registry.dart';
import 'api.dart';
import 'database.dart';
import 'demo_data.dart';
import 'event_bus.dart';
import 'menu_service.dart';
import 'order_service.dart';
import 'repositories.dart';
import 'settings_service.dart';

/// Wires the server together; used by `bin/server.dart` and by the tests.
class KioskApp {
  final AppDatabase db;
  final EventBus bus;
  final AdapterRegistry registry;
  final SettingsService settings;
  final MenuService menu;
  final OrderService orders;
  final PrintJobRepository printJobs;
  final Handler handler;

  KioskApp._(
    this.db,
    this.bus,
    this.registry,
    this.settings,
    this.menu,
    this.orders,
    this.printJobs,
    this.handler,
  );

  factory KioskApp(
    AppDatabase db, {
    AdapterRegistry? registry,
    bool seedDemo = true,
    Handler? mediaHandler,
    DateTime Function()? clock,
  }) {
    final bus = EventBus();
    final reg = registry ?? AdapterRegistry();
    final menuRepo = MenuRepository(db);
    final printJobs = PrintJobRepository(db);
    final settings = SettingsService(SettingsRepository(db), reg, bus)
      ..ensureInitialized();
    if (seedDemo && menuRepo.isEmpty) seedDemoMenu(menuRepo);
    final menu = MenuService(menuRepo, bus);
    final orders = OrderService(
      db,
      menuRepo,
      OrderRepository(db),
      printJobs,
      settings,
      bus,
      clock: clock,
    );
    final api = Api(
      settings: settings,
      menu: menu,
      orders: orders,
      printJobs: printJobs,
      registry: reg,
      bus: bus,
      mediaHandler: mediaHandler,
    );
    return KioskApp._(
      db,
      bus,
      reg,
      settings,
      menu,
      orders,
      printJobs,
      api.handler,
    );
  }

  Future<void> close() async {
    await bus.close();
    db.close();
  }
}
