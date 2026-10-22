/// Vector food illustrations used as demo product images until the venue
/// uploads real photos. Transparent background with a soft shadow, so they
/// look like cut-out product shots on the kiosk's light cards.
library;

const _defs = '''
<defs>
  <linearGradient id="bunTop" x1="0" y1="0" x2="0" y2="1">
    <stop offset="0" stop-color="#F7B860"/><stop offset="0.6" stop-color="#E08A2E"/><stop offset="1" stop-color="#C96F1C"/>
  </linearGradient>
  <linearGradient id="bunBottom" x1="0" y1="0" x2="0" y2="1">
    <stop offset="0" stop-color="#F0A54B"/><stop offset="1" stop-color="#C4701F"/>
  </linearGradient>
  <linearGradient id="patty" x1="0" y1="0" x2="0" y2="1">
    <stop offset="0" stop-color="#7A4321"/><stop offset="1" stop-color="#4E2812"/>
  </linearGradient>
  <linearGradient id="crispy" x1="0" y1="0" x2="0" y2="1">
    <stop offset="0" stop-color="#F6B443"/><stop offset="1" stop-color="#C77418"/>
  </linearGradient>
  <linearGradient id="veg" x1="0" y1="0" x2="0" y2="1">
    <stop offset="0" stop-color="#8DBB4C"/><stop offset="1" stop-color="#5A8A2B"/>
  </linearGradient>
  <linearGradient id="red" x1="0" y1="0" x2="1" y2="0">
    <stop offset="0" stop-color="#C21807"/><stop offset="0.45" stop-color="#E8331C"/><stop offset="1" stop-color="#B01505"/>
  </linearGradient>
  <linearGradient id="fry" x1="0" y1="0" x2="0" y2="1">
    <stop offset="0" stop-color="#FFE07A"/><stop offset="1" stop-color="#F2B630"/>
  </linearGradient>
  <linearGradient id="choc" x1="0" y1="0" x2="0" y2="1">
    <stop offset="0" stop-color="#6B3A22"/><stop offset="1" stop-color="#3E1F10"/>
  </linearGradient>
  <linearGradient id="glass" x1="0" y1="0" x2="1" y2="0">
    <stop offset="0" stop-color="#ffffff" stop-opacity="0.55"/><stop offset="0.3" stop-color="#ffffff" stop-opacity="0.1"/><stop offset="1" stop-color="#ffffff" stop-opacity="0.35"/>
  </linearGradient>
  <radialGradient id="shine" cx="0.35" cy="0.3" r="0.6">
    <stop offset="0" stop-color="#fff" stop-opacity="0.55"/><stop offset="1" stop-color="#fff" stop-opacity="0"/>
  </radialGradient>
</defs>''';

String _svg(
  String body, {
  String shadow =
      '<ellipse cx="200" cy="356" rx="140" ry="16" fill="#000" opacity="0.13"/>',
}) =>
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 400 400" width="400" height="400">'
    '$_defs$shadow$body</svg>';

// ---------------------------------------------------------------------------
// Burger parts, drawn bottom-up between y=340 and y=90.

const _bottomBun =
    '<path d="M72 300 h256 q8 0 6 10 q-8 34 -46 34 h-176 q-38 0 -46 -34 q-2 -10 6 -10z" fill="url(#bunBottom)"/>'
    '<path d="M82 306 h236" stroke="#fff" stroke-opacity="0.25" stroke-width="5" stroke-linecap="round"/>';

String _patty(double y, {String fill = 'url(#patty)'}) =>
    '<rect x="60" y="$y" width="280" height="40" rx="20" fill="$fill"/>'
    '<path d="M84 ${y + 12} q10 -6 20 0 M130 ${y + 26} q10 -6 20 0 M190 ${y + 12} q10 -6 20 0 M250 ${y + 26} q10 -6 20 0 M290 ${y + 12} q10 -6 20 0" '
    'stroke="#2E160A" stroke-opacity="0.45" stroke-width="5" fill="none" stroke-linecap="round"/>';

