/// Messages pushed by the server over the `/ws` WebSocket so that the
/// kitchen display, pickup screen, admin panel and kiosks update live.
class ServerEvent {
  static const orderCreated = 'order.created';
  static const orderUpdated = 'order.updated';
  static const menuUpdated = 'menu.updated';
  static const settingsUpdated = 'settings.updated';
  static const printJob = 'print.job';
  static const pickupAnnounce = 'pickup.announce';

  final String type;
  final Map<String, Object?> data;

  const ServerEvent(this.type, [this.data = const {}]);

  factory ServerEvent.fromJson(Map<String, Object?> json) => ServerEvent(
    json['type'] as String,
    (json['data'] as Map? ?? const {}).cast<String, Object?>(),
  );

  Map<String, Object?> toJson() => {'type': type, 'data': data};
}
