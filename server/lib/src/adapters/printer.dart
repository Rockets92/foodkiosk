import 'dart:io';
import 'dart:typed_data';

/// A printable ticket, independent of the printer language.
class Ticket {
  final List<TicketLine> lines;
  const Ticket(this.lines);

  /// Plain-text rendering, used by the demo printer and the print log.
  String toPlainText(int width) {
    final out = StringBuffer();
    for (final l in lines) {
      switch (l) {
        case TicketText(:final text, :final align):
          out.writeln(_align(text, width, align));
        case TicketSeparator():
          out.writeln('-' * width);
        case TicketRow(:final left, :final right):
          out.writeln(_row(left, right, width));
        case TicketFeed(:final lines):
          for (var i = 0; i < lines; i++) {
            out.writeln();
          }
        case TicketCut():
          out.writeln('✂${'-' * (width - 1)}');
      }
    }
    return out.toString();
  }
}

enum TicketAlign { left, center, right }

sealed class TicketLine {
  const TicketLine();
}

class TicketText extends TicketLine {
  final String text;
  final TicketAlign align;
  final bool bold;

  /// Double width and height, for the order number.
  final bool large;
  const TicketText(
    this.text, {
    this.align = TicketAlign.left,
    this.bold = false,
    this.large = false,
  });
}

/// Text on the left and right edges of the same line (item ... price).
class TicketRow extends TicketLine {
  final String left;
  final String right;
  final bool bold;
  const TicketRow(this.left, this.right, {this.bold = false});
}

class TicketSeparator extends TicketLine {
  const TicketSeparator();
}

class TicketFeed extends TicketLine {
  final int lines;
  const TicketFeed([this.lines = 1]);
}

class TicketCut extends TicketLine {
  const TicketCut();
}

String _align(String text, int width, TicketAlign align) {
  if (text.length >= width) return text;
  final pad = width - text.length;
  return switch (align) {
    TicketAlign.left => text,
    TicketAlign.right => ' ' * pad + text,
    TicketAlign.center => ' ' * (pad ~/ 2) + text,
  };
}

String _row(String left, String right, int width) {
  if (right.isEmpty) return left;
  final space = width - right.length - 1;
  if (left.length > space) {
    return '${left.substring(0, space)} $right';
  }
  return left + ' ' * (width - left.length - right.length) + right;
}

abstract class TicketPrinter {
  String get type;

  /// Characters per line (42 for 80mm paper, 32 for 58mm).
  int get width;

  Future<void> printTicket(Ticket ticket);
}

/// Prints nothing: the ticket only ends up in the print log, which the
/// admin panel can show. Handy on a PC without a thermal printer.
class DemoPrinter extends TicketPrinter {
  @override
  final int width;
  DemoPrinter({this.width = 42});

  @override
  String get type => 'demo';

  @override
  Future<void> printTicket(Ticket ticket) async {}
}

class NoPrinter extends TicketPrinter {
  @override
  String get type => 'none';
  @override
  int get width => 42;
  @override
  Future<void> printTicket(Ticket ticket) async {}
}

/// The printer attached to the totem itself (USB, or any printer installed
/// in Windows there). The server cannot reach it: the order service encodes
/// the ticket in ESC/POS and hands it back to the totem that placed the
/// order, which sends it to the printer chosen in its staff menu.
class KioskReceiptPrinter extends TicketPrinter {
  @override
  final int width;
  KioskReceiptPrinter({this.width = 42});

  factory KioskReceiptPrinter.fromOptions(Map<String, Object?> o) =>
      KioskReceiptPrinter(width: (o['width'] as num?)?.toInt() ?? 42);

  @override
  String get type => 'kiosk';

  Uint8List encode(Ticket ticket) => EscPosEncoder(width).encode(ticket);

  @override
  Future<void> printTicket(Ticket ticket) async =>
      throw StateError('the totem prints this ticket itself');
}

