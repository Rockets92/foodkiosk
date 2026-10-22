import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:kiosk_core/kiosk_core.dart';
import 'package:path/path.dart' as p;
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_web_socket/shelf_web_socket.dart';

import 'adapters/registry.dart';
import 'discount_service.dart';
import 'errors.dart';
import 'event_bus.dart';
import 'menu_service.dart';
import 'order_service.dart';
import 'placeholder.dart';
import 'repositories.dart';
import 'settings_service.dart';

const _json = {'content-type': 'application/json; charset=utf-8'};

Response _ok(Object? body, {int status = 200}) =>
    Response(status, body: jsonEncode(body), headers: _json);

Future<Map<String, Object?>> _body(Request req) async {
  final text = await req.readAsString();
  if (text.trim().isEmpty) return {};
  try {
    final decoded = jsonDecode(text);
    if (decoded is Map) return decoded.cast();
  } on FormatException {
    // fall through
  }
  throw ApiException.badRequest(
    'invalidJson',
    'The body must be a JSON object.',
  );
}

/// Server events that anyone on the network may receive (kiosks, pickup
/// screen). Order details are only streamed to authenticated staff.
const _publicEvents = {
  ServerEvent.menuUpdated,
  ServerEvent.settingsUpdated,
  ServerEvent.pickupAnnounce,
};

/// A device listening for live events: a totem, a staff station or a
/// pickup screen.
class ConnectedDevice {
  final String kind;
  final String address;
  final DateTime since;
  ConnectedDevice(this.kind, this.address, this.since);

  Map<String, Object?> toJson() => {
    'kind': kind,
    'address': address,
    'since': since.toUtc().toIso8601String(),
  };
}

class Api {
  final SettingsService settings;
  final MenuService menu;

  /// Folder where uploaded photos are stored and served from `/media/`.
  final String? mediaDir;
  final OrderService orders;
  final DiscountService discounts;
  final PrintJobRepository printJobs;
  final AdapterRegistry registry;
  final EventBus bus;
  final Handler? mediaHandler;

  /// Devices with an open live connection, for the "Rete" settings.
  final Set<ConnectedDevice> devices = {};

  Api({
    required this.settings,
    required this.menu,
    required this.orders,
    required this.discounts,
    required this.printJobs,
    required this.registry,
    required this.bus,
    this.mediaHandler,
    this.mediaDir,
  });

  bool _isStaff(Request req) {
    final pin = req.headers['x-staff-pin'] ?? req.url.queryParameters['pin'];
    return pin != null && pin == settings.current.adminPin;
  }

  Middleware get _staffOnly =>
      (inner) => (req) {
        if (!_isStaff(req)) {
          return _ok({
            'error': 'unauthorized',
            'message': 'Staff PIN required.',
          }, status: 401);
        }
        return inner(req);
      };

  Handler get handler {
    final staffHandler = const Pipeline()
        .addMiddleware(_staffOnly)
        .addHandler(_staffRouter().call);

    // Unknown public routes fall through to the PIN-protected ones.
    final public = Router(notFoundHandler: staffHandler)
      ..get('/health', (Request _) => _ok({'status': 'ok'}))
      ..get('/settings', (Request _) => _ok(settings.current.toPublicJson()))
      ..get('/menu', (Request _) => _ok(menu.kioskMenu().toJson()))
      ..get('/pickup', (Request _) => _ok(orders.pickupBoard()))
      ..get(
        '/allergens',
        (Request _) => _ok({
          'allergens': [
            for (final a in Allergen.values)
              {'code': a.name, 'label': a.label.toJson()},
          ],
          'tags': [
            for (final t in DietaryTag.values)
              {'code': t.name, 'label': t.label.toJson()},
          ],
        }),
      )
      ..post('/discounts/check', (Request req) async {
        final body = await _body(req);
        final code = discounts.lookup(
          body['code'] as String? ?? '',
          channel: DiscountChannel.kiosk,
          client: _clientOf(req),
        );
        return _ok(code.toPublicJson());
      })
      ..post('/orders', (Request req) async {
        final body = await _body(req);
        final order = await orders.create(OrderRequest.fromJson(body));
        return _ok(order.toJson(), status: 201);
      })
      ..get(
        '/orders/<id>',
        (Request _, String id) => _ok(orders.get(id).toJson()),
      )
      ..post(
        '/orders/<id>/pay',
        (Request _, String id) async =>
            _ok((await orders.payOnKiosk(id)).toJson()),
      )
      ..post(
        '/orders/<id>/switch-to-counter',
        (Request _, String id) async =>
            _ok((await orders.switchToCounter(id)).toJson()),
      )
      ..post(
        '/orders/<id>/cancel',
        (Request _, String id) async =>
            _ok((await orders.cancel(id, byStaff: false)).toJson()),
      );

    final root = Router()
      ..get('/ws', _webSocket)
      ..get(
        '/media/placeholder/<name>',
        (Request _, String name) => Response.ok(
          placeholderSvg(name),
          headers: {
            'content-type': 'image/svg+xml',
            'cache-control': 'max-age=86400',
          },
        ),
      )
      ..mount('/api/', public.call);
    if (mediaHandler case final media?) root.mount('/media/', media);

    return const Pipeline()
        .addMiddleware(_cors)
        .addMiddleware(_errors)
        .addHandler(root.call);
  }

