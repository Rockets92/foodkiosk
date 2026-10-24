import 'palette.dart';

/// A seasonal look for the customer screens (Christmas, Halloween…): its
/// own colours plus themed animations and artwork, switched on by the
/// staff when needed or picked automatically from the calendar.
///
/// The decorations themselves live in the apps and are keyed by [id];
/// this model only knows the colours and when the holiday falls.
class HolidayTheme {
  final String id;
  final String name;
  final String description;

  /// When the automatic mode shows it, in words, for the staff.
  final String period;

  /// Replaces the venue palette while the theme is on.
  final ColorPalette palette;

  /// First and last day (inclusive) of the automatic window that starts
  /// in [year]; the last day may fall in the next year.
  final (DateTime, DateTime) Function(int year) _window;

  const HolidayTheme._({
    required this.id,
    required this.name,
    required this.description,
    required this.period,
    required this.palette,
    required (DateTime, DateTime) Function(int year) window,
  }) : _window = window;

  /// Whether [day] falls in the automatic window.
  bool covers(DateTime day) {
    final d = DateTime(day.year, day.month, day.day);
    for (final year in [day.year - 1, day.year]) {
      final (start, end) = _window(year);
      if (!d.isBefore(start) && !d.isAfter(end)) return true;
    }
    return false;
  }

  static final halloween = HolidayTheme._(
    id: 'halloween',
    name: 'Halloween',
    description: 'Zucche, pipistrelli e fantasmi su una notte viola',
    period: 'Dal 15 ottobre al 2 novembre',
    palette: const ColorPalette(
      id: 'holiday-halloween',
      name: 'Halloween',
      description: 'Viola notte e arancio zucca',
      primary: 0xFF6A2C9E,
      primaryDark: 0xFF261040,
      primaryLight: 0xFF8B48C6,
      accent: 0xFFFF8A1C,
      background: 0xFFF6F1F7,
      line: 0xFFE8DDEC,
    ),
    window: (y) => (DateTime(y, 10, 15), DateTime(y, 11, 2)),
  );

  static final christmas = HolidayTheme._(
    id: 'christmas',
    name: 'Natale',
    description: 'Neve, lucine, albero e regali',
    period: 'Dal 1 dicembre al 6 gennaio',
    palette: const ColorPalette(
      id: 'holiday-christmas',
      name: 'Natale',
      description: 'Rosso Natale e oro',
      primary: 0xFFC41E3A,
      primaryDark: 0xFF7E0E21,
      primaryLight: 0xFFE03550,
      accent: 0xFFF4C44E,
      background: 0xFFF7F3EE,
      line: 0xFFEBE3D9,
    ),
    window: (y) => (DateTime(y, 12, 1), DateTime(y + 1, 1, 6)),
  );

  static final newYear = HolidayTheme._(
    id: 'newYear',
    name: 'Capodanno',
    description: 'Fuochi d\'artificio, brindisi e coriandoli d\'oro',
    period: 'Dal 27 dicembre al 2 gennaio',
    palette: const ColorPalette(
      id: 'holiday-newYear',
      name: 'Capodanno',
      description: 'Blu mezzanotte e oro',
      primary: 0xFF1F2E5A,
      primaryDark: 0xFF0A1027,
      primaryLight: 0xFF364C86,
      accent: 0xFFF5C451,
      background: 0xFFF3F3F6,
      line: 0xFFE2E3EA,
    ),
    window: (y) => (DateTime(y, 12, 27), DateTime(y + 1, 1, 2)),
  );

  static final valentine = HolidayTheme._(
    id: 'valentine',
    name: 'San Valentino',
    description: 'Cuori che volano, rosa e rosso passione',
    period: 'Dal 7 al 15 febbraio',
    palette: const ColorPalette(
      id: 'holiday-valentine',
      name: 'San Valentino',
      description: 'Rosso passione e rosa',
      primary: 0xFFE0194A,
      primaryDark: 0xFF990F37,
      primaryLight: 0xFFF7476F,
      accent: 0xFFFFC6D5,
      background: 0xFFFDF4F6,
      line: 0xFFF3E1E6,
    ),
    window: (y) => (DateTime(y, 2, 7), DateTime(y, 2, 15)),
  );

