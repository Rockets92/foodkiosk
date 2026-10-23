import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:kiosk_core/kiosk_core.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Error returned by the server, with its machine-readable [code].
class BackendException implements Exception {
  final int status;
  final String code;
  final String message;

  BackendException(this.status, this.code, this.message);

  /// The server could not be reached at all.
  bool get isNetwork => status == 0;

  @override
  String toString() => 'BackendException($status, $code, $message)';
}

/// What the kiosk needs from the server. The UI only talks to this
/// interface, so tests run against an in-memory fake.
abstract class KioskBackend {
  Uri get baseUri;

  Future<KioskSettings> settings();
  Future<Menu> menu();
  Future<Order> createOrder(OrderRequest request);
  Future<Order> order(String id);
  Future<Order> pay(String orderId);
  Future<Order> switchToCounter(String orderId);
  Future<Order> cancel(String orderId);

  /// Looks up a discount code typed or scanned by the customer.
  Future<DiscountCode> checkDiscount(String code);

  /// Checks a staff PIN against the server (for the hidden staff menu).
  /// Whether the server accepts [pin]; null when it cannot be reached.
  Future<bool?> verifyStaffPin(String pin);

  /// Tickets the server left for this totem's own printer with the last
  /// replies about order [orderId] (ESC/POS bytes); each is handed out
  /// once.
  List<Uint8List> takeReceipts(String orderId) => const [];

  /// Live notifications (menu or settings changed).
  Stream<ServerEvent> events();

  /// Absolute URL for an image path coming from the menu.
  String? imageUrl(String? path) {
    if (path == null || path.isEmpty) return null;
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    return baseUri.resolve(path).toString();
  }

  void dispose() {}
}

class HttpKioskBackend extends KioskBackend {
  @override
  final Uri baseUri;
  final http.Client _client;
  final Duration timeout;

  HttpKioskBackend(
    this.baseUri, {
    http.Client? client,
    this.timeout = const Duration(seconds: 10),
  }) : _client = client ?? http.Client();

  Uri _u(String path) => baseUri.resolve(path);

  final _receipts = <String, List<Uint8List>>{};

  Order _order(Map<String, Object?> json) {
    final order = Order.fromJson(json);
    if (json['receipts'] case final List<Object?> tickets
        when tickets.isNotEmpty) {
      (_receipts[order.id] ??= []).addAll([
        for (final t in tickets) base64Decode(t as String),
      ]);
    }
    return order;
  }

  @override
  List<Uint8List> takeReceipts(String orderId) =>
      _receipts.remove(orderId) ?? const [];

  Future<Map<String, Object?>> _send(
    String method,
    String path, {
    Object? body,
    Duration? timeout,
  }) async {
    final req = http.Request(method, _u(path))
      ..headers['content-type'] = 'application/json';
    if (body != null) req.body = jsonEncode(body);
    final http.Response res;
    try {
      res = await http.Response.fromStream(
        await _client.send(req).timeout(timeout ?? this.timeout),
      );
    } on TimeoutException {
      throw BackendException(0, 'timeout', 'Server not responding');
    } catch (e) {
      throw BackendException(0, 'network', '$e');
    }
    final decoded = res.body.isEmpty
        ? <String, Object?>{}
        : jsonDecode(utf8.decode(res.bodyBytes));
    final json = (decoded as Map).cast<String, Object?>();
    if (res.statusCode >= 400) {
      throw BackendException(
        res.statusCode,
        json['error'] as String? ?? 'error',
        json['message'] as String? ?? 'HTTP ${res.statusCode}',
      );
    }
    return json;
  }

  @override
  Future<KioskSettings> settings() async =>
      KioskSettings.fromJson(await _send('GET', '/api/settings'));

  @override
  Future<Menu> menu() async => Menu.fromJson(await _send('GET', '/api/menu'));

  @override
  Future<Order> createOrder(OrderRequest request) async =>
      _order(await _send('POST', '/api/orders', body: request.toJson()));

  @override
  Future<Order> order(String id) async =>
      _order(await _send('GET', '/api/orders/$id'));

  /// Card payments can take a while on the terminal: generous timeout.
  @override
  Future<Order> pay(String orderId) async => _order(
    await _send(
      'POST',
      '/api/orders/$orderId/pay',
      timeout: const Duration(minutes: 3),
    ),
  );

  @override
  Future<Order> switchToCounter(String orderId) async =>
      _order(await _send('POST', '/api/orders/$orderId/switch-to-counter'));

  @override
  Future<Order> cancel(String orderId) async =>
      Order.fromJson(await _send('POST', '/api/orders/$orderId/cancel'));

  @override
  Future<DiscountCode> checkDiscount(String code) async =>
      DiscountCode.fromJson(
        await _send('POST', '/api/discounts/check', body: {'code': code}),
      );

  @override
  Future<bool?> verifyStaffPin(String pin) async {
    try {
      final res = await _client
          .get(_u('/api/admin/settings'), headers: {'x-staff-pin': pin})
          .timeout(timeout);
      if (res.statusCode == 200) return true;
      if (res.statusCode == 401) return false;
      return null;
    } catch (_) {
      return null;
    }
  }

  @override
  Stream<ServerEvent> events() {
    final wsUri = _u('/ws').replace(
      scheme: baseUri.scheme == 'https' ? 'wss' : 'ws',
      queryParameters: {'device': 'totem'},
    );
    late StreamController<ServerEvent> controller;
    WebSocketChannel? channel;
    Timer? retry;
    var closed = false;

    void connect() {
      if (closed) return;
      try {
        channel = WebSocketChannel.connect(wsUri);
        channel!.stream.listen(
          (data) => controller.add(
            ServerEvent.fromJson((jsonDecode(data as String) as Map).cast()),
          ),
          onDone: () => retry = Timer(const Duration(seconds: 5), connect),
          onError: (_) {},
          cancelOnError: true,
        );
      } catch (_) {
        retry = Timer(const Duration(seconds: 5), connect);
      }
    }

    controller = StreamController<ServerEvent>.broadcast(
      onListen: connect,
      onCancel: () {
        closed = true;
        retry?.cancel();
        channel?.sink.close();
      },
    );
    return controller.stream;
  }

  @override
  void dispose() => _client.close();
}