  Router _staffRouter() {
    return Router()
      ..get(
        '/kitchen/orders',
        (Request _) => _ok({
          'orders': [for (final o in orders.kitchenQueue()) o.toJson()],
        }),
      )
      ..post('/kitchen/orders/<id>/status', (Request req, String id) async {
        final body = await _body(req);
        final status = KitchenStatus.values
            .where((s) => s.name == body['status'])
            .firstOrNull;
        if (status == null) {
          throw ApiException.badRequest(
            'invalidStatus',
            'Unknown kitchen status.',
          );
        }
        return _ok((await orders.setKitchenStatus(id, status)).toJson());
      })
      ..patch('/kitchen/products/<id>', (Request req, String id) async {
        final body = await _body(req);
        return _ok(
          menu.patchProduct(id, soldOut: body['soldOut'] as bool?).toJson(),
        );
      })
      ..get('/staff/orders', _listOrders)
      ..post('/staff/discounts/check', (Request req) async {
        final body = await _body(req);
        return _ok(
          discounts
              .lookup(
                body['code'] as String? ?? '',
                channel: DiscountChannel.counter,
                client: 'staff',
              )
              .toPublicJson(),
        );
      })
      ..get(
        '/admin/discounts',
        (Request _) => _ok({
          'codes': [for (final c in discounts.all()) c.toJson()],
        }),
      )
      ..post(
        '/admin/discounts',
        (Request req) async =>
            _ok(discounts.save(await _body(req)).toJson(), status: 201),
      )
      ..put(
        '/admin/discounts/<id>',
        (Request req, String id) async =>
            _ok(discounts.save(await _body(req), id: id).toJson()),
      )
      ..post(
        '/admin/discounts/<id>/reset-uses',
        (Request _, String id) => _ok(discounts.resetUses(id).toJson()),
      )
      ..delete('/admin/discounts/<id>', (Request _, String id) {
        discounts.delete(id);
        return Response(204);
      })
      ..post('/staff/orders', (Request req) async {
        final body = await _body(req);
        final method = body['payment'] as String?;
        final order = await orders.create(
          OrderRequest.fromJson(body),
          origin: OrderOrigin.counter,
          payMethod: method == null || method.isEmpty ? null : method,
          cashCents: body['cashCents'] as int?,
          cardCents: body['cardCents'] as int?,
          receivedCents: body['receivedCents'] as int?,
          issueFiscal: body['issueFiscal'] as bool? ?? true,
        );
        return _ok(order.toJson(), status: 201);
      })
      ..get(
        '/staff/summary',
        (Request req) => _ok(
          orders.summary(
            req.url.queryParameters['day'] ??
                OrderRepository.businessDay(DateTime.now()),
          ),
        ),
      )
      ..post('/staff/orders/<id>/mark-paid', (Request req, String id) async {
        final body = await _body(req);
        return _ok(
          (await orders.markPaid(
            id,
            method: body['method'] as String? ?? 'counter',
            cashCents: body['cashCents'] as int?,
            cardCents: body['cardCents'] as int?,
            receivedCents: body['receivedCents'] as int?,
            issueFiscal: body['issueFiscal'] as bool? ?? true,
          )).toJson(),
        );
      })
      ..put('/staff/orders/<id>/lines', (Request req, String id) async {
        final body = await _body(req);
        return _ok(
          (await orders.editLines(id, OrderRequest.fromJson(body))).toJson(),
        );
      })
      ..post('/staff/orders/<id>/cancel', (Request req, String id) async {
        final body = await _body(req);
        return _ok(
          (await orders.cancel(
            id,
            byStaff: true,
            reason: body['reason'] as String?,
          )).toJson(),
        );
      })
      ..post('/staff/orders/<id>/actions/<action>', (
        Request _,
        String id,
        String action,
      ) async {
        final a =
            FlowAction.tryParse(action) ??
            (throw ApiException.badRequest('unknownAction', 'Unknown action.'));
        return _ok((await orders.runAction(id, a)).toJson());
      })
      ..get(
        '/staff/print-jobs',
        (Request req) => _ok({
          'jobs': [
            for (final j in printJobs.recent(
              orderId: req.url.queryParameters['orderId'],
            ))
              j.toJson(),
          ],
        }),
      )
      ..get('/admin/settings', (Request _) => _ok(settings.current.toJson()))
      ..put('/admin/settings', (Request req) async {
        final body = await _body(req);
        final next = KioskSettings.fromJson({
          ...settings.current.toJson(),
          ...body,
        });
        return _ok(settings.update(next).toJson());
      })
      ..get(
        '/admin/flow/presets',
        (Request _) => _ok({
          for (final e in FlowConfig.presets.entries) e.key: e.value.toJson(),
        }),
      )
      ..post('/admin/flow/validate', (Request req) async {
        final flow = FlowConfig.fromJson(await _body(req));
        return _ok({
          'valid': flow.isValid,
          'issues': [for (final i in flow.validate()) i.toJson()],
        });
      })
      ..get('/admin/adapters', (Request _) => _ok(registry.describe()))
      ..get('/admin/network', (Request _) async => _ok(await _network()))
      ..post('/admin/media', _upload)
      ..get('/admin/menu', (Request _) => _ok(menu.fullMenu().toJson()))
      ..post(
        '/admin/categories',
        (Request req) async =>
            _ok(menu.saveCategory(await _body(req)).toJson(), status: 201),
      )
      ..put(
        '/admin/categories/<id>',
        (Request req, String id) async =>
            _ok(menu.saveCategory(await _body(req), id: id).toJson()),
      )
      ..delete('/admin/categories/<id>', (Request _, String id) {
        menu.deleteCategory(id);
        return Response(204);
      })
      ..post(
        '/admin/products',
        (Request req) async =>
            _ok(menu.saveProduct(await _body(req)).toJson(), status: 201),
      )
      ..put(
        '/admin/products/<id>',
        (Request req, String id) async =>
            _ok(menu.saveProduct(await _body(req), id: id).toJson()),
      )
      ..patch('/admin/products/<id>', (Request req, String id) async {
        final b = await _body(req);
        return _ok(
          menu
              .patchProduct(
                id,
                soldOut: b['soldOut'] as bool?,
                enabled: b['enabled'] as bool?,
                stockQty: b['stockQty'] as int?,
              )
              .toJson(),
        );
      })
      ..delete('/admin/products/<id>', (Request _, String id) {
        menu.deleteProduct(id);
        return Response(204);
      })
      ..post(
        '/admin/modifier-groups',
        (Request req) async =>
            _ok(menu.saveModifierGroup(await _body(req)).toJson(), status: 201),
      )
      ..put(
        '/admin/modifier-groups/<id>',
        (Request req, String id) async =>
            _ok(menu.saveModifierGroup(await _body(req), id: id).toJson()),
      )
      ..delete('/admin/modifier-groups/<id>', (Request _, String id) {
        menu.deleteModifierGroup(id);
        return Response(204);
      });
  }

