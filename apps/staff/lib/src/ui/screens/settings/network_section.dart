import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../api.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import 'fields.dart';

/// The address other PCs and tablets use to reach the server, and the
/// devices connected right now: what you need to set up a totem, a kitchen
/// PC or a pickup monitor on the local network.
class NetworkSection extends StatefulWidget {
  final StaffApi api;
  final Duration refresh;

  const NetworkSection({
    super.key,
    required this.api,
    this.refresh = const Duration(seconds: 5),
  });

  @override
  State<NetworkSection> createState() => _NetworkSectionState();
}

class _NetworkSectionState extends State<NetworkSection> {
  NetworkInfo? _info;
  bool _failed = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(widget.refresh, (_) => _load());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final info = await widget.api.network();
      if (mounted) {
        setState(() {
          _info = info;
          _failed = false;
        });
      }
    } on ApiError {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final info = _info;
    final port = widget.api.baseUri.port;
    final urls = [for (final a in info?.addresses ?? []) 'http://$a:$port'];
    return SectionCard(
      icon: Icons.lan_rounded,
      title: 'Rete',
      subtitle: 'Collega altri totem, la cucina e lo schermo ritiro',
      accent: S.success,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Indirizzo del server', style: ST.h3),
          const SizedBox(height: 4),
          Text(
            info == null || info.hostname.isEmpty
                ? 'Da inserire sugli altri dispositivi della stessa rete.'
                : 'Il server gira sul PC "${info.hostname}". Inserisci '
                      'questo indirizzo sugli altri dispositivi della stessa '
                      'rete.',
            style: ST.small,
          ),
          const SizedBox(height: 10),
          if (info == null && !_failed)
            const LinearProgressIndicator()
          else if (urls.isEmpty)
            Text(
              _failed
                  ? 'Impossibile leggere le informazioni di rete dal server.'
                  : 'Il PC del server non è collegato a nessuna rete.',
              style: ST.body.copyWith(color: S.warning),
            )
          else
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [for (final u in urls) _AddressChip(url: u)],
            ),
          const SizedBox(height: 14),
          const Text(
            'Sul totem: tieni premuto 3 secondi l\'angolo in alto a '
            'sinistra, PIN, "Indirizzo server". Nell\'app staff: tocca '
            '"Server" nella schermata di accesso, poi "Entra" o "Schermo '
            'ritiro". Se gli altri dispositivi non si collegano, su questo '
            'PC consenti FoodKioskServer nel firewall di Windows (rete '
            'privata).',
            style: ST.small,
          ),
          const SizedBox(height: 22),
          Text('Collegati ora (${info?.devices.length ?? 0})', style: ST.h3),
          const SizedBox(height: 6),
          if (info != null && info.devices.isEmpty)
            const Text('Nessun dispositivo collegato.', style: ST.small),
          for (final d in info?.devices ?? const <ConnectedDevice>[])
            _DeviceRow(device: d, local: _isLocal(d.address, info!)),
        ],
      ),
    );
  }

  static bool _isLocal(String address, NetworkInfo info) =>
      address == '127.0.0.1' ||
      address == '::1' ||
      address.isEmpty ||
      info.addresses.contains(address);
}

class _AddressChip extends StatelessWidget {
  final String url;
  const _AddressChip({required this.url});

  @override
  Widget build(BuildContext context) => Container(
    key: ValueKey('address-$url'),
    padding: const EdgeInsets.fromLTRB(16, 6, 6, 6),
    decoration: BoxDecoration(
      color: S.success.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SelectableText(
          url,
          style: ST.h2.copyWith(fontFamily: 'monospace', fontSize: 20),
        ),
        const SizedBox(width: 6),
        IconButton(
          tooltip: 'Copia',
          icon: const Icon(Icons.copy_rounded, size: 20),
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: url));
            if (context.mounted) showMessage(context, 'Indirizzo copiato');
          },
        ),
      ],
    ),
  );
}

class _DeviceRow extends StatelessWidget {
  final ConnectedDevice device;
  final bool local;
  const _DeviceRow({required this.device, required this.local});

  @override
  Widget build(BuildContext context) {
    final (label, icon) = switch (device.kind) {
      'totem' => ('Totem', Icons.touch_app_rounded),
      'staff' => ('Postazione staff', Icons.point_of_sale_rounded),
      'pickup' => ('Schermo ritiro', Icons.tv_rounded),
      _ => ('Altro dispositivo', Icons.devices_other_rounded),
    };
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: S.inkSoft),
      title: Text(label, style: ST.body),
      subtitle: Text(local ? 'Questo PC' : device.address, style: ST.small),
      trailing: Text('da ${hhmm(device.since)}', style: ST.small),
    );
  }
}
