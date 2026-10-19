import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _serverKey = 'serverUrl';
const _pinKey = 'staffPin';

/// Server address: the saved one, else the `SERVER_URL` define, else the
/// page origin on web (the server hosts this app at `/staff/`), else
/// localhost.
Future<Uri> loadServerUri() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_serverKey);
    if (saved != null && saved.isNotEmpty) return Uri.parse(saved);
  } catch (_) {
    // No preferences store available: use the defaults.
  }
  return defaultServerUri();
}

Uri defaultServerUri() {
  const fromDefine = String.fromEnvironment('SERVER_URL');
  if (fromDefine.isNotEmpty) return Uri.parse(fromDefine);
  if (kIsWeb && Uri.base.scheme.startsWith('http')) {
    return Uri.base.replace(path: '/', query: null, fragment: null);
  }
  return Uri.parse('http://localhost:8080/');
}

/// The PIN is remembered on this device so the kitchen screen survives a
/// restart; "Esci" forgets it.
Future<String?> loadPin() async {
  try {
    return (await SharedPreferences.getInstance()).getString(_pinKey);
  } catch (_) {
    return null;
  }
}

Future<void> saveLogin(Uri server, String? pin) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_serverKey, server.toString());
    if (pin == null) {
      await prefs.remove(_pinKey);
    } else {
      await prefs.setString(_pinKey, pin);
    }
  } catch (_) {
    // Not persisted: the user logs in again next time.
  }
}
