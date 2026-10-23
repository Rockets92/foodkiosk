import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

/// Printers installed in Windows, through the spooler (winspool). Any
/// printer Windows can print to works: USB thermal printers with the
/// maker's driver or with "Generic / Text Only". The ticket (ESC/POS
/// bytes) reaches the printer untouched, as a RAW document.
bool get canPrintLocally => Platform.isWindows;

/// Names of the printers installed on this PC, local and shared.
List<String> installedPrinters() {
  if (!Platform.isWindows) return const [];
  const flags = 0x2 | 0x4; // PRINTER_ENUM_LOCAL | PRINTER_ENUM_CONNECTIONS
  return using((arena) {
    final needed = arena<Uint32>();
    final count = arena<Uint32>();
    _api.enumPrinters(flags, nullptr, 4, nullptr, 0, needed, count);
    if (needed.value == 0) return const <String>[];
    final buffer = arena<Uint8>(needed.value);
    if (_api.enumPrinters(
          flags,
          nullptr,
          4,
          buffer,
          needed.value,
          needed,
          count,
        ) ==
        0) {
      return const <String>[];
    }
    final infos = buffer.cast<_PrinterInfo4>();
    return [
      for (var i = 0; i < count.value; i++) infos[i].printerName.toDartString(),
    ];
  });
}

/// The Windows default printer, if there is one.
String? defaultPrinter() {
  if (!Platform.isWindows) return null;
  return using((arena) {
    final size = arena<Uint32>();
    _api.getDefaultPrinter(nullptr, size);
    if (size.value == 0) return null;
    final name = arena<Uint16>(size.value).cast<Utf16>();
    if (_api.getDefaultPrinter(name, size) == 0) return null;
    return name.toDartString();
  });
}

/// Sends [data] to [printer] as it is, off the UI thread (a shared
/// printer can take a moment to answer).
Future<void> printRaw(String printer, Uint8List data) =>
    Isolate.run(() => _printRaw(printer, data));

void _printRaw(String printer, Uint8List data) {
  if (!Platform.isWindows) {
    throw UnsupportedError('Local printing needs Windows');
  }
  using((arena) {
    final handle = arena<IntPtr>();
    if (_api.openPrinter(
          printer.toNativeUtf16(allocator: arena),
          handle,
          nullptr,
        ) ==
        0) {
      throw StateError('Stampante "$printer" non trovata');
    }
    final h = handle.value;
    try {
      final doc = arena<_DocInfo1>();
      doc.ref
        ..docName = 'Food Kiosk'.toNativeUtf16(allocator: arena)
        ..outputFile = nullptr
        ..datatype = 'RAW'.toNativeUtf16(allocator: arena);
      if (_api.startDocPrinter(h, 1, doc) == 0) {
        throw StateError(
          'La stampante "$printer" non accetta la stampa diretta (RAW)',
        );
      }
      try {
        _api.startPagePrinter(h);
        final buffer = arena<Uint8>(data.length);
        buffer.asTypedList(data.length).setAll(0, data);
        final written = arena<Uint32>();
        final ok = _api.writePrinter(h, buffer, data.length, written);
        _api.endPagePrinter(h);
        if (ok == 0 || written.value != data.length) {
          throw StateError('Invio alla stampante "$printer" non riuscito');
        }
      } finally {
        _api.endDocPrinter(h);
      }
    } finally {
      _api.closePrinter(h);
    }
  });
}

final class _DocInfo1 extends Struct {
  external Pointer<Utf16> docName;
  external Pointer<Utf16> outputFile;
  external Pointer<Utf16> datatype;
}

final class _PrinterInfo4 extends Struct {
  external Pointer<Utf16> printerName;
  external Pointer<Utf16> serverName;
  @Uint32()
  external int attributes;
}

/// The winspool.drv functions used here, loaded on first use.
final _api = _Winspool(DynamicLibrary.open('winspool.drv'));

class _Winspool {
  final int Function(Pointer<Utf16>, Pointer<IntPtr>, Pointer<Void>)
  openPrinter;
  final int Function(int) closePrinter;
  final int Function(int, int, Pointer<_DocInfo1>) startDocPrinter;
  final int Function(int) endDocPrinter;
  final int Function(int) startPagePrinter;
  final int Function(int) endPagePrinter;
  final int Function(int, Pointer<Uint8>, int, Pointer<Uint32>) writePrinter;
  final int Function(
    int,
    Pointer<Utf16>,
    int,
    Pointer<Uint8>,
    int,
    Pointer<Uint32>,
    Pointer<Uint32>,
  )
  enumPrinters;
  final int Function(Pointer<Utf16>, Pointer<Uint32>) getDefaultPrinter;

  _Winspool(DynamicLibrary lib)
    : openPrinter = lib
          .lookupFunction<
            Int32 Function(Pointer<Utf16>, Pointer<IntPtr>, Pointer<Void>),
            int Function(Pointer<Utf16>, Pointer<IntPtr>, Pointer<Void>)
          >('OpenPrinterW'),
      closePrinter = lib
          .lookupFunction<Int32 Function(IntPtr), int Function(int)>(
            'ClosePrinter',
          ),
      startDocPrinter = lib
          .lookupFunction<
            Uint32 Function(IntPtr, Uint32, Pointer<_DocInfo1>),
            int Function(int, int, Pointer<_DocInfo1>)
          >('StartDocPrinterW'),
      endDocPrinter = lib
          .lookupFunction<Int32 Function(IntPtr), int Function(int)>(
            'EndDocPrinter',
          ),
      startPagePrinter = lib
          .lookupFunction<Int32 Function(IntPtr), int Function(int)>(
            'StartPagePrinter',
          ),
      endPagePrinter = lib
          .lookupFunction<Int32 Function(IntPtr), int Function(int)>(
            'EndPagePrinter',
          ),
      writePrinter = lib
          .lookupFunction<
            Int32 Function(IntPtr, Pointer<Uint8>, Uint32, Pointer<Uint32>),
            int Function(int, Pointer<Uint8>, int, Pointer<Uint32>)
          >('WritePrinter'),
      enumPrinters = lib
          .lookupFunction<
            Int32 Function(
              Uint32,
              Pointer<Utf16>,
              Uint32,
              Pointer<Uint8>,
              Uint32,
              Pointer<Uint32>,
              Pointer<Uint32>,
            ),
            int Function(
              int,
              Pointer<Utf16>,
              int,
              Pointer<Uint8>,
              int,
              Pointer<Uint32>,
              Pointer<Uint32>,
            )
          >('EnumPrintersW'),
      getDefaultPrinter = lib
          .lookupFunction<
            Int32 Function(Pointer<Utf16>, Pointer<Uint32>),
            int Function(Pointer<Utf16>, Pointer<Uint32>)
          >('GetDefaultPrinterW');
}
