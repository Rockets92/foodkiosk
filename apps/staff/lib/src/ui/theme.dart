import 'package:flutter/material.dart';

/// Design tokens of the staff app, sharing the kiosk's placeholder brand.
abstract final class S {
  static const red = Color(0xFFD62300);
  static const yellow = Color(0xFFFFC72C);
  static const ink = Color(0xFF1B1B1F);
  static const inkSoft = Color(0xFF5E5E66);
  static const muted = Color(0xFF9A9AA3);
  static const background = Color(0xFFF5F2EC);
  static const line = Color(0xFFE8E2D8);
  static const success = Color(0xFF1FA463);
  static const warning = Color(0xFFF29A00);
  static const info = Color(0xFF2F6FEB);
  static const nav = Color(0xFF16161A);

  static const radius = 20.0;
  static const fast = Duration(milliseconds: 180);
  static const medium = Duration(milliseconds: 320);

  static const shadow = [
    BoxShadow(color: Color(0x12000000), blurRadius: 24, offset: Offset(0, 8)),
  ];
}

ThemeData staffTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: S.red,
    primary: S.red,
    secondary: S.yellow,
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
        borderSide: const BorderSide(color: S.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: S.line),
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
        side: const BorderSide(color: S.line, width: 1.5),
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
      side: const BorderSide(color: S.line),
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
