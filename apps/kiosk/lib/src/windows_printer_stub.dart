import 'dart:typed_data';

/// On the web there is no local printer: the server prints.
bool get canPrintLocally => false;

List<String> installedPrinters() => const [];

String? defaultPrinter() => null;

Future<void> printRaw(String printer, Uint8List data) async =>
    throw UnsupportedError('No local printer on this platform');