String _cheese(double y) =>
    '<path d="M56 $y h288 l-6 10 l-30 0 l-14 26 l-16 -26 l-60 0 l-18 32 l-16 -32 l-68 0 l-12 20 l-12 -20 l-30 0z" fill="#FFC21A"/>'
    '<path d="M56 $y h288 l-6 10 h-276z" fill="#FFD95A"/>';

String _lettuce(double y) =>
    '<path d="M60 ${y + 8} q14 -16 28 0 t28 0 t28 0 t28 0 t28 0 t28 0 t28 0 t28 0 t28 0 t28 0 v14 h-280z" fill="#5DB33C"/>'
    '<path d="M60 ${y + 8} q14 -16 28 0 t28 0 t28 0 t28 0 t28 0 t28 0 t28 0 t28 0 t28 0 t28 0" stroke="#8ED45E" stroke-width="4" fill="none"/>';

String _tomato(double y) =>
    '<rect x="70" y="$y" width="120" height="16" rx="8" fill="#E8331C"/>'
    '<rect x="200" y="$y" width="128" height="16" rx="8" fill="#D42A15"/>'
    '<path d="M86 ${y + 5} h80 M218 ${y + 5} h90" stroke="#FF8A70" stroke-width="3" stroke-linecap="round"/>';

String _bacon(double y) =>
    '<path d="M64 ${y + 8} q30 -14 60 0 t60 0 t60 0 t60 0 t36 0 v12 q-18 10 -36 0 t-60 0 t-60 0 t-60 0 t-60 0z" fill="#B5432A"/>'
    '<path d="M70 ${y + 12} q28 -10 56 0 t56 0 t56 0 t56 0 t46 0" stroke="#F3B49A" stroke-width="3" fill="none"/>';

String _topBun(double bottom, {bool seeds = true}) {
  final b = bottom;
  final seed = seeds
      ? [
          for (final (x, y, r) in [
            (140, b - 96, -20),
            (190, b - 112, 10),
            (240, b - 98, 30),
            (110, b - 64, -35),
            (170, b - 78, 0),
            (220, b - 72, 15),
            (280, b - 66, 40),
            (205, b - 40, -10),
            (150, b - 42, 20),
            (255, b - 40, 5),
          ])
            '<ellipse cx="$x" cy="$y" rx="8" ry="4.5" fill="#FFF3D6" transform="rotate($r $x $y)"/>',
        ].join()
      : '';
  return '<path d="M58 ${b - 4} q0 -128 142 -128 q142 0 142 128 q0 12 -14 12 h-256 q-14 0 -14 -12z" fill="url(#bunTop)"/>'
      '<path d="M88 ${b - 52} q20 -58 92 -64" stroke="#fff" stroke-opacity="0.45" stroke-width="10" fill="none" stroke-linecap="round"/>'
      '$seed';
}

String _burger({required String filling, bool seeds = true}) =>
    _svg('$_bottomBun$filling${_topBun(226, seeds: seeds)}');

final _classicBurger = _burger(
  filling: '${_patty(260)}${_cheese(254)}${_tomato(240)}${_lettuce(226)}',
);

final _doubleBurger = _svg(
  '<g transform="translate(0 6)">$_bottomBun'
  '${_patty(266)}${_cheese(260)}${_patty(226)}${_cheese(220)}${_bacon(204)}'
  '${_lettuce(194)}${_topBun(200)}</g>',
);

final _chickenBurger = _burger(
  filling:
      '<path d="M60 254 q14 -9 28 0 t28 0 t28 0 t28 0 t28 0 t28 0 t28 0 t28 0 t28 0 t28 0 q14 4 14 20 q0 16 -14 20 q-14 9 -28 0 t-28 0 t-28 0 t-28 0 t-28 0 t-28 0 t-28 0 t-28 0 t-28 0 t-28 0 q-14 -4 -14 -20 q0 -16 14 -20z" fill="url(#crispy)"/>'
      '<circle cx="110" cy="276" r="3" fill="#A65A10"/><circle cx="170" cy="284" r="3" fill="#A65A10"/><circle cx="230" cy="274" r="3" fill="#A65A10"/><circle cx="290" cy="284" r="3" fill="#A65A10"/>'
      '<path d="M70 248 h260" stroke="#FFF7E0" stroke-width="10" stroke-linecap="round"/>'
      '${_lettuce(228)}',
);