  static const _imageTypes = {'jpg', 'jpeg', 'png', 'webp', 'gif', 'svg'};
  static const _maxUpload = 10 * 1024 * 1024;

  /// Stores a photo sent as the raw request body; `?name=burger.jpg` gives
  /// the original file name. Returns the URL to use as `imageUrl`.
  Future<Response> _upload(Request req) async {
    final dir = mediaDir;
    if (dir == null) {
      throw ApiException.conflict('noMedia', 'Uploads are not enabled.');
    }
    final name = req.url.queryParameters['name'] ?? 'image.jpg';
    final ext = p.extension(name).replaceFirst('.', '').toLowerCase();
    if (!_imageTypes.contains(ext)) {
      throw ApiException.badRequest(
        'unsupportedType',
        'Use a JPG, PNG, WEBP, GIF or SVG image.',
      );
    }
    final bytes = BytesBuilder(copy: false);
    await for (final chunk in req.read()) {
      bytes.add(chunk);
      if (bytes.length > _maxUpload) {
        throw ApiException.badRequest('tooLarge', 'Images up to 10 MB.');
      }
    }
    if (bytes.isEmpty) {
      throw ApiException.badRequest('emptyFile', 'The file is empty.');
    }
    final base = p
        .basenameWithoutExtension(name)
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    final suffix = Random().nextInt(1 << 32).toRadixString(36);
    final file = '${base.isEmpty ? 'image' : base}-$suffix.$ext';
    await File(p.join(dir, file)).writeAsBytes(bytes.takeBytes());
    return _ok({'url': '/media/$file'}, status: 201);
  }

