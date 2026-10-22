import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Reads a QR/barcode reader connected as a USB keyboard (the default mode
/// of almost every reader): it "types" the code very fast, usually followed
/// by Enter. Keys typed at human speed, or into a text field, are ignored.
class ScannerListener extends StatefulWidget {
  final bool enabled;
  final ValueChanged<String> onScan;
  final Widget child;

  /// Readers type a character every few milliseconds; a person needs far
  /// more than this between two keys.
  static const maxGap = Duration(milliseconds: 60);

  /// Readers set up without the Enter suffix: the code ends when the keys
  /// stop for this long.
  static const endPause = Duration(milliseconds: 150);

  static const minLength = 3;

  const ScannerListener({
    super.key,
    required this.enabled,
    required this.onScan,
    required this.child,
  });

  @override
  State<ScannerListener> createState() => _ScannerListenerState();
}

class _ScannerListenerState extends State<ScannerListener> {
  final _buffer = StringBuffer();
  DateTime _last = DateTime.fromMillisecondsSinceEpoch(0);
  Timer? _end;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    _end?.cancel();
    super.dispose();
  }

  bool get _typingInField {
    final ctx = FocusManager.instance.primaryFocus?.context;
    if (ctx == null) return false;
    return ctx.widget is EditableText ||
        ctx.findAncestorWidgetOfExactType<EditableText>() != null;
  }

  bool _onKey(KeyEvent event) {
    if (!widget.enabled || event is KeyUpEvent || _typingInField) {
      return false;
    }
    final now = DateTime.now();
    if (now.difference(_last) > ScannerListener.maxGap) _buffer.clear();
    _last = now;
    _end?.cancel();
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter ||
        key == LogicalKeyboardKey.tab) {
      return _flush();
    }
    final char = event.character;
    if (char == null || char.isEmpty || char.codeUnitAt(0) < 32) return false;
    _buffer.write(char);
    _end = Timer(ScannerListener.endPause, _flush);
    // Keep the characters to ourselves only once it is clearly a scan.
    return _buffer.length >= ScannerListener.minLength;
  }

  bool _flush() {
    _end?.cancel();
    final code = _buffer.toString().trim();
    _buffer.clear();
    if (code.length < ScannerListener.minLength) return false;
    widget.onScan(code);
    return true;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
