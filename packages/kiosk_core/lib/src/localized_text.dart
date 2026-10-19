/// A text available in several languages, keyed by ISO 639-1 code
/// (`it`, `en`, `de`, ...).
class LocalizedText {
  final Map<String, String> values;

  const LocalizedText(this.values);

  const LocalizedText.empty() : values = const {};

  factory LocalizedText.single(String lang, String text) =>
      LocalizedText({lang: text});

  /// Accepts either a map of translations or a plain string (stored as `it`).
  factory LocalizedText.fromJson(Object? json) {
    if (json == null) return const LocalizedText.empty();
    if (json is String) return LocalizedText({'it': json});
    return LocalizedText(
      (json as Map).map((k, v) => MapEntry(k as String, v as String)),
    );
  }

  Map<String, String> toJson() => Map.of(values);

  bool get isEmpty => values.values.every((v) => v.trim().isEmpty);

  /// Returns the text in [lang], falling back to [fallback], then to any
  /// available translation, so the kiosk never shows an empty label.
  String resolve(String lang, {String fallback = 'it'}) {
    final direct = values[lang];
    if (direct != null && direct.isNotEmpty) return direct;
    final fb = values[fallback];
    if (fb != null && fb.isNotEmpty) return fb;
    for (final v in values.values) {
      if (v.isNotEmpty) return v;
    }
    return '';
  }

  /// Languages for which a non-empty translation exists.
  Set<String> get languages =>
      values.entries.where((e) => e.value.isNotEmpty).map((e) => e.key).toSet();

  @override
  bool operator ==(Object other) =>
      other is LocalizedText &&
      other.values.length == values.length &&
      other.values.entries.every((e) => values[e.key] == e.value);

  @override
  int get hashCode => Object.hashAllUnordered(
    values.entries.map((e) => Object.hash(e.key, e.value)),
  );

  @override
  String toString() => 'LocalizedText($values)';
}