final _veggieBurger = _burger(
  filling:
      '${_patty(260, fill: 'url(#veg)')}${_tomato(244)}${_lettuce(228)}'
      '<circle cx="120" cy="276" r="4" fill="#E8331C"/><circle cx="200" cy="284" r="4" fill="#FFC21A"/><circle cx="270" cy="274" r="4" fill="#E8331C"/>',
);

// ---------------------------------------------------------------------------
// Sides

String _carton(String color, String content) => _svg(
  '$content'
  '<path d="M110 196 h180 l-22 160 h-136z" fill="$color"/>'
  '<path d="M110 196 h180 l-4 30 q-86 28 -172 0z" fill="#000" opacity="0.12"/>'
  '<path d="M128 214 q72 22 144 0" stroke="#fff" stroke-opacity="0.35" stroke-width="6" fill="none"/>'
  '<path d="M168 268 l32 -26 l32 26 l-32 26z" fill="#FFC21A"/>',
);

final _fries = _carton(
  'url(#red)',
  [
    for (final (x, top, rot) in [
      (128, 112, -12),
      (148, 92, -6),
      (170, 80, -2),
      (192, 70, 2),
      (214, 78, 4),
      (236, 90, 8),
      (258, 106, 12),
      (160, 120, -4),
      (204, 110, 3),
      (246, 122, 6),
      (182, 100, -1),
      (226, 100, 5),
    ])
      '<rect x="$x" y="$top" width="18" height="${220 - top}" rx="5" fill="url(#fry)" stroke="#E0A020" stroke-width="2" transform="rotate($rot ${x + 9} 220)"/>',
  ].join(),
);

final _wedges = _carton(
  '#2F6B3A',
  [
    for (final (x, y, rot) in [
      (130, 150, -30),
      (170, 120, -10),
      (210, 118, 12),
      (250, 140, 30),
      (190, 160, 0),
      (150, 170, -15),
      (232, 168, 18),
    ])
      '<path d="M$x $y l26 -50 q14 8 12 30 l-14 40 q-20 0 -24 -20z" fill="#D9932E" stroke="#9B5A14" stroke-width="3" transform="rotate($rot $x $y)"/>',
  ].join(),
);

String _nugget(double x, double y, double r) =>
    '<g transform="rotate($r $x $y)"><path d="M${x - 34} ${y + 4} q-4 -26 22 -30 q14 -14 32 -2 q24 -2 22 22 q8 22 -14 30 q-18 12 -36 2 q-28 2 -26 -22z" fill="url(#crispy)" stroke="#B9690F" stroke-width="3"/>'
    '<circle cx="${x - 10}" cy="${y - 6}" r="3" fill="#A65A10"/><circle cx="${x + 8}" cy="${y + 6}" r="3" fill="#A65A10"/>'
    '<ellipse cx="${x - 6}" cy="${y - 14}" rx="12" ry="5" fill="url(#shine)"/></g>';

final _nuggets = _svg(
  '<path d="M70 220 h260 l-24 132 h-212z" fill="#FFC21A"/>'
  '<path d="M70 220 h260 l-6 30 h-248z" fill="#E8331C"/>'
  '${_nugget(130, 206, -10)}${_nugget(200, 190, 8)}${_nugget(270, 206, 18)}${_nugget(165, 230, 0)}${_nugget(240, 232, -12)}'
  '<path d="M70 250 h260 l-24 102 h-212z" fill="#FFC21A"/>'
  '<text x="200" y="320" text-anchor="middle" font-family="Arial, sans-serif" font-weight="900" font-size="44" fill="#E8331C">6</text>',
);

String _ring(double cx, double cy, double rx, double ry, double rot) =>
    '<g transform="rotate($rot $cx $cy)"><ellipse cx="$cx" cy="$cy" rx="$rx" ry="$ry" fill="none" stroke="url(#crispy)" stroke-width="26"/>'
    '<ellipse cx="$cx" cy="$cy" rx="$rx" ry="$ry" fill="none" stroke="#B9690F" stroke-width="2" stroke-dasharray="4 10"/></g>';

final _onionRings = _svg(
  '${_ring(150, 290, 70, 34, -6)}${_ring(250, 286, 70, 34, 8)}${_ring(200, 240, 72, 36, 2)}${_ring(160, 190, 66, 32, -12)}${_ring(240, 186, 64, 30, 14)}',
);

final _salad = _svg(
  '<path d="M70 230 q130 18 260 0 q-10 110 -130 116 q-120 -6 -130 -116z" fill="#FFFFFF" stroke="#E5E0D8" stroke-width="4"/>'
  '${[
    for (final (x, y, c) in [(110, 220, '#5DB33C'), (150, 200, '#7CC94A'), (195, 192, '#4E9F33'), (240, 200, '#7CC94A'), (285, 218, '#5DB33C'), (130, 228, '#8ED45E'), (260, 226, '#8ED45E')]) '<ellipse cx="$x" cy="$y" rx="38" ry="22" fill="$c" transform="rotate(${(x % 40) - 20} $x $y)"/>',
  ].join()}'
  '<circle cx="170" cy="210" r="16" fill="#E8331C"/><circle cx="235" cy="214" r="14" fill="#E8331C"/>'
  '<circle cx="205" cy="226" r="10" fill="#FFC21A"/>'
  '<path d="M70 230 q130 18 260 0 q-4 20 -10 34 q-120 16 -240 0 q-6 -14 -10 -34z" fill="#F6F2EC"/>',
);

