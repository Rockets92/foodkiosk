import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:kiosk_core/kiosk_core.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Error returned by the server, with its machine-readable [code].
class ApiError implements Exception {
  final int status;
  final String code;
  final String message;

  ApiError(this.status, this.code, this.message);

  bool get isNetwork => status == 0;
  bool get isUnauthorized => status == 401;

  @override
  String toString() => message;
}

/// Client for the staff and admin endpoints of the local server. Every
/// call carries the staff PIN.
class StaffApi {
  final Uri baseUri;
  final String pin;
  final http.Client _client;
  final Duration timeout;

  StaffApi(
    this.baseUri,
    this.pin, {
    http.Client? client,
    this.timeout = const Duration(seconds: 15),
  }) : _client = client ?? http.Client();

  Uri _u(String path, [Map<String, String>? query]) {
    final u = baseUri.resolve(path);
    return query == null ? u : u.replace(queryParameters: query);
  }

  Future<Object?> send(
    String method,
    String path, {
    Object? body,
    Map<String, String>? query,
    Uint8List? bytes,
  }) async {
    final req = http.Request(method, _u(path, query))
      ..headers['x-staff-pin'] = pin;
    if (bytes != null) {
      req
        ..headers['content-type'] = 'application/octet-stream'
        ..bodyBytes = bytes;
    } else {
      req.headers['content-type'] = 'application/json';
      if (body != null) req.body = jsonEncode(body);
    }
    final http.Response res;
    try {
      res = await http.Response.fromStream(
        await _client.send(req).timeout(timeout),
      );
    } on TimeoutException {
      throw ApiError(0, 'timeout', 'Il server non risponde');
    } catch (e) {
      throw ApiError(0, 'network', 'Server non raggiungibile');
    }
    final decoded = res.bodyBytes.isEmpty
        ? null
        : jsonDecode(utf8.decode(res.bodyBytes));
    if (res.statusCode >= 400) {
      final json = decoded is Map ? decoded : const {};
      throw ApiError(
        res.statusCode,
        json['error'] as String? ?? 'error',
        json['message'] as String? ?? 'Errore ${res.statusCode}',
      );
    }
    return decoded;
  }

  Future<Map<String, Object?>> _map(
    String method,
    String path, {
    Object? body,
    Map<String, String>? query,
  }) async =>
      ((await send(method, path, body: body, query: query)) as Map? ?? {})
          .cast();

  /// Absolute URL for an image path coming from the menu.
  String? imageUrl(String? path) {
    if (path == null || path.isEmpty) return null;
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    return baseUri.resolve(path).toString();
  }

  // Settings ---------------------------------------------------------------

  Future<KioskSettings> settings() async =>
      KioskSettings.fromJson(await _map('GET', '/api/admin/settings'));

  /// Saves a partial or full settings object; the server validates it.
  Future<KioskSettings> saveSettings(Map<String, Object?> patch) async =>
      KioskSettings.fromJson(
        await _map('PUT', '/api/admin/settings', body: patch),
      );

  Future<Map<String, FlowConfig>> flowPresets() async {
    final json = await _map('GET', '/api/admin/flow/presets');
    return {
      for (final e in json.entries)
        e.key: FlowConfig.fromJson((e.value as Map).cast()),
    };
  }

  Future<List<FlowIssue>> validateFlow(FlowConfig flow) async {
    final json = await _map(
      'POST',
      '/api/admin/flow/validate',
      body: flow.toJson(),
    );
    return [
      for (final i in json['issues'] as List? ?? const [])
        FlowIssue.fromJson((i as Map).cast()),
    ];
  }

  /// Adapter types the server knows: `{payment: [...], fiscal: [...],
  /// printer: [...]}`.
  Future<Map<String, List<String>>> adapters() async {
    final json = await _map('GET', '/api/admin/adapters');
    return {
      for (final e in json.entries)
        e.key: [for (final t in e.value as List) t as String],
    };
  }

  // Menu -------------------------------------------------------------------

  Future<Menu> menu() async =>
      Menu.fromJson(await _map('GET', '/api/admin/menu'));

  Future<Category> saveCategory(Category c, {bool isNew = false}) async =>
      Category.fromJson(
        await _map(
          isNew ? 'POST' : 'PUT',
          isNew ? '/api/admin/categories' : '/api/admin/categories/${c.id}',
          body: c.toJson(),
        ),
      );

