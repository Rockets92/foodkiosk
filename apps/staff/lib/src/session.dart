import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:kiosk_core/kiosk_core.dart';

import 'api.dart';

/// The logged-in staff session: API client, settings and menu kept in sync
/// with the server, and the live event stream screens listen to.
class StaffSession extends ChangeNotifier {
  final StaffApi api;
  KioskSettings settings;
  Menu menu;
  final _events = StreamController<ServerEvent>.broadcast();
  StreamSubscription<ServerEvent>? _sub;
  bool connected = true;

  StaffSession._(this.api, this.settings, this.menu);

  /// Checks the PIN by loading the admin settings; throws [ApiError].
  static Future<StaffSession> open(StaffApi api) async {
    final settings = await api.settings();
    final menu = await api.menu();
    return StaffSession._(api, settings, menu).._listen();
  }

  /// Server events: `order.created`, `order.updated`, `menu.updated`...
  Stream<ServerEvent> get events => _events.stream;

  /// Order changes only, for the cashier, kitchen and pickup screens.
  Stream<ServerEvent> get orderEvents => events.where(
    (e) =>
        e.type == ServerEvent.orderCreated ||
        e.type == ServerEvent.orderUpdated,
  );

  void _listen() {
    _sub = api.events().listen((e) {
      _events.add(e);
      if (e.type == ServerEvent.menuUpdated) reloadMenu();
      if (e.type == ServerEvent.settingsUpdated) reloadSettings();
    });
  }

  Future<void> reloadMenu() async {
    try {
      menu = await api.menu();
      notifyListeners();
    } on ApiError {
      // Kept the previous menu; the next event retries.
    }
  }

  Future<void> reloadSettings() async {
    try {
      settings = await api.settings();
      notifyListeners();
    } on ApiError {
      // Kept the previous settings.
    }
  }

  String money(Cents cents) =>
      formatCents(cents, symbol: settings.currencySymbol);

  @override
  void dispose() {
    _sub?.cancel();
    _events.close();
    api.dispose();
    super.dispose();
  }
}

class StaffScope extends InheritedNotifier<StaffSession> {
  const StaffScope({
    super.key,
    required StaffSession session,
    required super.child,
  }) : super(notifier: session);

  static StaffSession of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<StaffScope>()!.notifier!;

  /// Without subscribing to rebuilds, for callbacks.
  static StaffSession read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<StaffScope>()!.notifier!;
}

extension StaffContext on BuildContext {
  StaffSession get staff => StaffScope.of(this);
  StaffSession get staffRead => StaffScope.read(this);
}