  static final carnival = HolidayTheme._(
    id: 'carnival',
    name: 'Carnevale',
    description: 'Coriandoli, stelle filanti e maschere',
    period: 'Le due settimane fino a martedì grasso',
    palette: const ColorPalette(
      id: 'holiday-carnival',
      name: 'Carnevale',
      description: 'Fucsia, viola e giallo',
      primary: 0xFFD3176F,
      primaryDark: 0xFF6C1C9C,
      primaryLight: 0xFFF03F8C,
      accent: 0xFFFFD23F,
      background: 0xFFFBF4F8,
      line: 0xFFF0E2EB,
    ),
    window: (y) {
      final easter = easterSunday(y);
      return (_shift(easter, -60), _shift(easter, -47));
    },
  );

  static final easter = HolidayTheme._(
    id: 'easter',
    name: 'Pasqua',
    description: 'Uova colorate, coniglietti e fiori di primavera',
    period: 'Le due settimane prima di Pasqua e Pasquetta',
    palette: const ColorPalette(
      id: 'holiday-easter',
      name: 'Pasqua',
      description: 'Lilla, giallo pulcino e verde prato',
      primary: 0xFF7A57C2,
      primaryDark: 0xFF54379A,
      primaryLight: 0xFF9C7DDB,
      accent: 0xFFFFE07A,
      background: 0xFFF8F5FC,
      line: 0xFFEAE3F4,
    ),
    window: (y) {
      final easter = easterSunday(y);
      return (_shift(easter, -14), _shift(easter, 1));
    },
  );

  static final summer = HolidayTheme._(
    id: 'summer',
    name: 'Estate',
    description: 'Sole, onde, palme e gelati',
    period: 'Dal 21 giugno al 31 agosto',
    palette: const ColorPalette(
      id: 'holiday-summer',
      name: 'Estate',
      description: 'Azzurro mare e giallo sole',
      primary: 0xFF0A8DB8,
      primaryDark: 0xFF075E7E,
      primaryLight: 0xFF1FB4D8,
      accent: 0xFFFFD166,
      background: 0xFFF1F8F9,
      line: 0xFFDCECEF,
    ),
    window: (y) => (DateTime(y, 6, 21), DateTime(y, 8, 31)),
  );

  /// The themes in calendar order, for the staff settings.
  static final presets = [
    newYear,
    valentine,
    carnival,
    easter,
    summer,
    halloween,
    christmas,
  ];

  /// When windows overlap, the more specific holiday wins.
  static final _priority = [
    newYear,
    carnival,
    valentine,
    easter,
    halloween,
    christmas,
    summer,
  ];

  static HolidayTheme? byId(String? id) {
    for (final t in presets) {
      if (t.id == id) return t;
    }
    return null;
  }

  /// The holiday falling on [day], if any.
  static HolidayTheme? forDate(DateTime day) {
    for (final t in _priority) {
      if (t.covers(day)) return t;
    }
    return null;
  }

  /// Easter Sunday of [year] (Gregorian calendar).
  static DateTime easterSunday(int year) {
    final a = year % 19;
    final b = year ~/ 100;
    final c = year % 100;
    final d = b ~/ 4;
    final e = b % 4;
    final f = (b + 8) ~/ 25;
    final g = (b - f + 1) ~/ 3;
    final h = (19 * a + b - d - g + 15) % 30;
    final i = c ~/ 4;
    final k = c % 4;
    final l = (32 + 2 * e + 2 * i - h - k) % 7;
    final m = (a + 11 * h + 22 * l) ~/ 451;
    final n = h + l - 7 * m + 114;
    return DateTime(year, n ~/ 31, n % 31 + 1);
  }
}

/// [day] moved by whole calendar [days], unaffected by daylight saving.
DateTime _shift(DateTime day, int days) =>
    DateTime(day.year, day.month, day.day + days);

/// The staff choice: no holiday theme, follow the calendar, or a theme
/// kept on until switched off.
abstract final class HolidayMode {
  static const none = 'none';
  static const auto = 'auto';

  static bool isValid(String value) =>
      value == none || value == auto || HolidayTheme.byId(value) != null;

  /// The theme to show on [now] for the setting [value].
  static HolidayTheme? resolve(String value, DateTime now) => switch (value) {
    none => null,
    auto => HolidayTheme.forDate(now),
    _ => HolidayTheme.byId(value),
  };
}