  Future<void> deleteCategory(String id) =>
      send('DELETE', '/api/admin/categories/$id');

  Future<Product> saveProduct(Product p, {bool isNew = false}) async =>
      Product.fromJson(
        await _map(
          isNew ? 'POST' : 'PUT',
          isNew ? '/api/admin/products' : '/api/admin/products/${p.id}',
          body: p.toJson(),
        ),
      );

  Future<Product> patchProduct(
    String id, {
    bool? enabled,
    bool? soldOut,
    int? stockQty,
  }) async => Product.fromJson(
    await _map(
      'PATCH',
      '/api/admin/products/$id',
      body: {'enabled': ?enabled, 'soldOut': ?soldOut, 'stockQty': ?stockQty},
    ),
  );

  Future<void> deleteProduct(String id) =>
      send('DELETE', '/api/admin/products/$id');

  Future<ModifierGroup> saveModifierGroup(
    ModifierGroup g, {
    bool isNew = false,
  }) async => ModifierGroup.fromJson(
    await _map(
      isNew ? 'POST' : 'PUT',
      isNew
          ? '/api/admin/modifier-groups'
          : '/api/admin/modifier-groups/${g.id}',
      body: g.toJson(),
    ),
  );

  Future<void> deleteModifierGroup(String id) =>
      send('DELETE', '/api/admin/modifier-groups/$id');

  /// Uploads a photo and returns the URL to store as `imageUrl`.
  Future<String> uploadImage(String fileName, Uint8List bytes) async {
    final json = await send(
      'POST',
      '/api/admin/media',
      query: {'name': fileName},
      bytes: bytes,
    );
    return (json as Map)['url'] as String;
  }

  // Orders -----------------------------------------------------------------

  Future<List<Order>> orders({String? day}) async {
    final json = await _map('GET', '/api/staff/orders', query: {'day': ?day});
    return [
      for (final o in json['orders'] as List? ?? const [])
        Order.fromJson((o as Map).cast()),
    ];
  }

  Future<Order> markPaid(
    String id, {
    required String method,
    required bool issueFiscal,
  }) async => Order.fromJson(
    await _map(
      'POST',
      '/api/staff/orders/$id/mark-paid',
      body: {'method': method, 'issueFiscal': issueFiscal},
    ),
  );

  Future<Order> cancelOrder(String id, {String? reason}) async =>
      Order.fromJson(
        await _map(
          'POST',
          '/api/staff/orders/$id/cancel',
          body: {'reason': ?reason},
        ),
      );

  Future<Order> runAction(String id, FlowAction action) async => Order.fromJson(
    await _map('POST', '/api/staff/orders/$id/actions/${action.name}'),
  );

  Future<Map<String, Object?>> summary({String? day}) =>
      _map('GET', '/api/staff/summary', query: {'day': ?day});

  // Kitchen ----------------------------------------------------------------

  Future<List<Order>> kitchenOrders() async {
    final json = await _map('GET', '/api/kitchen/orders');
    return [
      for (final o in json['orders'] as List? ?? const [])
        Order.fromJson((o as Map).cast()),
    ];
  }

  Future<Order> setKitchenStatus(String id, KitchenStatus status) async =>
      Order.fromJson(
        await _map(
          'POST',
          '/api/kitchen/orders/$id/status',
          body: {'status': status.name},
        ),
      );

  /// Public: numbers for the pickup screen.
  Future<({List<int> preparing, List<int> ready})> pickup() async {
    final json = await _map('GET', '/api/pickup');
    List<int> ints(Object? l) => [for (final n in l as List? ?? []) n as int];
    return (preparing: ints(json['preparing']), ready: ints(json['ready']));
  }

  /// Live server events (orders, menu, settings), reconnecting on loss.
  Stream<ServerEvent> events() {
    final wsUri = _u('/ws', {
      'pin': pin,
    }).replace(scheme: baseUri.scheme == 'https' ? 'wss' : 'ws');
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
          onDone: () => retry = Timer(const Duration(seconds: 3), connect),
          onError: (_) {},
          cancelOnError: true,
        );
      } catch (_) {
        retry = Timer(const Duration(seconds: 3), connect);
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

  void dispose() => _client.close();
}
