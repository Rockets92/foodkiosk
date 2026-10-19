import 'package:flutter/material.dart';

/// Design tokens of the kiosk. The brand is a placeholder: change the
/// colours here (and the logo served by the server) to restyle a venue.
abstract final class K {
  static const red = Color(0xFFD62300);
  static const redDark = Color(0xFFA81B00);
  static const yellow = Color(0xFFFFC72C);
  static const ink = Color(0xFF1B1B1F);
  static const inkSoft = Color(0xFF5E5E66);
  static const muted = Color(0xFF9A9AA3);
  static const background = Color(0xFFF7F4EF);
  static const card = Colors.white;
  static const line = Color(0xFFECE7DF);
  static const success = Color(0xFF1FA463);

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

  static const heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFE8331C), red, Color(0xFFB81D00)],
  );
}

ThemeData kioskTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: K.red,
    primary: K.red,
    secondary: K.yellow,
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
