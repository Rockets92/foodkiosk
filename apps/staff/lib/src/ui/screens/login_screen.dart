import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../api.dart';
import '../../session.dart';
import '../theme.dart';

/// PIN keypad, with the server address one tap away. The pickup screen
/// needs no PIN.
class LoginScreen extends StatefulWidget {
  final Uri initialServer;
  final void Function(StaffSession session, Uri server) onLoggedIn;
  final void Function(Uri server) onPickupOnly;
  final StaffApi Function(Uri server, String pin) apiFactory;

  const LoginScreen({
    super.key,
    required this.initialServer,
    this.apiFactory = StaffApi.new,
    required this.onLoggedIn,
    required this.onPickupOnly,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late final _server = TextEditingController(
    text: widget.initialServer.toString(),
  );
  late final String? _logoUrl = widget
      .apiFactory(widget.initialServer, '')
      .imageUrl('/media/placeholder/logo.svg');
  String _pin = '';
  String? _error;
  bool _busy = false;
  bool _showServer = false;

  Uri? get _serverUri {
    var text = _server.text.trim();
    if (text.isEmpty) return null;
    if (!text.startsWith('http')) text = 'http://$text';
    if (!text.endsWith('/')) text = '$text/';
    return Uri.tryParse(text);
  }

  Future<void> _submit() async {
    final server = _serverUri;
    if (server == null || _pin.length < 4) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final session = await StaffSession.open(widget.apiFactory(server, _pin));
      widget.onLoggedIn(session, server);
    } on ApiError catch (e) {
      setState(() {
        _error = e.isUnauthorized ? 'PIN errato' : e.message;
        if (e.isNetwork) _showServer = true;
        _pin = '';
        _busy = false;
      });
    }
  }

  void _key(String k) {
    if (_busy) return;
    setState(() {
      _error = null;
      if (k == '⌫') {
        if (_pin.isNotEmpty) _pin = _pin.substring(0, _pin.length - 1);
      } else if (_pin.length < 8) {
        _pin += k;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1E1E24), S.nav],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(32),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_logoUrl case final logo?)
                      SvgPicture.network(
                        logo,
                        width: 72,
                        height: 72,
                        colorMapper: PaletteColorMapper(S.palette),
                        placeholderBuilder: (_) =>
                            const SizedBox.square(dimension: 72),
                        errorBuilder: (_, _, _) =>
                            const SizedBox.square(dimension: 72),
                      ),
                    const SizedBox(height: 12),
                    const Text('Area staff', style: ST.h1),
                    const Text(
                      'Cassa, cucina e gestione del locale',
                      style: ST.small,
                    ),
                    const SizedBox(height: 24),
                    _PinDots(length: _pin.length, error: _error != null),
                    SizedBox(
                      height: 28,
                      child: _error == null
                          ? null
                          : Center(
                              child: Text(
                                _error!,
                                key: const ValueKey('login-error'),
                                style: const TextStyle(
                                  color: S.danger,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                    ),
                    _Keypad(onKey: _key),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        key: const ValueKey('login'),
                        onPressed: _pin.length >= 4 && !_busy ? _submit : null,
                        child: _busy
                            ? const SizedBox.square(
                                dimension: 22,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 3,
                                ),
                              )
                            : const Text('Entra'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    AnimatedSize(
                      duration: S.medium,
                      child: _showServer
                          ? Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: TextField(
                                key: const ValueKey('server-url'),
                                controller: _server,
                                decoration: const InputDecoration(
                                  labelText: 'Indirizzo del server',
                                  hintText: 'http://192.168.1.10:8080',
                                  prefixIcon: Icon(Icons.dns_rounded),
                                ),
                              ),
                            )
                          : const SizedBox(width: double.infinity),
                    ),
                    SizedBox(
                      width: double.infinity,
                      child: Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        children: [
                          TextButton.icon(
                            onPressed: () =>
                                setState(() => _showServer = !_showServer),
                            icon: const Icon(Icons.settings_ethernet_rounded),
                            label: const Text('Server'),
                          ),
                          TextButton.icon(
                            key: const ValueKey('pickup-only'),
                            onPressed: () {
                              final s = _serverUri;
                              if (s != null) widget.onPickupOnly(s);
                            },
                            icon: const Icon(Icons.tv_rounded),
                            label: const Text('Schermo ritiro'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.05),
            ),
          ),
        ),
      ),
    );
  }
}

class _PinDots extends StatelessWidget {
  final int length;
  final bool error;
  const _PinDots({required this.length, required this.error});

  @override
  Widget build(BuildContext context) {
    final dots = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < 4 || i < length; i++)
          AnimatedContainer(
            duration: S.fast,
            margin: const EdgeInsets.symmetric(horizontal: 7),
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i < length ? (error ? S.danger : S.ink) : S.line,
            ),
          ),
      ],
    );
    return error ? dots.animate().shake(hz: 5, duration: 400.ms) : dots;
  }
}

class _Keypad extends StatelessWidget {
  final void Function(String) onKey;
  const _Keypad({required this.onKey});

  @override
  Widget build(BuildContext context) {
    const keys = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '', '0', '⌫'];
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.7,
      children: [
        for (final k in keys)
          if (k.isEmpty)
            const SizedBox()
          else
            Material(
              color: const Color(0xFFF4F1EC),
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                key: ValueKey('key-$k'),
                borderRadius: BorderRadius.circular(16),
                onTap: () => onKey(k),
                child: Center(
                  child: k == '⌫'
                      ? const Icon(Icons.backspace_outlined)
                      : Text(
                          k,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
            ),
      ],
    );
  }
}