// ---------------------------------------------------------------------------
// Drinks

String _cup(
  String color, {
  double scale = 1,
  String label = '',
  String accent = '#FFFFFF',
}) {
  final s = scale;
  return _svg(
    '<g transform="translate(${200 - 200 * s} ${356 - 356 * s}) scale($s)">'
    '<rect x="214" y="40" width="14" height="110" rx="6" fill="#FFFFFF" stroke="#DDD" stroke-width="2" transform="rotate(12 221 95)"/>'
    '<rect x="214" y="40" width="14" height="30" fill="$color" opacity="0.8" transform="rotate(12 221 95)"/>'
    '<path d="M112 120 h176 l-22 236 h-132z" fill="$color"/>'
    '<path d="M112 120 h176 l-4 40 h-168z" fill="#000" opacity="0.08"/>'
    '<path d="M128 140 l20 210" stroke="#fff" stroke-opacity="0.35" stroke-width="10" stroke-linecap="round"/>'
    '<rect x="100" y="104" width="200" height="26" rx="10" fill="#F4F4F4" stroke="#DADADA" stroke-width="2"/>'
    '<path d="M150 104 q50 -26 100 0" fill="#F4F4F4" stroke="#DADADA" stroke-width="2"/>'
    '<path d="M156 220 q44 -24 88 0 q-44 24 -88 0z" fill="$accent" opacity="0.9"/>'
    '${label.isEmpty ? '' : '<text x="200" y="290" text-anchor="middle" font-family="Arial, sans-serif" font-weight="900" font-size="34" fill="$accent">$label</text>'}'
    '</g>',
  );
}

