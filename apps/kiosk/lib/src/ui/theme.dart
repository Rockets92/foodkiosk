import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:kiosk_core/kiosk_core.dart';

/// Design tokens of the kiosk. Brand colours come from the [ColorPalette]
/// chosen in the staff settings (see [K.palette]); text, cards and status
/// colours are shared by every palette.
abstract final class K {
  static ColorPalette palette = ColorPalette.fallback;

  /// Holiday decorations showing on the customer screens, if any.
  static HolidayTheme? holiday;

  static Color get primary => Color(palette.primary);
  static Color get primaryDark => Color(palette.primaryDark);
  static Color get accent => Color(palette.accent);
  static Color get background => Color(palette.background);
  static Color get line => Color(palette.line);

  /// Light wash of [primary], behind selected options and soft badges.
  static Color get primarySoft =>
      Color.alphaBlend(primary.withValues(alpha: 0.11), Colors.white);

  /// Fainter wash of [primary], for large selected surfaces.
  static Color get primaryFaint =>
      Color.alphaBlend(primary.withValues(alpha: 0.05), Colors.white);

  /// Light wash of [accent].
  static Color get accentSoft =>
      Color.alphaBlend(accent.withValues(alpha: 0.28), Colors.white);

  static const ink = Color(0xFF1B1B1F);
  static const inkSoft = Color(0xFF5E5E66);
  static const muted = Color(0xFF9A9AA3);
  static const card = Colors.white;
  static const success = Color(0xFF1FA463);

  /// Errors keep the same red whatever the palette.
  static const danger = Color(0xFFD62300);
  static const dangerDark = Color(0xFFA81B00);
  static const dangerSoft = Color(0xFFFFE9E5);

  static const radius = 28.0;
  static const radiusSmall = 18.0;

  static const fast = Duration(milliseconds: 180);
  static const medium = Duration(milliseconds: 320);
  static const slow = Duration(milliseconds: 600);

  static const shadow = [
    BoxShadow(color: Color(0x14000000), blurRadius: 30, offset: Offset(0, 12)),
    BoxShadow(color: Color(0x0A000000), blurRadius: 6, offset: Offset(0, 2)),
  ];

  static const shadowStrong = [
    BoxShadow(color: Color(0x33000000), blurRadius: 40, offset: Offset(0, 18)),
  ];

  /// Soft backdrop colours behind product pictures, one per category.
  static const tints = [
    Color(0xFFFFE9D6),
    Color(0xFFFFF1C7),
    Color(0xFFFFE0DA),
    Color(0xFFE4F4E1),
    Color(0xFFE3EEFB),
    Color(0xFFF1E6FA),
  ];

  static Color tintFor(String id) =>
      tints[id.codeUnits.fold<int>(0, (a, b) => a + b) % tints.length];

  static LinearGradient get heroGradient => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(palette.primaryLight), primary, primaryDark],
  );
}

/// Repaints the bundled SVG artwork in the current palette.
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
/// read the new palette tokens while keeping their state.
void rebuildAll(BuildContext context) {
  void visit(Element e) {
    e.markNeedsBuild();
    e.visitChildren(visit);
  }

  (context as Element).visitChildren(visit);
}

ThemeData kioskTheme(ColorPalette palette) {
  K.palette = palette;
  final scheme = ColorScheme.fromSeed(
    seedColor: K.primary,
    primary: K.primary,
    secondary: K.accent,
    surface: K.background,
  );
  final base = ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    fontFamily: 'Poppins',
  );
  return base.copyWith(
    scaffoldBackgroundColor: K.background,
    splashFactory: InkSparkle.splashFactory,
    textTheme: base.textTheme
        .merge(Typography.englishLike2021.apply(fontSizeFactor: 1.2))
        .apply(bodyColor: K.ink, displayColor: K.ink, fontFamily: 'Poppins'),
    dialogTheme: const DialogThemeData(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(K.radius)),
      ),
    ),
  );
}

/// Shorthand text styles, sized for a 1080px wide portrait kiosk.
abstract final class KText {
  static const display = TextStyle(
    fontSize: 64,
    fontWeight: FontWeight.w900,
    height: 1.05,
    color: K.ink,
  );
  static const h1 = TextStyle(
    fontSize: 44,
    fontWeight: FontWeight.w800,
    height: 1.1,
    color: K.ink,
  );
  static const h2 = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w800,
    height: 1.15,
    color: K.ink,
  );
  static const h3 = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    height: 1.2,
    color: K.ink,
  );
  static const body = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w500,
    height: 1.35,
    color: K.inkSoft,
  );
  static const small = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    height: 1.3,
    color: K.muted,
  );
  static const price = TextStyle(
    fontSize: 26,
    fontWeight: FontWeight.w800,
    color: K.ink,
    height: 1,
  );
  static const button = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    height: 1,
  );
}
