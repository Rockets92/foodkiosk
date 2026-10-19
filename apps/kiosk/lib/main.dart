import 'package:flutter/material.dart';

import 'src/api/kiosk_backend.dart';
import 'src/config.dart';
import 'src/state/kiosk_controller.dart';
import 'src/ui/kiosk_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(_Root(initialServer: await loadServerUri()));
}

/// Owns the controller and rebuilds it when staff change the server.
class _Root extends StatefulWidget {
  final Uri initialServer;
  const _Root({required this.initialServer});

  @override
  State<_Root> createState() => _RootState();
}

class _RootState extends State<_Root> {
  late KioskController _controller = _create(widget.initialServer);

  KioskController _create(Uri server) =>
      KioskController(HttpKioskBackend(server))..init();

  Future<void> _changeServer(Uri server) async {
    await saveServerUri(server);
    final old = _controller;
    setState(() => _controller = _create(server));
    old.dispose();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => KioskApp(
    key: ObjectKey(_controller),
    controller: _controller,
    onServerChanged: _changeServer,
  );
}