/// Thermal printer reachable over the network (raw port 9100), speaking
/// ESC/POS. Covers Epson TM, Star (ESC/POS mode), Custom and most
/// generic 80mm kiosk printers with an Ethernet interface.
class EscPosNetworkPrinter extends TicketPrinter {
  final String host;
  final int port;
  @override
  final int width;
  final Duration timeout;

  EscPosNetworkPrinter({
    required this.host,
    this.port = 9100,
    this.width = 42,
    this.timeout = const Duration(seconds: 5),
  });

  factory EscPosNetworkPrinter.fromOptions(Map<String, Object?> o) {
    final host = o['host'] as String?;
    if (host == null || host.isEmpty) {
      throw ArgumentError('escposNetwork printer needs a "host" option');
    }
    return EscPosNetworkPrinter(
      host: host,
      port: (o['port'] as num?)?.toInt() ?? 9100,
      width: (o['width'] as num?)?.toInt() ?? 42,
    );
  }

  @override
  String get type => 'escposNetwork';

  @override
  Future<void> printTicket(Ticket ticket) async {
    final socket = await Socket.connect(host, port, timeout: timeout);
    try {
      socket.add(EscPosEncoder(width).encode(ticket));
      await socket.flush();
    } finally {
      await socket.close();
    }
  }
}

/// Converts a [Ticket] into ESC/POS bytes (code page PC858, which has €).
class EscPosEncoder {
  final int width;
  EscPosEncoder(this.width);

  static const _esc = 0x1b;
  static const _gs = 0x1d;

  static const _cp858 = <String, int>{
    'Ç': 0x80, 'ü': 0x81, 'é': 0x82, 'â': 0x83, 'ä': 0x84, 'à': 0x85, //
    'ç': 0x87, 'ê': 0x88, 'ë': 0x89, 'è': 0x8a, 'ï': 0x8b, 'î': 0x8c,
    'ì': 0x8d, 'Ä': 0x8e, 'É': 0x90, 'ô': 0x93, 'ö': 0x94, 'ò': 0x95,
    'û': 0x96, 'ù': 0x97, 'Ö': 0x99, 'Ü': 0x9c, 'á': 0xa0, 'í': 0xa1,
    'ó': 0xa2, 'ú': 0xa3, 'ñ': 0xa4, 'Ñ': 0xa5, 'À': 0xb7, 'È': 0xd4,
    '€': 0xd5, 'Ì': 0xde, 'Ò': 0xe3, 'Ù': 0xeb, 'ß': 0xe1,
  };

  List<int> _text(String s) => [
    for (final rune in s.runes)
      if (rune < 0x80)
        rune
      else
        _cp858[String.fromCharCode(rune)] ?? 0x3f, // '?'
  ];

  Uint8List encode(Ticket ticket) {
    final b = BytesBuilder();
    b.add([_esc, 0x40]); // initialize
    b.add([_esc, 0x74, 19]); // code page PC858
    for (final l in ticket.lines) {
      switch (l) {
        case TicketText(:final text, :final align, :final bold, :final large):
          b.add([_esc, 0x61, align.index]);
          b.add([_esc, 0x45, bold ? 1 : 0]);
          b.add([_gs, 0x21, large ? 0x11 : 0x00]);
          b.add(_text(text));
          b.add([0x0a]);
          b.add([_gs, 0x21, 0x00, _esc, 0x45, 0, _esc, 0x61, 0]);
        case TicketRow(:final left, :final right, :final bold):
          b.add([_esc, 0x45, bold ? 1 : 0]);
          b.add(_text(_row(left, right, width)));
          b.add([0x0a, _esc, 0x45, 0]);
        case TicketSeparator():
          b.add(_text('-' * width));
          b.add([0x0a]);
        case TicketFeed(:final lines):
          b.add([_esc, 0x64, lines]);
        case TicketCut():
          b.add([_gs, 0x56, 0x42, 0x00]); // feed and partial cut
      }
    }
    return b.toBytes();
  }
}
