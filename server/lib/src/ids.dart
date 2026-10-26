import 'dart:math';

final _random = Random.secure();

/// Random 128-bit identifier as 32 hex chars. Order ids double as the
/// kiosk's capability to pay or cancel its own order, so they must not be
/// guessable.
String newId() => List.generate(
  16,
  (_) => _random.nextInt(256).toRadixString(16).padLeft(2, '0'),
).join();

/// Readable id from a name, for menu entities created in the admin panel.
String slugId(String name) {
  final base = name
      .toLowerCase()
      .replaceAll(RegExp(r'[àáâä]'), 'a')
      .replaceAll(RegExp(r'[èéêë]'), 'e')
      .replaceAll(RegExp(r'[ìíîï]'), 'i')
      .replaceAll(RegExp(r'[òóôö]'), 'o')
      .replaceAll(RegExp(r'[ùúûü]'), 'u')
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  final suffix = _random.nextInt(0xffff).toRadixString(16).padLeft(4, '0');
  return '${base.isEmpty ? 'item' : base}-$suffix';
}
