import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../api.dart';
import '../config.dart';
import '../local_server.dart';
import '../session.dart';
import 'screens/login_screen.dart';
import 'screens/pickup_screen.dart';
import 'shell.dart';
import 'theme.dart';

/// Root: login, then the staff shell; or the pickup screen alone.
class StaffApp extends StatefulWidget {
  /// Tests inject a ready session, or the API used at login.
  final StaffSession? session;
  final StaffApi Function(Uri server, String pin) apiFactory;

  const StaffApp({super.key, this.session, this.apiFactory = StaffApi.new});

  @override
  State<StaffApp> createState() => _StaffAppState();
}

class _StaffAppState extends State<StaffApp> {
  final _theme = staffTheme();
  StaffSession? _session;
  StaffApi? _pickupApi;
  Uri? _server;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _session = widget.session;
    if (_session != null) {
      _loading = false;
    } else {
      _restore();
    }
  }

  Future<void> _restore() async {
    final server = await loadServerUri();
    await ensureLocalServer(server);
    final pin = await loadPin();
    StaffSession? session;
    if (pin != null) {
      try {
        session = await StaffSession.open(widget.apiFactory(server, pin));
      } on ApiError {
        session = null;
      }
    }
    if (!mounted) return;
    setState(() {
      _server = server;
      _session = session;
      _loading = false;
    });
  }

  void _loggedIn(StaffSession session, Uri server) {
    saveLogin(server, session.api.pin);
    setState(() {
      _server = server;
      _session = session;
    });
  }

  void _logout() {
    final s = _session;
    if (_server != null) saveLogin(_server!, null);
    setState(() {
      _session = null;
      _pickupApi = null;
    });
    s?.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget home;
    if (_loading) {
      home = const Scaffold(body: Center(child: CircularProgressIndicator()));
    } else if (_pickupApi case final api?) {
      home = PickupScreen(
        api: api,
        onExit: () => setState(() => _pickupApi = null),
      );
    } else if (_session case final session?) {
      home = StaffScope(
        session: session,
        child: StaffShell(onLogout: _logout),
      );
    } else {
      home = LoginScreen(
        initialServer: _server ?? defaultServerUri(),
        apiFactory: widget.apiFactory,
        onLoggedIn: _loggedIn,
        onPickupOnly: (server) =>
            setState(() => _pickupApi = widget.apiFactory(server, '')),
      );
    }
    return MaterialApp(
      title: 'Food Kiosk Staff',
      debugShowCheckedModeBanner: false,
      theme: _theme,
      locale: const Locale('it'),
      supportedLocales: const [Locale('it'), Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: home,
    );
  }
}
