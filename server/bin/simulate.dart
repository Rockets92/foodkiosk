import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:args/args.dart';
import 'package:kiosk_core/kiosk_core.dart';
// Only the simulator: the rest of the server (database) is not needed here.
import 'package:kiosk_server/src/simulator.dart';

/// Simulated customers: places random orders on a Food Kiosk server, as if
/// they came from the totems, so cashier, kitchen and pickup screens can be
/// tested with a realistic flow of orders.
///
///   dart run bin/simulate.dart --server http://192.168.1.20:8080 --rate 3
///
/// Started with no options (double click on Windows) it asks for them.
Future<void> main(List<String> args) async {
  final parser = ArgParser()
    ..addOption(
      'server',
      defaultsTo: 'http://localhost:8080',
      help: 'Address of the Food Kiosk server.',
    )
    ..addOption('rate', defaultsTo: '2', help: 'Average orders per minute.')
    ..addOption(
      'count',
      defaultsTo: '0',
      help: 'Stop after this many orders (0: until Ctrl+C).',
    )
    ..addFlag('help', abbr: 'h', negatable: false);
  final ArgResults opts;
  try {
    opts = parser.parse(args);
  } on FormatException catch (e) {
    stderr.writeln('${e.message}\n\n${parser.usage}');
    exit(64);
  }
  if (opts['help'] as bool) {
    stdout.writeln('Simulatore clienti Food Kiosk\n\n${parser.usage}');
    return;
  }

  var server = opts['server'] as String;
  var rate = double.tryParse(opts['rate'] as String) ?? 2;
  final count = int.tryParse(opts['count'] as String) ?? 0;
  if (args.isEmpty && stdin.hasTerminal) {
    server = _ask('Indirizzo del server', server);
    rate = double.tryParse(_ask('Ordini al minuto', '2')) ?? rate;
  }
  if (!server.contains('://')) server = 'http://$server';
  final base = Uri.parse(server.endsWith('/') ? server : '$server/');
  if (rate <= 0) rate = 2;

  final client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
  Future<(int, Object?)> send(String method, String path, Object? body) async {
    final req = await client.openUrl(method, base.resolve(path));
    req.headers.contentType = ContentType.json;
    if (body != null) req.write(jsonEncode(body));
    final res = await req.close().timeout(const Duration(seconds: 30));
    final text = await utf8.decodeStream(res);
    return (res.statusCode, text.isEmpty ? null : jsonDecode(text));
  }

  final random = Random();
  final simulator = CustomerSimulator(send, random: random);
  stdout.writeln(
    'Simulatore clienti: ${_rate(rate)} ordini al minuto verso $base'
    '${count > 0 ? ', $count ordini' : ''}. Ctrl+C per fermarlo.\n',
  );
  ProcessSignal.sigint.watch().listen((_) {
    client.close(force: true);
    exit(0);
  });

  var placed = 0;
  while (count == 0 || placed < count) {
    try {
      final r = await simulator.placeOne();
      placed++;
      final o = r.order;
      final items = o.lines.fold(0, (n, l) => n + l.quantity);
      stdout.writeln(
        '${_time()}  ordine ${o.displayNumber}  '
        '${items == 1 ? '1 prodotto' : '$items prodotti'}  '
        '${formatCents(o.totalCents)}  '
        '${o.serviceMode == ServiceMode.takeAway ? 'da asporto' : 'mangio qui'}'
        '  ${r.outcome}',
      );
    } on Object catch (e) {
      stdout.writeln('${_time()}  server non raggiungibile o errore: $e');
    }
    if (count > 0 && placed >= count) break;
    // Customers arrive at random: exponential gaps around the mean rate.
    final seconds = -log(1 - random.nextDouble()) * 60 / rate;
    await Future<void>.delayed(
      Duration(milliseconds: (min(seconds, 600) * 1000).round()),
    );
  }
  client.close(force: true);
  // The Ctrl+C listener would keep the process alive.
  await stdout.flush();
  exit(0);
}

String _ask(String label, String fallback) {
  stdout.write('$label [$fallback]: ');
  final line = stdin.readLineSync()?.trim() ?? '';
  return line.isEmpty ? fallback : line;
}

String _rate(double r) =>
    r == r.roundToDouble() ? r.round().toString() : r.toString();

String _time() {
  final t = DateTime.now();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(t.hour)}:${two(t.minute)}:${two(t.second)}';
}
