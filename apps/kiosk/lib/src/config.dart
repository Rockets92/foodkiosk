import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _serverKey = 'serverUrl';

/// Server address: the one saved from the staff menu, else the
/// `SERVER_URL` compile-time define, else the page origin on web (when the
/// server hosts the kiosk), else localhost.
Future<Uri> loadServerUri() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_serverKey);
    if (saved != null && saved.isNotEmpty) return Uri.parse(saved);
  } catch (_) {
    // No preferences store available: use the defaults.
  }
  const fromDefine = String.fromEnvironment('SERVER_URL');
  if (fromDefine.isNotEmpty) return Uri.parse(fromDefine);
  if (kIsWeb && Uri.base.scheme.startsWith('http') && Uri.base.port != 0) {
    final origin = Uri.base.replace(path: '/', query: null, fragment: null);
    if (Uri.base.path.startsWith('/kiosk')) return origin;
  }
  return Uri.parse('http://localhost:8080/');
}

/// Reads an address as typed by staff: a bare `192.168.1.20` is taken as
/// `http://192.168.1.20:8080/`, the server's default port.
Uri? parseServerAddress(String text) {
  final t = text.trim();
  if (t.isEmpty) return null;
  final bare = !t.contains('://');
  final uri = Uri.tryParse(bare ? 'http://$t' : t);
  if (uri == null || uri.host.isEmpty) return null;
  return uri.replace(
    port: bare && !uri.hasPort ? 8080 : uri.port,
    path: '/',
    query: null,
    fragment: null,
  );
}

Future<void> saveServerUri(Uri uri) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_serverKey, uri.toString());
}

const _pinKey = 'staffPin';

/// The staff PIN last accepted by the server, remembered so the staff
/// menu still opens while the server is unreachable (wrong address, server
/// PC off): otherwise a full-screen totem could not be pointed elsewhere
/// or closed.
Future<void> rememberStaffPin(String pin) async {
  try {
    await (await SharedPreferences.getInstance()).setString(_pinKey, pin);
  } catch (_) {
    // Not persisted: offline access falls back to the factory PIN.
  }
}

/// Whether [pin] opens the staff menu while the server is unreachable: the
/// last PIN the server accepted, or the factory PIN 1234 on a totem that
/// never reached a server.
Future<bool> offlinePinMatches(String pin) async {
  String? saved;
  try {
    saved = (await SharedPreferences.getInstance()).getString(_pinKey);
  } catch (_) {
    saved = null;
  }
  return pin == (saved ?? '1234');
}
