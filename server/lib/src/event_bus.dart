import 'dart:async';

import 'package:kiosk_core/kiosk_core.dart';

/// In-process broadcast of [ServerEvent]s, forwarded to WebSocket clients.
class EventBus {
  final _controller = StreamController<ServerEvent>.broadcast();

  Stream<ServerEvent> get stream => _controller.stream;

  void emit(String type, [Map<String, Object?> data = const {}]) =>
      _controller.add(ServerEvent(type, data));

  Future<void> close() => _controller.close();
}
