import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:kiosk_core/kiosk_core.dart';

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
  ColorPalette _palette = ColorPalette.fallback;
  late ThemeData _theme = staffTheme(_palette);
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
      _follow(_session!);
    } else {
      _restore();
    }
  }

  @override
  void dispose() {
    _session?.removeListener(_syncPalette);
    super.dispose();
  }

  void _usePalette(ColorPalette next) {
    if (next.id == _palette.id || !mounted) return;
    setState(() {
      _palette = next;
      _theme = staffTheme(next);
    });
    rebuildAll(context);
  }

  /// Logged in: the palette follows the session settings live.
  void _follow(StaffSession session) {
    session.addListener(_syncPalette);
    _palette = session.settings.colors;
    _theme = staffTheme(_palette);
  }

  void _syncPalette() {
    if (_session case final s?) _usePalette(s.settings.colors);
  }

  /// Not logged in (login, pickup screen): read the public settings.
  Future<void> _loadPublicPalette(StaffApi api) async {
    try {
      _usePalette((await api.publicSettings()).colors);
    } catch (_) {
      // Server not reachable yet: keep the current palette.
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
      if (session != null) _follow(session);
    });
    if (session == null) _loadPublicPalette(widget.apiFactory(server, ''));
  }

  void _loggedIn(StaffSession session, Uri server) {
    saveLogin(server, session.api.pin);
    setState(() {
      _server = server;
      _session = session;
      _follow(session);
    });
  }

  void _logout() {
    final s = _session;
    if (_server != null) saveLogin(_server!, null);
    s?.removeListener(_syncPalette);
    setState(() {
      _session = null;
      _pickupApi = null;
    });
    s?.dispose();
  }

  void _openPickup(Uri server) {
    final api = widget.apiFactory(server, '');
    setState(() => _pickupApi = api);
    _loadPublicPalette(api);
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
        onPickupOnly: _openPickup,
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
