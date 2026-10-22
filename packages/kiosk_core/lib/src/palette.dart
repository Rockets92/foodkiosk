/// A colour scheme for the customer kiosk and the staff app, picked in the
/// staff settings and pushed by the server to every device.
///
/// Colours are 0xAARRGGBB integers so the model stays free of Flutter.
/// Every palette keeps light surfaces and dark text; what changes is the
/// brand: [primary] carries white text (buttons, hero backgrounds) and
/// [accent] carries dark text (prices, badges, the cart button).
class ColorPalette {
  final String id;
  final String name;
  final String description;

  final int primary;

  /// Pressed / deep shade of [primary], end of the hero gradient.
  final int primaryDark;

  /// Bright shade of [primary], start of the hero gradient.
  final int primaryLight;
  final int accent;

  /// Page background behind the white cards.
  final int background;

  /// Hairlines and dividers on [background].
  final int line;

  const ColorPalette({
    required this.id,
    required this.name,
    required this.description,
    required this.primary,
    required this.primaryDark,
    required this.primaryLight,
    required this.accent,
    required this.background,
    required this.line,
  });

  static const classic = ColorPalette(
    id: 'classic',
    name: 'Classico',
    description: 'Rosso e giallo, il fast food per eccellenza',
    primary: 0xFFD62300,
    primaryDark: 0xFFB81D00,
    primaryLight: 0xFFE8331C,
    accent: 0xFFFFC72C,
    background: 0xFFF7F4EF,
    line: 0xFFECE7DF,
  );

  static const flame = ColorPalette(
    id: 'flame',
    name: 'Fiamma',
    description: 'Arancio brace e giallo sole, caldo e grigliato',
    primary: 0xFFE2540A,
    primaryDark: 0xFFB83F00,
    primaryLight: 0xFFF57A1F,
    accent: 0xFFFFD23F,
    background: 0xFFFAF4EC,
    line: 0xFFEFE4D6,
  );

  static const steakhouse = ColorPalette(
    id: 'steakhouse',
    name: 'Steakhouse',
    description: 'Bordeaux e oro, per burger gourmet',
    primary: 0xFF8E1B2B,
    primaryDark: 0xFF64101C,
    primaryLight: 0xFFAE2A3B,
    accent: 0xFFF0B53F,
    background: 0xFFF6F1EB,
    line: 0xFFE9E0D5,
  );

  static const midnight = ColorPalette(
    id: 'midnight',
    name: 'Notte',
    description: 'Nero grafite e giallo, deciso e moderno',
    primary: 0xFF26262C,
    primaryDark: 0xFF111114,
    primaryLight: 0xFF3A3A42,
    accent: 0xFFFFC72C,
    background: 0xFFF3F2EF,
    line: 0xFFE4E2DD,
  );

  static const fresh = ColorPalette(
    id: 'fresh',
    name: 'Fresco',
    description: 'Verde e lime, per insalate, bowl e veggie',
    primary: 0xFF1E8A48,
    primaryDark: 0xFF136536,
    primaryLight: 0xFF2FA65B,
    accent: 0xFFD4E94B,
    background: 0xFFF3F6EF,
    line: 0xFFE1E8D9,
  );

  static const ocean = ColorPalette(
    id: 'ocean',
    name: 'Oceano',
    description: 'Blu intenso e giallo, pulito e luminoso',
    primary: 0xFF1F5FD1,
    primaryDark: 0xFF14449E,
    primaryLight: 0xFF3B7BEA,
    accent: 0xFFFFC233,
    background: 0xFFF2F5FA,
    line: 0xFFDFE5EF,
  );

  static const berry = ColorPalette(
    id: 'berry',
    name: 'Frutti di bosco',
    description: 'Fucsia e rosa, per gelaterie, dessert e bubble tea',
    primary: 0xFFC2185B,
    primaryDark: 0xFF8E1146,
    primaryLight: 0xFFDB3576,
    accent: 0xFFFFC1D8,
    background: 0xFFFAF3F6,
    line: 0xFFF0E1E8,
  );

  static const italia = ColorPalette(
    id: 'italia',
    name: 'Trattoria',
    description: 'Verde basilico e crema, per pizza e pasta',
    primary: 0xFF0B7A4B,
    primaryDark: 0xFF075A37,
    primaryLight: 0xFF169163,
    accent: 0xFFF7C948,
    background: 0xFFF8F4EA,
    line: 0xFFEBE4D3,
  );

  static const fallback = classic;

  /// The selectable palettes, in display order.
  static const presets = [
    classic,
    flame,
    steakhouse,
    midnight,
    fresh,
    ocean,
    berry,
    italia,
  ];

  /// Maps a colour of the bundled artwork (placeholder logo, "eat in" and
  /// "take away" illustrations), drawn in the [classic] red and yellow, to
  /// this palette, so the artwork follows the brand. Other colours (food,
  /// paper, shadows) are kept. Alpha is preserved.
  int recolor(int argb) {
    final rgb = argb & 0xFFFFFF;
    final mapped = switch (rgb) {
      0xD62300 => primary,
      0xE8331C || 0xFF5A3C => primaryLight,
      0xC21807 || 0xB01505 => primaryDark,
      0xFFC72C => accent,
      _ => null,
    };
    if (mapped == null) return argb;
    return (argb & 0xFF000000) | (mapped & 0xFFFFFF);
  }

  /// The preset with [id], or the default one when unknown.
  static ColorPalette byId(String? id) =>
      presets.firstWhere((p) => p.id == id, orElse: () => fallback);
}
