import 'dart:io';

import 'package:args/args.dart';
import 'package:kiosk_server/kiosk_server.dart';
import 'package:path/path.dart' as p;
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_static/shelf_static.dart';

Future<void> main(List<String> args) async {
  final parser = ArgParser()
    ..addOption('host', defaultsTo: '0.0.0.0', help: 'Address to listen on.')
    ..addOption('port', defaultsTo: '8080', help: 'Port to listen on.')
    ..addOption(
      'data-dir',
      defaultsTo: 'data',
      help: 'Folder for the database and uploaded media.',
    )
    ..addOption(
      'kiosk-web',
      help:
          'Folder with the kiosk web build, served at /kiosk/ '
          '(flutter build web --base-href /kiosk/).',
    )
    ..addFlag(
      'no-demo-menu',
      negatable: false,
      help: 'Start with an empty menu instead of the demo one.',
    )
    ..addFlag('help', abbr: 'h', negatable: false);
  final opts = parser.parse(args);
  if (opts['help'] as bool) {
    stdout.writeln('Food Kiosk server\n\n${parser.usage}');
    return;
  }

  final dataDir = Directory(opts['data-dir'] as String)
    ..createSync(recursive: true);
  final mediaDir = Directory(p.join(dataDir.path, 'media'))..createSync();
  final app = KioskApp(
    AppDatabase.open(p.join(dataDir.path, 'foodkiosk.db')),
    seedDemo: !(opts['no-demo-menu'] as bool),
    mediaHandler: createStaticHandler(mediaDir.path),
  );

  final kioskWeb = opts['kiosk-web'] as String?;
  final kioskHandler = kioskWeb == null
      ? null
      : createStaticHandler(kioskWeb, defaultDocument: 'index.html');
  final handler = const Pipeline().addMiddleware(logRequests()).addHandler((
    Request req,
  ) {
    if (kioskHandler != null && req.url.path == 'kiosk') {
      return Response.found('/kiosk/');
    }
    if (kioskHandler != null && req.url.path.startsWith('kiosk/')) {
      return kioskHandler(req.change(path: 'kiosk'));
    }
    return app.handler(req);
  });
  final server = await io.serve(
    handler,
    opts['host'] as String,
    int.parse(opts['port'] as String),
  );
  final s = app.settings.current;
  stdout.writeln(
    'Food Kiosk server on http://${server.address.host}:${server.port}',
  );
  stdout.writeln('  data:  ${p.absolute(dataDir.path)}');
  if (kioskWeb != null) {
    stdout.writeln('  kiosk: http://localhost:${server.port}/kiosk/');
  }
  stdout.writeln(
    '  mode:  ${s.demoMode ? 'DEMO (payments simulated)' : 'production'}',
  );
  stdout.writeln('  flow:  payment=${s.flow.paymentMode.name}');

  ProcessSignal.sigint.watch().listen((_) async {
    await server.close();
    await app.close();
    exit(0);
  });
}
