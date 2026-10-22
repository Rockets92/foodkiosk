import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:kiosk_core/kiosk_core.dart';

/// Design tokens of the staff app. Brand colours follow the venue's
/// [ColorPalette], the same one the kiosk uses (see [S.palette]).
abstract final class S {
  static ColorPalette palette = ColorPalette.fallback;

  static Color get primary => Color(palette.primary);
  static Color get primaryDark => Color(palette.primaryDark);
  static Color get accent => Color(palette.accent);
  static Color get background => Color(palette.background);
  static Color get line => Color(palette.line);

  /// Highlight of the selected item on the dark side bar: the primary
  /// colour, or the accent when the primary is too dark to stand out.
  static Color get navSelected =>
      primary.computeLuminance() < 0.04 ? accent : primary;
  static Color get onNavSelected =>
      primary.computeLuminance() < 0.04 ? ink : Colors.white;

  static const ink = Color(0xFF1B1B1F);
  static const inkSoft = Color(0xFF5E5E66);
  static const muted = Color(0xFF9A9AA3);
  static const success = Color(0xFF1FA463);
  static const warning = Color(0xFFF29A00);

  /// Errors, cancellations and late orders: red whatever the palette.
  static const danger = Color(0xFFD62300);
  static const info = Color(0xFF2F6FEB);
  static const nav = Color(0xFF16161A);

  static const radius = 20.0;
  static const fast = Duration(milliseconds: 180);
  static const medium = Duration(milliseconds: 320);

  static const shadow = [
    BoxShadow(color: Color(0x12000000), blurRadius: 24, offset: Offset(0, 8)),
  ];
}

/// Repaints the placeholder logo in the current palette.
class PaletteColorMapper extends ColorMapper {
  final ColorPalette palette;
  const PaletteColorMapper(this.palette);

  @override
  Color substitute(String? id, String element, String attribute, Color c) =>
      Color(palette.recolor(c.toARGB32()));

  @override
  bool operator ==(Object other) =>
      other is PaletteColorMapper && other.palette.id == palette.id;

  @override
  int get hashCode => palette.id.hashCode;
}

/// Rebuilds every widget below [context], const ones included, so they
/// read the new palette tokens while keeping their state (open section,
/// selected order...).
void rebuildAll(BuildContext context) {
  void visit(Element e) {
    e.markNeedsBuild();
    e.visitChildren(visit);
  }

  (context as Element).visitChildren(visit);
}

ThemeData staffTheme(ColorPalette palette) {
  S.palette = palette;
  final scheme = ColorScheme.fromSeed(
    seedColor: S.primary,
    primary: S.primary,
    secondary: S.accent,
    surface: Colors.white,
  );
  final base = ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    fontFamily: 'Poppins',
  );
  return base.copyWith(
    scaffoldBackgroundColor: S.background,
    textTheme: base.textTheme
        .merge(Typography.englishLike2021)
        .apply(bodyColor: S.ink, displayColor: S.ink, fontFamily: 'Poppins'),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: S.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: S.line),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 52),
        padding: const EdgeInsets.symmetric(horizontal: 22),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(
          fontFamily: 'Poppins',
          fontWeight: FontWeight.w700,
          fontSize: 16,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 52),
        padding: const EdgeInsets.symmetric(horizontal: 22),
        foregroundColor: S.ink,
        side: BorderSide(color: S.line, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(
          fontFamily: 'Poppins',
          fontWeight: FontWeight.w600,
          fontSize: 16,
        ),
      ),
    ),
    dialogTheme: const DialogThemeData(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(S.radius)),
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      side: BorderSide(color: S.line),
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
  );
}

abstract final class ST {
  static const h1 = TextStyle(
    fontSize: 30,
    fontWeight: FontWeight.w800,
    color: S.ink,
    height: 1.15,
  );
  static const h2 = TextStyle(
    fontSize: 21,
    fontWeight: FontWeight.w700,
    color: S.ink,
  );
  static const h3 = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: S.ink,
  );
  static const body = TextStyle(fontSize: 15, color: S.ink);
  static const small = TextStyle(fontSize: 13, color: S.inkSoft);
}