final _water = _svg(
  '<path d="M176 60 h48 v30 q36 20 36 70 v176 q0 20 -20 20 h-80 q-20 0 -20 -20 v-176 q0 -50 36 -70z" fill="#BFE6FA" stroke="#7CC6EC" stroke-width="4"/>'
  '<rect x="172" y="44" width="56" height="26" rx="6" fill="#1E88E5"/>'
  '<rect x="142" y="190" width="116" height="80" rx="8" fill="#1E88E5"/>'
  '<path d="M186 230 q14 -30 28 0 a14 14 0 1 1 -28 0z" fill="#fff"/>'
  '<path d="M158 120 v200" stroke="#fff" stroke-opacity="0.6" stroke-width="8" stroke-linecap="round"/>',
);

final _beer = _svg(
  '<path d="M268 170 h26 q34 0 34 40 v40 q0 40 -34 40 h-26" fill="none" stroke="#E7F3F8" stroke-width="18"/>'
  '<path d="M268 170 h26 q34 0 34 40 v40 q0 40 -34 40 h-26" fill="none" stroke="#BFD9E3" stroke-width="4"/>'
  '<rect x="112" y="120" width="160" height="236" rx="16" fill="#F2A71B"/>'
  '<rect x="112" y="120" width="160" height="236" rx="16" fill="url(#glass)"/>'
  '<circle cx="150" cy="300" r="5" fill="#FFE29A"/><circle cx="190" cy="250" r="4" fill="#FFE29A"/><circle cx="230" cy="310" r="6" fill="#FFE29A"/><circle cx="210" cy="200" r="4" fill="#FFE29A"/>'
  '<path d="M104 136 q-8 -40 30 -44 q10 -30 50 -20 q26 -22 56 0 q40 -6 40 32 q20 10 6 32 h-178 q-12 0 -4 0z" fill="#FFFDF6" stroke="#EDE6D2" stroke-width="3"/>',
);

// ---------------------------------------------------------------------------
// Desserts

final _sundae = _svg(
  '<path d="M120 236 h160 l-30 110 h-100z" fill="#FFFFFF" stroke="#E2E2E2" stroke-width="4"/>'
  '<path d="M120 236 h160 l-6 22 h-148z" fill="#E8331C"/>'
  '<path d="M128 236 q-10 -40 30 -46 q-6 -40 42 -44 q-4 -46 40 -46 q-14 30 10 50 q34 6 24 40 q30 10 14 46z" fill="#FFF8EC" stroke="#EADFC8" stroke-width="3"/>'
  '<path d="M150 196 q30 22 52 -4 q16 26 44 2 q10 18 20 6 l2 26 q-20 18 -40 2 q-24 22 -52 0 q-20 16 -34 -4z" fill="url(#choc)"/>'
  '<circle cx="232" cy="120" r="14" fill="#C21807"/><path d="M232 106 q6 -20 20 -24" stroke="#4E7A2B" stroke-width="4" fill="none"/>',
);

final _brownie = _svg(
  '<path d="M90 230 l110 -50 l110 50 l-110 50z" fill="#5A2E19"/>'
  '<path d="M90 230 v60 l110 50 v-60z" fill="url(#choc)"/>'
  '<path d="M310 230 v60 l-110 50 v-60z" fill="#4A2412"/>'
  '<path d="M110 232 l90 -40 l90 40" stroke="#7B4A2C" stroke-width="5" fill="none" stroke-linecap="round"/>'
  '${[
    for (final (x, y) in [(150, 222), (200, 206), (245, 226), (190, 246), (230, 252), (165, 248)]) '<ellipse cx="$x" cy="$y" rx="10" ry="6" fill="#D9B48A"/>',
  ].join()}'
  '<path d="M150 180 q10 -30 40 -26 q30 -10 40 18" fill="#FFF8EC"/>',
);

// ---------------------------------------------------------------------------
// Extras and sauces

String _dip(String color) => _svg(
  '<ellipse cx="200" cy="230" rx="110" ry="34" fill="$color"/>'
  '<path d="M90 230 q0 110 110 110 q110 0 110 -110 q-110 50 -220 0z" fill="#FFFFFF" stroke="#E2E2E2" stroke-width="4"/>'
  '<ellipse cx="200" cy="230" rx="110" ry="34" fill="none" stroke="#E2E2E2" stroke-width="6"/>'
  '<ellipse cx="170" cy="222" rx="40" ry="10" fill="#fff" opacity="0.35"/>',
  shadow:
      '<ellipse cx="200" cy="344" rx="110" ry="14" fill="#000" opacity="0.13"/>',
);

