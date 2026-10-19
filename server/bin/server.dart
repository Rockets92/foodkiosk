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
      help:
          'Folder for the database and uploaded media. On Windows the '
          'default is %ProgramData%\\FoodKiosk\\data.',
    )
    ..addOption(
      'kiosk-web',
      help:
          'Folder with the kiosk web build, served at /kiosk/ '
          '(flutter build web --base-href /kiosk/). Default: web/kiosk '
          'next to the executable, when present.',
    )
    ..addOption(
      'staff-web',
      help:
          'Folder with the staff app web build (cashier, kitchen, pickup '
          'screen, admin), served at /staff/. Default: web/staff next to '
          'the executable, when present.',
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

  final programData = Platform.environment['ProgramData'];
  final dataPath = !opts.wasParsed('data-dir') && programData != null
      ? p.join(programData, 'FoodKiosk', 'data')
      : opts['data-dir'] as String;
  final dataDir = Directory(dataPath)..createSync(recursive: true);
  final mediaDir = Directory(p.join(dataDir.path, 'media'))..createSync();
  final app = KioskApp(
    AppDatabase.open(p.join(dataDir.path, 'foodkiosk.db')),
    seedDemo: !(opts['no-demo-menu'] as bool),
    mediaHandler: createStaticHandler(mediaDir.path),
    mediaDir: mediaDir.path,
  );

  // Web apps: an explicit folder, or the one shipped with the exe (the
  // Windows package has server/bin/server.exe and web/ at the top).
  final exeDir = p.dirname(Platform.resolvedExecutable);
  String? webDir(String option, String name) {
    final explicit = opts[option] as String?;
    if (explicit != null) return explicit;
    for (final up in ['.', '..', '../..']) {
      final bundled = p.normalize(p.join(exeDir, up, 'web', name));
      if (File(p.join(bundled, 'index.html')).existsSync()) return bundled;
    }
    return null;
  }

  final webApps = <String, Handler>{
    for (final name in ['kiosk', 'staff'])
      if (webDir('$name-web', name) case final dir?)
        name: createStaticHandler(dir, defaultDocument: 'index.html'),
  };
  final handler = const Pipeline().addMiddleware(logRequests()).addHandler((
    Request req,
  ) {
    final path = req.url.path;
    if (path.isEmpty && webApps.containsKey('kiosk')) {
      return Response.found('/kiosk/');
    }
    for (final MapEntry(key: name, value: web) in webApps.entries) {
      if (path == name) return Response.found('/$name/');
      if (path.startsWith('$name/')) return web(req.change(path: name));
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
  for (final name in webApps.keys) {
    stdout.writeln('  $name: http://localhost:${server.port}/$name/');
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
