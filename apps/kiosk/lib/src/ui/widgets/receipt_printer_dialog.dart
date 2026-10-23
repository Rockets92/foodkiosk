import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../config.dart';
import '../../state/kiosk_controller.dart';
import '../../windows_printer.dart';

/// Staff menu page that picks the Windows printer (USB thermal printer,
/// usually) for the customer's receipt, with a test print.
class ReceiptPrinterDialog extends StatefulWidget {
  final KioskController kiosk;
  const ReceiptPrinterDialog({super.key, required this.kiosk});

  @override
  State<ReceiptPrinterDialog> createState() => _ReceiptPrinterDialogState();
}

class _ReceiptPrinterDialogState extends State<ReceiptPrinterDialog> {
  final List<String> _printers = installedPrinters();
  final String? _default = defaultPrinter();

  /// Null: the Windows default printer.
  String? _chosen;
  bool _loaded = false;
  bool _testing = false;
  String? _testResult;
  bool _testFailed = false;

  @override
  void initState() {
    super.initState();
    loadReceiptPrinter().then((name) {
      if (!mounted) return;
      setState(() {
        _chosen = name;
        _loaded = true;
      });
    });
  }

  String? get _target => _chosen ?? _default;

  Future<void> _test() async {
    final target = _target;
    if (target == null) return;
    setState(() {
      _testing = true;
      _testResult = null;
    });
    try {
      await printRaw(target, testTicket(target));
      _testResult = 'Stampa di prova inviata a "$target"';
      _testFailed = false;
    } catch (e) {
      _testResult = '$e';
      _testFailed = true;
    }
    if (mounted) setState(() => _testing = false);
  }

  Widget _option(String? name, String label) {
    final selected = _chosen == name;
    return ListTile(
      key: ValueKey('printer-${name ?? 'default'}'),
      leading: Icon(
        selected ? Icons.radio_button_checked : Icons.radio_button_off,
        color: selected ? Theme.of(context).colorScheme.primary : null,
      ),
      title: Text(label, style: const TextStyle(fontSize: 20)),
      onTap: () => setState(() => _chosen = name),
    );
  }

  @override
  Widget build(BuildContext context) {
    final serverSendsReceipts =
        widget.kiosk.settings.customerPrinter.type == 'kiosk';
    final error = widget.kiosk.lastPrintError;
    return AlertDialog(
      title: const Text('Stampante ricevute'),
      content: SizedBox(
        width: 560,
        child: !_loaded
            ? const SizedBox(
                height: 120,
                child: Center(child: CircularProgressIndicator()),
              )
            : ListView(
                shrinkWrap: true,
                children: [
                  _Note(
                    ok: serverSendsReceipts,
                    text: serverSendsReceipts
                        ? 'Il server manda a questo totem le ricevute dei '
                              'suoi ordini.'
                        : 'Il server ora non manda le ricevute al totem. '
                              "Nell'app staff vai in Impostazioni → "
                              'Dispositivi → Stampante scontrini cliente e '
                              'scegli "Stampante del totem (USB o Windows)".',
                  ),
                  const SizedBox(height: 8),
                  if (!canPrintLocally)
                    const Text('Stampa diretta disponibile solo su Windows.')
                  else ...[
                    _option(
                      null,
                      _default == null
                          ? 'Predefinita di Windows (nessuna)'
                          : 'Predefinita di Windows ($_default)',
                    ),
                    for (final p in _printers) _option(p, p),
                    if (_chosen != null && !_printers.contains(_chosen))
                      _option(_chosen, '$_chosen (non trovata)'),
                  ],
                  if (error != null)
                    _Note(
                      ok: false,
                      text: 'Ultima ricevuta non stampata: $error',
                    ),
                  if (_testResult case final result?)
                    _Note(ok: !_testFailed, text: result),
                ],
              ),
      ),
      actions: [
        if (canPrintLocally)
          TextButton.icon(
            key: const ValueKey('printer-test'),
            onPressed: _testing || _target == null ? null : _test,
            icon: const Icon(Icons.print_rounded),
            label: const Text('Stampa di prova'),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annulla'),
        ),
        FilledButton(
          key: const ValueKey('printer-save'),
          onPressed: !_loaded
              ? null
              : () async {
                  await saveReceiptPrinter(_chosen);
                  if (context.mounted) Navigator.pop(context);
                },
          child: const Text('Salva'),
        ),
      ],
    );
  }
}

class _Note extends StatelessWidget {
  final bool ok;
  final String text;
  const _Note({required this.ok, required this.text});

  @override
  Widget build(BuildContext context) {
    final color = ok ? const Color(0xFF1B7F3B) : const Color(0xFFB3261E);
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            ok ? Icons.check_circle_rounded : Icons.info_rounded,
            color: color,
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 16))),
        ],
      ),
    );
  }
}

/// A short ESC/POS ticket to check paper, cutter and code page.
Uint8List testTicket(String printer) {
  final now = DateTime.now();
  String two(int n) => n.toString().padLeft(2, '0');
  List<int> line(String s) => [
    for (final c in s.codeUnits) c < 0x80 ? c : 0x3f,
    0x0a,
  ];
  return Uint8List.fromList([
    0x1b, 0x40, // initialize
    0x1b, 0x61, 1, // center
    0x1d, 0x21, 0x11, // double size
    ...line('FOOD KIOSK'),
    0x1d, 0x21, 0x00,
    ...line('Stampa di prova'),
    ...line(printer),
    ...line(
      '${two(now.day)}/${two(now.month)}/${now.year} '
      '${two(now.hour)}:${two(now.minute)}',
    ),
    0x1b, 0x64, 4, // feed
    0x1d, 0x56, 0x42, 0x00, // feed and partial cut
  ]);
}