final _cheeseSlice = _svg(
  '<path d="M70 170 l260 -20 l10 120 q-20 6 -26 30 q-30 -24 -50 4 l-194 16z" fill="#FFC21A"/>'
  '<path d="M70 170 l260 -20 l-4 22 l-252 20z" fill="#FFD95A"/>'
  '<circle cx="140" cy="240" r="16" fill="#E9A800"/><circle cx="230" cy="220" r="12" fill="#E9A800"/><circle cx="270" cy="270" r="10" fill="#E9A800"/>',
);

final _baconStrips = _svg('${_bacon(150)}${_bacon(210)}${_bacon(270)}');

final _egg = _svg(
  '<path d="M80 250 q-20 -80 60 -90 q40 -60 110 -20 q80 10 70 80 q20 70 -60 80 q-60 30 -120 0 q-70 0 -60 -50z" fill="#FFFFFF" stroke="#EEE" stroke-width="4"/>'
  '<circle cx="200" cy="230" r="54" fill="#FFB300"/><ellipse cx="184" cy="212" rx="18" ry="10" fill="#FFE29A"/>',
);

final _jalapeno = _svg(
  [
    for (final (x, y) in [
      (140, 200),
      (230, 180),
      (190, 260),
      (270, 260),
      (120, 280),
    ])
      '<circle cx="$x" cy="$y" r="40" fill="#4E9F33"/><circle cx="$x" cy="$y" r="26" fill="#9BD16B"/>'
          '<circle cx="${x - 8}" cy="${y - 4}" r="4" fill="#F6F2D0"/><circle cx="${x + 8}" cy="${y + 2}" r="4" fill="#F6F2D0"/><circle cx="$x" cy="${y + 10}" r="4" fill="#F6F2D0"/>',
  ].join(),
);

// ---------------------------------------------------------------------------
// Meal: burger, fries and drink together.

String _inner(String svg) {
  final start = svg.indexOf('</defs>') + 7;
  final shadowEnd = svg.indexOf('/>', start) + 2;
  return svg.substring(shadowEnd, svg.length - 6);
}

String _meal(String burger) => _svg(
  '<g transform="translate(150 40) scale(0.62)">${_inner(_cup('url(#red)'))}</g>'
  '<g transform="translate(-10 70) scale(0.62)">${_inner(_fries)}</g>'
  '<g transform="translate(70 120) scale(0.68)">${_inner(burger)}</g>',
  shadow:
      '<ellipse cx="200" cy="356" rx="170" ry="18" fill="#000" opacity="0.13"/>',
);

final illustrations = <String, String>{
  'burger': _classicBurger,
  'burger-double': _doubleBurger,
  'burger-chicken': _chickenBurger,
  'burger-veggie': _veggieBurger,
  'meal-classic': _meal(_classicBurger),
  'meal-chicken': _meal(_chickenBurger),
  'meal-veggie': _meal(_veggieBurger),
  'fries': _fries,
  'wedges': _wedges,
  'nuggets': _nuggets,
  'onion-rings': _onionRings,
  'salad': _salad,
  'cola': _cup('url(#red)'),
  'orange': _cup('#FF8F1F', accent: '#FFF4D6'),
  'cup-medium': _cup('url(#red)', scale: 0.8),
  'cup-large': _cup('url(#red)'),
  'water': _water,
  'beer': _beer,
  'sundae': _sundae,
  'brownie': _brownie,
  'cheese': _cheeseSlice,
  'bacon': _baconStrips,
  'egg': _egg,
  'jalapeno': _jalapeno,
  'ketchup': _dip('#D42A15'),
  'mayo': _dip('#FFF3C4'),
  'bbq': _dip('#6B2E14'),
};
