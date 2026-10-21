import 'dart:async';
import 'dart:io';

/// Installed on Windows, the app ships next to the server
/// (`<install>\server\bin\FoodKioskServer.exe`). When the configured server
/// is this PC and it is not answering, start it with no window and wait
/// until it is ready, so the app works with a double click and no browser.
Future<void> ensureLocalServer(Uri server) async {
  if (!Platform.isWindows) return;
  if (!const {'localhost', '127.0.0.1', '::1'}.contains(server.host)) return;
  if (await _healthy(server)) return;
  final install = File(Platform.resolvedExecutable).parent.parent.path;
  final exe = File('$install\\server\\bin\\FoodKioskServer.exe');
  if (!exe.existsSync()) return;
  try {
    await Process.start(
      exe.path,
      ['--background', '--port', '${server.port}'],
      workingDirectory: exe.parent.path,
      mode: ProcessStartMode.detached,
    );
  } on ProcessException {
    return;
  }
  final deadline = DateTime.now().add(const Duration(seconds: 20));
  while (DateTime.now().isBefore(deadline)) {
    if (await _healthy(server)) return;
    await Future<void>.delayed(const Duration(milliseconds: 300));
  }
}

Future<bool> _healthy(Uri server) async {
  final client = HttpClient()
    ..connectionTimeout = const Duration(milliseconds: 800);
  try {
    final req = await client.getUrl(server.resolve('/api/health'));
    final res = await req.close().timeout(const Duration(seconds: 2));
    await res.drain<void>();
    return res.statusCode == 200;
  } catch (_) {
    return false;
  } finally {
    client.close(force: true);
  }
}
