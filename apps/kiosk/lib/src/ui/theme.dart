import 'package:flutter/material.dart';

/// Placeholder brand: change these two colours (and the logo served by
/// the server) to restyle the kiosk for a venue.
const brandPrimary = Color(0xFFD62300);
const brandAccent = Color(0xFFFFC72C);

ThemeData kioskTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: brandPrimary,
    primary: brandPrimary,
    secondary: brandAccent,
    surface: const Color(0xFFFFFBF5),
  );
  final base = ThemeData(colorScheme: scheme, useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: scheme.surface,
    textTheme: base.textTheme.merge(
      Typography.englishLike2021.apply(fontSizeFactor: 1.25),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(160, 72),
        textStyle: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(160, 72),
        textStyle: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        side: const BorderSide(color: brandPrimary, width: 2),
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
  );
}