  Response _listOrders(Request req) {
    final q = req.url.queryParameters;
    return _ok({
      'orders': [
        for (final o in orders.query(
          businessDay: q['day'] ?? OrderRepository.businessDay(DateTime.now()),
          number: int.tryParse(q['number'] ?? ''),
          status: q['status'] == null ? null : OrderStatus.parse(q['status']!),
          paymentStatus: q['payment'] == null
              ? null
              : PaymentStatus.parse(q['payment']!),
        ))
          o.toJson(),
      ],
    });
  }

  static String _clientOf(Request req) {
    final info = req.context['shelf.io.connection_info'];
    return info is HttpConnectionInfo ? info.remoteAddress.address : '';
  }

  FutureOr<Response> _webSocket(Request req) {
    final staff = _isStaff(req);
    final info = req.context['shelf.io.connection_info'];
    final device = ConnectedDevice(
      req.url.queryParameters['device'] ?? (staff ? 'staff' : 'other'),
      info is HttpConnectionInfo ? info.remoteAddress.address : '',
      DateTime.now(),
    );
    return webSocketHandler((channel, _) {
      devices.add(device);
      final sub = bus.stream
          .where((e) => staff || _publicEvents.contains(e.type))
          .listen((e) => channel.sink.add(jsonEncode(e.toJson())));
      void gone() {
        devices.remove(device);
        sub.cancel();
      }

      channel.stream.listen((_) {}, onDone: gone, onError: (_) => gone());
    })(req);
  }

  /// This PC's LAN addresses (the other devices use one of them, with the
  /// server's port) and the devices connected right now.
  Future<Map<String, Object?>> _network() async {
    var addresses = <String>[];
    try {
      addresses = [
        for (final i in await NetworkInterface.list(
          type: InternetAddressType.IPv4,
        ))
          for (final a in i.addresses)
            if (!a.isLoopback && !a.isLinkLocal) a.address,
      ];
    } on SocketException {
      // No interfaces to report.
    }
    return {
      'hostname': Platform.localHostname,
      'addresses': addresses,
      'devices': [for (final d in devices) d.toJson()],
    };
  }
}

Middleware get _errors =>
    (inner) => (req) async {
      try {
        return await inner(req);
      } on ApiException catch (e) {
        return _ok(e.toJson(), status: e.status);
      }
    };

const _corsHeaders = {
  'access-control-allow-origin': '*',
  'access-control-allow-methods': 'GET, POST, PUT, PATCH, DELETE, OPTIONS',
  'access-control-allow-headers': 'content-type, x-staff-pin',
};

Middleware get _cors =>
    (inner) => (req) async {
      if (req.method == 'OPTIONS') {
        return Response.ok('', headers: _corsHeaders);
      }
      final res = await inner(req);
      return res.change(headers: _corsHeaders);
    };
