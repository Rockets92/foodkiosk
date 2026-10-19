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

Future<void> saveServerUri(Uri uri) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_serverKey, uri.toString());
}
