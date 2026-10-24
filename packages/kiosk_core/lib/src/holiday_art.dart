/// Artwork of the [HolidayTheme]s as SVG sources, shared by the kiosk
/// (decorations) and the staff app (theme previews).
///
/// Flat style with soft gradients, like the bundled illustrations.
abstract final class HolidayArt {
  // ---- Halloween ----------------------------------------------------------

  static const pumpkin = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 200 200">
  <defs>
    <radialGradient id="pk" cx="0.4" cy="0.35" r="0.8"><stop offset="0" stop-color="#FFB04A"/><stop offset="0.55" stop-color="#F27A12"/><stop offset="1" stop-color="#B9480A"/></radialGradient>
    <radialGradient id="gl" cx="0.5" cy="0.4" r="0.7"><stop offset="0" stop-color="#FFF7B8"/><stop offset="1" stop-color="#FFB81C"/></radialGradient>
  </defs>
  <ellipse cx="100" cy="188" rx="80" ry="9" fill="#000" opacity="0.2"/>
  <path d="M112 44 C122 30 140 24 156 30 C146 32 132 36 122 46" fill="none" stroke="#5DA03A" stroke-width="5" stroke-linecap="round"/>
  <path d="M92 46 C88 30 92 16 104 10 C110 8 114 12 112 16 C104 22 102 34 106 46Z" fill="#4E7A2B"/>
  <ellipse cx="60" cy="118" rx="50" ry="64" fill="url(#pk)"/>
  <ellipse cx="140" cy="118" rx="50" ry="64" fill="url(#pk)"/>
  <ellipse cx="100" cy="116" rx="48" ry="70" fill="url(#pk)"/>
  <path d="M80 54 C62 96 62 146 80 182 M120 54 C138 96 138 146 120 182" fill="none" stroke="#C4560C" stroke-width="3" opacity="0.55"/>
  <ellipse cx="62" cy="84" rx="9" ry="20" fill="#fff" opacity="0.28" transform="rotate(22 62 84)"/>
  <path d="M54 104 L78 76 L92 108Z" fill="url(#gl)"/>
  <path d="M146 104 L122 76 L108 108Z" fill="url(#gl)"/>
  <path d="M100 112 L90 128 H110Z" fill="url(#gl)"/>
  <path d="M46 136 Q100 160 154 136 Q146 182 100 184 Q54 182 46 136Z" fill="url(#gl)"/>
  <path d="M74 144 h14 v14 h-14z M112 146 h14 v14 h-14z M92 168 h16 v18 h-16z" fill="#E86E10"/>
</svg>''';

  static const ghost = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 200 220">
  <defs>
    <linearGradient id="g" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#FFFFFF"/><stop offset="1" stop-color="#DCD5EC"/></linearGradient>
  </defs>
  <path d="M44 124 C26 128 16 140 14 156 C26 152 38 148 48 146Z" fill="#E9E4F4"/>
  <path d="M156 124 C174 128 184 140 186 156 C174 152 162 148 152 146Z" fill="#E9E4F4"/>
  <path d="M40 110 C40 56 66 26 100 26 C134 26 160 56 160 110 V194 Q150 210 140 194 Q130 178 120 194 Q110 210 100 194 Q90 178 80 194 Q70 210 60 194 Q50 178 40 194Z" fill="url(#g)"/>
  <ellipse cx="78" cy="100" rx="10" ry="14" fill="#2B1B3A"/>
  <ellipse cx="122" cy="100" rx="10" ry="14" fill="#2B1B3A"/>
  <circle cx="81" cy="95" r="3.5" fill="#fff"/><circle cx="125" cy="95" r="3.5" fill="#fff"/>
  <ellipse cx="100" cy="134" rx="11" ry="14" fill="#2B1B3A"/>
  <ellipse cx="64" cy="122" rx="10" ry="6" fill="#FF9EC0" opacity="0.6"/>
  <ellipse cx="136" cy="122" rx="10" ry="6" fill="#FF9EC0" opacity="0.6"/>
</svg>''';

  static const witchHat = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 200 200">
  <defs>
    <linearGradient id="h" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#5A3488"/><stop offset="1" stop-color="#2A1544"/></linearGradient>
  </defs>
  <ellipse cx="100" cy="160" rx="92" ry="22" fill="#24123A"/>
  <path d="M50 158 C58 112 78 74 100 52 C116 36 128 24 146 14 C132 32 126 52 128 82 C130 112 138 136 150 158Z" fill="url(#h)"/>
  <path d="M52 140 Q100 154 148 140 L152 160 Q100 174 48 160Z" fill="#FF8A1C"/>
  <rect x="88" y="141" width="24" height="22" rx="4" fill="none" stroke="#FFD34D" stroke-width="5"/>
  <path d="M146 14 l6 -4 l-2 8z" fill="#5A3488"/>
</svg>''';

  // ---- Christmas ----------------------------------------------------------

  static const tree = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 200 240">
  <defs>
    <linearGradient id="t" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#44B565"/><stop offset="1" stop-color="#1C6637"/></linearGradient>
  </defs>
  <ellipse cx="100" cy="230" rx="72" ry="8" fill="#000" opacity="0.15"/>
  <rect x="88" y="196" width="24" height="32" rx="4" fill="#8B5A2B"/>
  <path d="M100 104 L14 204 Q57 216 100 208 Q143 216 186 204Z" fill="url(#t)"/>
  <path d="M100 66 L28 154 Q64 166 100 158 Q136 166 172 154Z" fill="url(#t)"/>
  <path d="M100 28 L42 104 Q71 114 100 108 Q129 114 158 104Z" fill="url(#t)"/>
  <path d="M56 98 Q100 118 146 92" fill="none" stroke="#F4C44E" stroke-width="4" stroke-linecap="round"/>
  <path d="M44 146 Q104 172 162 138" fill="none" stroke="#F4C44E" stroke-width="4" stroke-linecap="round"/>
  <path d="M30 196 Q100 222 172 186" fill="none" stroke="#F4C44E" stroke-width="4" stroke-linecap="round"/>
  <circle cx="82" cy="86" r="7" fill="#E0344F"/><circle cx="124" cy="96" r="7" fill="#3B82F6"/>
  <circle cx="64" cy="136" r="8" fill="#F4C44E"/><circle cx="108" cy="150" r="8" fill="#E0344F"/><circle cx="146" cy="134" r="8" fill="#FFFFFF"/>
  <circle cx="48" cy="186" r="9" fill="#3B82F6"/><circle cx="90" cy="198" r="9" fill="#F4C44E"/><circle cx="136" cy="192" r="9" fill="#E0344F"/><circle cx="168" cy="184" r="8" fill="#FFFFFF"/>
  <circle cx="80" cy="84" r="2.4" fill="#fff" opacity="0.8"/><circle cx="106" cy="148" r="2.6" fill="#fff" opacity="0.8"/><circle cx="134" cy="190" r="2.8" fill="#fff" opacity="0.8"/>
  <path d="M100.0 2.0 L105.0 15.1 L119.0 15.8 L108.1 24.6 L111.8 38.2 L100.0 30.5 L88.2 38.2 L91.9 24.6 L81.0 15.8 L95.0 15.1Z" fill="#FFD34D" stroke="#F0A81A" stroke-width="2" stroke-linejoin="round"/>
</svg>''';

  static const gifts = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 220 200">
  <ellipse cx="110" cy="190" rx="102" ry="8" fill="#000" opacity="0.15"/>
  <rect x="20" y="92" width="110" height="94" rx="8" fill="#D62839"/>
  <rect x="20" y="92" width="110" height="94" rx="8" fill="#000" opacity="0.08"/>
  <rect x="12" y="74" width="126" height="28" rx="7" fill="#EA4258"/>
  <rect x="66" y="74" width="18" height="112" fill="#F4C44E"/>
  <path d="M75 74 C52 44 30 50 34 64 C38 76 60 76 75 74Z" fill="#F4C44E"/>
  <path d="M75 74 C98 44 120 50 116 64 C112 76 90 76 75 74Z" fill="#F4C44E"/>
  <path d="M75 74 C60 62 46 62 44 66" fill="none" stroke="#D99A1E" stroke-width="3"/>
  <circle cx="75" cy="73" r="8" fill="#E0A82E"/>
  <rect x="126" y="124" width="80" height="62" rx="7" fill="#1F8A4C"/>
  <rect x="120" y="112" width="92" height="20" rx="5" fill="#2BA35F"/>
  <circle cx="142" cy="150" r="4" fill="#fff" opacity="0.5"/><circle cx="192" cy="170" r="4" fill="#fff" opacity="0.5"/><circle cx="188" cy="144" r="3" fill="#fff" opacity="0.5"/><circle cx="146" cy="174" r="3" fill="#fff" opacity="0.5"/>
  <rect x="159" y="112" width="14" height="74" fill="#FFFFFF"/>
  <path d="M166 112 C150 90 134 96 138 106 C142 114 156 114 166 112Z" fill="#FFFFFF"/>
  <path d="M166 112 C182 90 198 96 194 106 C190 114 176 114 166 112Z" fill="#FFFFFF"/>
  <circle cx="166" cy="111" r="6" fill="#E8E8E8"/>
</svg>''';

  static const santaHat = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 200 200">
  <defs>
    <linearGradient id="r" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#F0384F"/><stop offset="1" stop-color="#A3122A"/></linearGradient>
  </defs>
  <path d="M34 150 C42 96 78 48 130 42 C160 40 178 62 184 104 L168 108 C162 86 152 78 142 82 C150 104 158 128 166 150Z" fill="url(#r)"/>
  <rect x="22" y="138" width="156" height="36" rx="18" fill="#FFFFFF"/>
  <rect x="22" y="158" width="156" height="16" rx="8" fill="#E6E6EE"/>
  <circle cx="176" cy="110" r="18" fill="#FFFFFF"/>
  <circle cx="181" cy="116" r="10" fill="#E6E6EE"/>
</svg>''';

  static const snowman = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 180 230">
  <ellipse cx="90" cy="222" rx="70" ry="8" fill="#000" opacity="0.12"/>
  <circle cx="90" cy="168" r="56" fill="#FFFFFF"/><circle cx="90" cy="168" r="56" fill="#C9D9F0" opacity="0.35"/>
  <circle cx="90" cy="88" r="40" fill="#FFFFFF"/>
  <path d="M52 112 Q90 128 128 112 L132 126 Q90 142 48 126Z" fill="#E0344F"/>
  <path d="M112 122 l10 40 l14 -4 l-8 -38z" fill="#C41E3A"/>
  <rect x="58" y="38" width="64" height="12" rx="4" fill="#26262C"/>
  <rect x="68" y="4" width="44" height="40" rx="5" fill="#26262C"/>
  <rect x="68" y="30" width="44" height="8" fill="#E0344F"/>
  <circle cx="76" cy="80" r="5" fill="#26262C"/><circle cx="104" cy="80" r="5" fill="#26262C"/>
  <path d="M90 90 L124 98 L90 100Z" fill="#FF8A1C"/>
  <circle cx="90" cy="156" r="5" fill="#26262C"/><circle cx="90" cy="178" r="5" fill="#26262C"/><circle cx="90" cy="200" r="5" fill="#26262C"/>
  <path d="M38 150 L6 122 M20 136 L8 140 M146 150 L176 120 M160 134 L172 138" stroke="#8B5A2B" stroke-width="5" stroke-linecap="round"/>
</svg>''';

  // ---- Easter -------------------------------------------------------------

  /// A painted egg; colours as `#RRGGBB`.
  static String egg(String base, String band, String dots) =>
      '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 160 200">
  <defs>
    <clipPath id="c"><path d="M80 8 C128 8 150 96 150 130 C150 172 118 194 80 194 C42 194 10 172 10 130 C10 96 32 8 80 8Z"/></clipPath>
    <radialGradient id="s" cx="0.35" cy="0.3" r="0.85"><stop offset="0" stop-color="#FFFFFF" stop-opacity="0.5"/><stop offset="0.45" stop-color="#FFFFFF" stop-opacity="0"/><stop offset="1" stop-color="#000000" stop-opacity="0.18"/></radialGradient>
  </defs>
  <g clip-path="url(#c)">
    <rect width="160" height="200" fill="$base"/>
    <path d="M0 96 L20 80 L40 96 L60 80 L80 96 L100 80 L120 96 L140 80 L160 96 V112 L140 96 L120 112 L100 96 L80 112 L60 96 L40 112 L20 96 L0 112Z" fill="$band"/>
    <rect y="138" width="160" height="10" fill="$band"/>
    <circle cx="44" cy="52" r="7" fill="$dots"/><circle cx="80" cy="40" r="7" fill="$dots"/><circle cx="116" cy="52" r="7" fill="$dots"/>
    <circle cx="36" cy="168" r="6" fill="$dots"/><circle cx="64" cy="172" r="6" fill="$dots"/><circle cx="96" cy="172" r="6" fill="$dots"/><circle cx="124" cy="168" r="6" fill="$dots"/>
    <rect width="160" height="200" fill="url(#s)"/>
  </g>
</svg>''';

  static final eggs = [
    egg('#B9A2F0', '#FFE07A', '#FFFFFF'),
    egg('#8FD9B6', '#FF9EC0', '#FFFFFF'),
    egg('#FFC1D8', '#7FC8F8', '#FFE07A'),
    egg('#FFE07A', '#9C7DDB', '#FF9EC0'),
  ];

  static const bunny = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 200 220">
  <defs>
    <radialGradient id="f" cx="0.45" cy="0.35" r="0.8"><stop offset="0" stop-color="#FFFFFF"/><stop offset="1" stop-color="#E7E1EE"/></radialGradient>
  </defs>
  <path d="M64 112 C44 62 46 10 70 8 C94 6 94 60 88 108Z" fill="url(#f)"/>
  <path d="M69 100 C57 64 59 24 71 22 C83 22 82 64 81 100Z" fill="#F8B8CF"/>
  <path d="M136 112 C156 62 154 10 130 8 C106 6 106 60 112 108Z" fill="url(#f)"/>
  <path d="M131 100 C143 64 141 24 129 22 C117 22 118 64 119 100Z" fill="#F8B8CF"/>
  <ellipse cx="100" cy="156" rx="68" ry="58" fill="url(#f)"/>
  <ellipse cx="76" cy="146" rx="8" ry="10" fill="#2B2235"/><ellipse cx="124" cy="146" rx="8" ry="10" fill="#2B2235"/>
  <circle cx="79" cy="142" r="3" fill="#fff"/><circle cx="127" cy="142" r="3" fill="#fff"/>
  <ellipse cx="58" cy="168" rx="11" ry="7" fill="#FF9EC0" opacity="0.6"/><ellipse cx="142" cy="168" rx="11" ry="7" fill="#FF9EC0" opacity="0.6"/>
  <path d="M91 164 H109 Q100 176 91 164Z" fill="#F27BA3"/>
  <path d="M100 172 Q96 182 86 178 M100 172 Q104 182 114 178" fill="none" stroke="#2B2235" stroke-width="3" stroke-linecap="round"/>
  <path d="M40 160 L70 166 M40 176 L70 172 M160 160 L130 166 M160 176 L130 172" stroke="#B9AFC6" stroke-width="2" stroke-linecap="round"/>
  <ellipse cx="66" cy="210" rx="20" ry="12" fill="#FFFFFF"/><ellipse cx="134" cy="210" rx="20" ry="12" fill="#FFFFFF"/>
</svg>''';

  static const chick = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 200 200">
  <defs>
    <radialGradient id="y" cx="0.4" cy="0.35" r="0.75"><stop offset="0" stop-color="#FFF08A"/><stop offset="1" stop-color="#FFC21A"/></radialGradient>
  </defs>
  <ellipse cx="100" cy="192" rx="70" ry="7" fill="#000" opacity="0.14"/>
  <path d="M94 44 C88 28 96 18 104 18 C100 26 104 34 108 40 C112 30 120 28 126 32 C116 34 112 40 110 46Z" fill="#FFC21A"/>
  <circle cx="100" cy="102" r="60" fill="url(#y)"/>
  <path d="M44 112 C30 120 32 138 40 144 C48 134 54 126 56 116Z" fill="#FFC21A"/>
  <path d="M156 112 C170 120 168 138 160 144 C152 134 146 126 144 116Z" fill="#FFC21A"/>
  <circle cx="80" cy="94" r="7" fill="#2B2235"/><circle cx="120" cy="94" r="7" fill="#2B2235"/>
  <circle cx="82" cy="91" r="2.5" fill="#fff"/><circle cx="122" cy="91" r="2.5" fill="#fff"/>
  <path d="M90 106 L100 120 L110 106Z" fill="#FF8A1C"/>
  <ellipse cx="66" cy="112" rx="9" ry="6" fill="#FF9E7A" opacity="0.5"/><ellipse cx="134" cy="112" rx="9" ry="6" fill="#FF9E7A" opacity="0.5"/>
  <path d="M34 122 L50 136 L66 120 L82 136 L100 120 L118 136 L134 120 L150 136 L166 122 C170 168 142 192 100 192 C58 192 30 168 34 122Z" fill="#FFFFFF"/>
  <path d="M34 122 L50 136 L66 120 L82 136 L100 120 L118 136 L134 120 L150 136 L166 122 C170 168 142 192 100 192 C58 192 30 168 34 122Z" fill="#B9A2F0" opacity="0.12"/>
  <circle cx="70" cy="164" r="6" fill="#B9A2F0" opacity="0.6"/><circle cx="118" cy="172" r="5" fill="#8FD9B6" opacity="0.8"/><circle cx="140" cy="152" r="4" fill="#FF9EC0" opacity="0.8"/>
</svg>''';

  static const bunnyEars = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 200 200">
  <path d="M60 150 C30 90 34 16 66 12 C98 8 96 90 86 150Z" fill="#FFFFFF"/>
  <path d="M66 136 C48 90 50 30 67 28 C84 28 82 90 78 136Z" fill="#F8B8CF"/>
  <path d="M140 150 C170 90 166 16 134 12 C102 8 104 90 114 150Z" fill="#FFFFFF"/>
  <path d="M134 136 C152 90 150 30 133 28 C116 28 118 90 122 136Z" fill="#F8B8CF"/>
  <path d="M24 176 Q100 120 176 176" fill="none" stroke="#B9A2F0" stroke-width="14" stroke-linecap="round"/>
</svg>''';

  static const daisy = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 200 200">
  <g fill="#FFFFFF">
    <ellipse cx="100" cy="52" rx="22" ry="40"/>
    <ellipse cx="100" cy="52" rx="22" ry="40" transform="rotate(60 100 100)"/>
    <ellipse cx="100" cy="52" rx="22" ry="40" transform="rotate(120 100 100)"/>
    <ellipse cx="100" cy="52" rx="22" ry="40" transform="rotate(180 100 100)"/>
    <ellipse cx="100" cy="52" rx="22" ry="40" transform="rotate(240 100 100)"/>
    <ellipse cx="100" cy="52" rx="22" ry="40" transform="rotate(300 100 100)"/>
  </g>
  <circle cx="100" cy="100" r="28" fill="#FFC21A"/>
  <circle cx="92" cy="92" r="9" fill="#FFE07A"/>
</svg>''';

  // ---- Carnival -----------------------------------------------------------

  static const mask = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 240 200">
  <defs>
    <linearGradient id="m" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#F03F8C"/><stop offset="1" stop-color="#6C1C9C"/></linearGradient>
  </defs>
  <path d="M46 92 C24 52 36 10 64 8 C66 34 70 60 72 84Z" fill="#2EC4B6"/>
  <path d="M60 86 C50 40 72 2 100 6 C92 30 86 58 84 84Z" fill="#FFD23F"/>
  <path d="M40 98 C10 70 8 30 30 18 C40 44 50 68 62 88Z" fill="#F03F8C"/>
  <path d="M20 90 C40 70 90 76 120 94 C150 76 200 70 220 90 C230 130 210 170 170 168 C150 166 136 148 120 148 C104 148 90 166 70 168 C30 170 10 130 20 90Z" fill="url(#m)"/>
  <path d="M20 90 C40 70 90 76 120 94 C150 76 200 70 220 90 C230 130 210 170 170 168 C150 166 136 148 120 148 C104 148 90 166 70 168 C30 170 10 130 20 90Z" fill="none" stroke="#FFD23F" stroke-width="5"/>
  <path d="M46 114 C58 98 92 100 100 120 C88 132 58 132 46 114Z" fill="#2A0F3A"/>
  <path d="M194 114 C182 98 148 100 140 120 C152 132 182 132 194 114Z" fill="#2A0F3A"/>
  <path d="M46 114 C58 98 92 100 100 120 M194 114 C182 98 148 100 140 120" fill="none" stroke="#FFD23F" stroke-width="3"/>
  <path d="M120 104 l8 12 l-8 12 l-8 -12z" fill="#FFD23F"/>
  <circle cx="44" cy="146" r="4" fill="#FFD23F"/><circle cx="196" cy="146" r="4" fill="#FFD23F"/><circle cx="72" cy="152" r="3" fill="#2EC4B6"/><circle cx="168" cy="152" r="3" fill="#2EC4B6"/>
  <path d="M60 90 Q70 84 80 90 M160 90 Q170 84 180 90" fill="none" stroke="#FFFFFF" stroke-width="3" stroke-linecap="round" opacity="0.6"/>
</svg>''';

  static const jesterHat = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 220 200">
  <path d="M36 168 C30 130 22 100 16 72 C50 90 80 120 98 160Z" fill="#F03F8C"/>
  <path d="M78 160 C86 110 100 60 110 26 C120 60 134 110 142 160Z" fill="#6C1C9C"/>
  <path d="M122 160 C140 120 170 90 204 72 C198 100 190 130 184 168Z" fill="#2EC4B6"/>
  <path d="M30 168 Q110 140 190 168 L192 190 Q110 162 28 190Z" fill="#FFD23F"/>
  <circle cx="60" cy="172" r="5" fill="#F03F8C"/><circle cx="110" cy="164" r="5" fill="#6C1C9C"/><circle cx="160" cy="172" r="5" fill="#2EC4B6"/>
  <circle cx="16" cy="72" r="11" fill="#FFD23F"/><circle cx="110" cy="24" r="11" fill="#FFD23F"/><circle cx="204" cy="72" r="11" fill="#FFD23F"/>
  <circle cx="13" cy="69" r="3.5" fill="#fff" opacity="0.7"/><circle cx="107" cy="21" r="3.5" fill="#fff" opacity="0.7"/><circle cx="201" cy="69" r="3.5" fill="#fff" opacity="0.7"/>
</svg>''';

  // ---- Valentine's day ----------------------------------------------------

  static const heart = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 200 180">
  <defs>
    <linearGradient id="h" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#FF6F93"/><stop offset="0.55" stop-color="#E0194A"/><stop offset="1" stop-color="#A30F3A"/></linearGradient>
  </defs>
  <path d="M100 170 C40 124 8 92 8 56 C8 28 30 8 56 8 C76 8 92 20 100 36 C108 20 124 8 144 8 C170 8 192 28 192 56 C192 92 160 124 100 170Z" fill="url(#h)"/>
  <path d="M34 46 C40 30 60 24 72 32 C58 34 46 44 40 60Z" fill="#FFFFFF" opacity="0.55"/>
</svg>''';

  static const heartBalloon = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 120 230">
  <defs>
    <linearGradient id="h" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#FF7A9C"/><stop offset="0.55" stop-color="#F0315C"/><stop offset="1" stop-color="#B0123F"/></linearGradient>
  </defs>
  <path d="M60 130 Q52 160 64 180 Q76 200 58 228" fill="none" stroke="#9C8FA0" stroke-width="2"/>
  <path d="M60 116 C24 90 4 70 4 46 C4 26 18 10 38 10 C50 10 56 18 60 28 C64 18 70 10 82 10 C102 10 116 26 116 46 C116 70 96 90 60 116Z" fill="url(#h)"/>
  <path d="M54 116 h12 l-3 10 h-6z" fill="#B0123F"/>
  <path d="M22 38 C26 26 40 22 48 28 C38 30 30 36 26 48Z" fill="#FFFFFF" opacity="0.6"/>
</svg>''';

  static const loveLetter = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 220 170">
  <ellipse cx="110" cy="160" rx="96" ry="7" fill="#000" opacity="0.12"/>
  <rect x="14" y="30" width="192" height="124" rx="12" fill="#FFF3F6"/>
  <path d="M14 42 L110 112 L206 42" fill="none" stroke="#F3C6D3" stroke-width="5" stroke-linejoin="round"/>
  <path d="M18 150 L86 92 M202 150 L134 92" stroke="#F3C6D3" stroke-width="4"/>
  <path d="M110 122 C86 104 78 94 78 82 C78 72 86 66 94 66 C102 66 106 72 110 78 C114 72 118 66 126 66 C134 66 142 72 142 82 C142 94 134 104 110 122Z" fill="#E0194A"/>
  <path d="M88 76 C90 72 96 70 100 72" fill="none" stroke="#fff" stroke-width="3" stroke-linecap="round" opacity="0.7"/>
</svg>''';

  /// A round party balloon; colour as `#RRGGBB`.
  static String balloon(String color) =>
      '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 120 230">
  <defs>
    <radialGradient id="b" cx="0.35" cy="0.3" r="0.8"><stop offset="0" stop-color="#FFFFFF" stop-opacity="0.6"/><stop offset="0.4" stop-color="#FFFFFF" stop-opacity="0"/><stop offset="1" stop-color="#000000" stop-opacity="0.22"/></radialGradient>
  </defs>
  <path d="M60 134 Q48 164 64 186 Q78 206 58 228" fill="none" stroke="#B9B2C2" stroke-width="2"/>
  <ellipse cx="60" cy="66" rx="52" ry="62" fill="$color"/>
  <ellipse cx="60" cy="66" rx="52" ry="62" fill="url(#b)"/>
  <path d="M53 126 H67 L63 136 H57Z" fill="$color"/>
</svg>''';

  // ---- New year -----------------------------------------------------------

  static const toast = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 220 220">
  <defs>
    <linearGradient id="c" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#FFE08A"/><stop offset="1" stop-color="#E9A825"/></linearGradient>
  </defs>
  <g transform="rotate(-14 80 210)">
    <path d="M58 30 H102 C104 92 98 118 80 126 C62 118 56 92 58 30Z" fill="#EAF2FF" opacity="0.7"/>
    <path d="M60 62 H100 C100 98 94 116 80 122 C66 116 60 98 60 62Z" fill="url(#c)"/>
    <circle cx="74" cy="96" r="2.5" fill="#fff"/><circle cx="84" cy="80" r="2" fill="#fff"/><circle cx="80" cy="108" r="2" fill="#fff"/>
    <rect x="77" y="124" width="6" height="62" fill="#EAF2FF"/>
    <ellipse cx="80" cy="188" rx="26" ry="7" fill="#EAF2FF"/>
    <path d="M64 36 C64 70 66 96 72 112" fill="none" stroke="#fff" stroke-width="4" stroke-linecap="round" opacity="0.8"/>
  </g>
  <g transform="rotate(14 140 210)">
    <path d="M118 30 H162 C164 92 158 118 140 126 C122 118 116 92 118 30Z" fill="#EAF2FF" opacity="0.7"/>
    <path d="M120 62 H160 C160 98 154 116 140 122 C126 116 120 98 120 62Z" fill="url(#c)"/>
    <circle cx="134" cy="90" r="2.5" fill="#fff"/><circle cx="146" cy="104" r="2" fill="#fff"/><circle cx="140" cy="76" r="2" fill="#fff"/>
    <rect x="137" y="124" width="6" height="62" fill="#EAF2FF"/>
    <ellipse cx="140" cy="188" rx="26" ry="7" fill="#EAF2FF"/>
    <path d="M124 36 C124 70 126 96 132 112" fill="none" stroke="#fff" stroke-width="4" stroke-linecap="round" opacity="0.8"/>
  </g>
  <path d="M110.0 6.0 L112.8 19.2 L126.0 22.0 L112.8 24.8 L110.0 38.0 L107.2 24.8 L94.0 22.0 L107.2 19.2Z" fill="#FFE08A"/>
  <circle cx="86" cy="14" r="3" fill="#FFE08A"/><circle cx="136" cy="10" r="3" fill="#FFE08A"/>
</svg>''';

  static const partyHat = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 160 200">
  <defs>
    <clipPath id="c"><path d="M80 18 L140 178 Q80 194 20 178Z"/></clipPath>
  </defs>
  <g clip-path="url(#c)">
    <rect width="160" height="200" fill="#2C3F78"/>
    <path d="M0 70 L160 30 V52 L0 92Z M0 124 L160 84 V106 L0 146Z M0 178 L160 138 V160 L0 200Z" fill="#F5C451"/>
    <circle cx="70" cy="60" r="4" fill="#fff"/><circle cx="96" cy="112" r="4" fill="#fff"/><circle cx="60" cy="150" r="4" fill="#fff"/><circle cx="110" cy="164" r="4" fill="#fff"/>
  </g>
  <path d="M20 178 Q80 194 140 178" fill="none" stroke="#F5C451" stroke-width="10" stroke-linecap="round"/>
  <path d="M80 18 l-14 -12 M80 18 l0 -16 M80 18 l14 -12 M80 18 l-18 0 M80 18 l18 0" stroke="#F5C451" stroke-width="5" stroke-linecap="round"/>
  <circle cx="80" cy="18" r="9" fill="#FFE08A"/>
</svg>''';

  // ---- Summer -------------------------------------------------------------

  static const sunRays = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 200 200">
  <path d="M165.2 89.7 L196.0 100.0 L165.2 110.3Z M161.6 123.7 L183.1 148.0 L151.3 141.5Z M141.5 151.3 L148.0 183.1 L123.7 161.6Z M110.3 165.2 L100.0 196.0 L89.7 165.2Z M76.3 161.6 L52.0 183.1 L58.5 151.3Z M48.7 141.5 L16.9 148.0 L38.4 123.7Z M34.8 110.3 L4.0 100.0 L34.8 89.7Z M38.4 76.3 L16.9 52.0 L48.7 58.5Z M58.5 48.7 L52.0 16.9 L76.3 38.4Z M89.7 34.8 L100.0 4.0 L110.3 34.8Z M123.7 38.4 L148.0 16.9 L141.5 48.7Z M151.3 58.5 L183.1 52.0 L161.6 76.3Z" fill="#FFC21A" stroke="#FFC21A" stroke-width="6" stroke-linejoin="round"/>
</svg>''';

  static const sunFace = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 200 200">
  <defs>
    <radialGradient id="s" cx="0.4" cy="0.35" r="0.75"><stop offset="0" stop-color="#FFF08A"/><stop offset="1" stop-color="#FFB81C"/></radialGradient>
  </defs>
  <circle cx="100" cy="100" r="60" fill="url(#s)"/>
  <path d="M58 86 H96 Q96 112 78 112 Q60 112 58 86Z M104 86 H142 Q140 112 122 112 Q104 112 104 86Z" fill="#26262C"/>
  <path d="M56 86 H144" stroke="#26262C" stroke-width="5" stroke-linecap="round"/>
  <path d="M66 92 L74 92 M112 92 L120 92" stroke="#FFFFFF" stroke-width="3" stroke-linecap="round" opacity="0.7"/>
  <path d="M80 126 Q100 144 120 126" fill="none" stroke="#C2620A" stroke-width="5" stroke-linecap="round"/>
  <ellipse cx="62" cy="122" rx="9" ry="6" fill="#FF8A6B" opacity="0.5"/><ellipse cx="138" cy="122" rx="9" ry="6" fill="#FF8A6B" opacity="0.5"/>
</svg>''';

  static const palm = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 220 280">
  <defs>
    <linearGradient id="l" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#4CC46E"/><stop offset="1" stop-color="#1D7A43"/></linearGradient>
  </defs>
  <path d="M100 276 C104 200 114 140 124 86 L140 88 C130 140 122 204 122 276Z" fill="#B5793A"/>
  <path d="M104 250 h18 M106 220 h18 M108 190 h18 M111 160 h18 M115 130 h18 M119 104 h18" stroke="#8B5A2B" stroke-width="4" stroke-linecap="round"/>
  <path d="M132 84 C110 52 66 44 24 72 C64 62 98 70 128 92Z" fill="url(#l)"/>
  <path d="M132 84 C112 70 74 84 52 124 C82 98 106 92 130 94Z" fill="url(#l)"/>
  <path d="M132 84 C150 50 190 44 214 70 C180 62 156 70 136 92Z" fill="url(#l)"/>
  <path d="M132 84 C156 76 188 90 202 128 C176 102 154 96 134 94Z" fill="url(#l)"/>
  <path d="M132 84 C124 50 136 18 160 6 C146 34 142 60 140 88Z" fill="url(#l)"/>
  <circle cx="122" cy="96" r="9" fill="#7A4A1E"/><circle cx="138" cy="100" r="9" fill="#8B5A2B"/><circle cx="130" cy="108" r="8" fill="#6B3E16"/>
</svg>''';

  static const iceCream = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 160 240">
  <defs>
    <clipPath id="c"><path d="M30 112 H130 L80 236Z"/></clipPath>
  </defs>
  <g clip-path="url(#c)">
    <rect width="160" height="240" fill="#E9A85C"/>
    <path d="M0 120 L160 280 M0 150 L160 310 M0 90 L160 250 M0 60 L160 220 M160 120 L0 280 M160 150 L0 310 M160 90 L0 250 M160 60 L0 220" stroke="#C98436" stroke-width="4"/>
  </g>
  <circle cx="58" cy="96" r="34" fill="#8FE0C0"/>
  <circle cx="104" cy="96" r="34" fill="#FF9EC0"/>
  <circle cx="80" cy="58" r="36" fill="#FFF3D6"/>
  <path d="M26 104 Q34 124 46 110 Q56 126 66 112 Q76 126 86 112 Q96 126 106 112 Q116 126 124 110 Q134 120 136 102" fill="none" stroke="#FFFFFF" stroke-width="6" stroke-linecap="round" opacity="0.6"/>
  <circle cx="80" cy="18" r="12" fill="#E0194A"/>
  <path d="M80 8 Q86 -2 96 0" fill="none" stroke="#3E7A2B" stroke-width="3" stroke-linecap="round"/>
  <circle cx="76" cy="14" r="3" fill="#fff" opacity="0.7"/>
  <path d="M60 46 l6 4 M92 40 l4 -6 M100 66 l6 2 M66 70 l-4 6" stroke="#FF4D6D" stroke-width="4" stroke-linecap="round"/>
</svg>''';

  static const beachBall = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 200 200">
  <defs>
    <radialGradient id="s" cx="0.35" cy="0.3" r="0.9"><stop offset="0" stop-color="#FFFFFF" stop-opacity="0.45"/><stop offset="0.5" stop-color="#FFFFFF" stop-opacity="0"/><stop offset="1" stop-color="#000000" stop-opacity="0.22"/></radialGradient>
  </defs>
  <path d="M100 100 L100.0 10.0 A90 90 0 0 1 177.9 55.0Z" fill="#FF4D6D"/>
  <path d="M100 100 L177.9 55.0 A90 90 0 0 1 177.9 145.0Z" fill="#FFFFFF"/>
  <path d="M100 100 L177.9 145.0 A90 90 0 0 1 100.0 190.0Z" fill="#FFC21A"/>
  <path d="M100 100 L100.0 190.0 A90 90 0 0 1 22.1 145.0Z" fill="#FFFFFF"/>
  <path d="M100 100 L22.1 145.0 A90 90 0 0 1 22.1 55.0Z" fill="#2BB3E0"/>
  <path d="M100 100 L22.1 55.0 A90 90 0 0 1 100.0 10.0Z" fill="#FFFFFF"/>
  <circle cx="100" cy="100" r="90" fill="url(#s)"/>
  <circle cx="100" cy="100" r="13" fill="#FFFFFF"/>
</svg>''';

  static const hibiscus = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 200 200">
  <defs>
    <radialGradient id="p" cx="0.5" cy="0.9" r="1"><stop offset="0" stop-color="#C2124A"/><stop offset="0.35" stop-color="#FF4D6D"/><stop offset="1" stop-color="#FF8FA6"/></radialGradient>
  </defs>
  <g fill="url(#p)">
    <ellipse cx="100" cy="58" rx="34" ry="46"/>
    <ellipse cx="100" cy="58" rx="34" ry="46" transform="rotate(72 100 100)"/>
    <ellipse cx="100" cy="58" rx="34" ry="46" transform="rotate(144 100 100)"/>
    <ellipse cx="100" cy="58" rx="34" ry="46" transform="rotate(216 100 100)"/>
    <ellipse cx="100" cy="58" rx="34" ry="46" transform="rotate(288 100 100)"/>
  </g>
  <circle cx="100" cy="100" r="16" fill="#9E0C3A"/>
  <path d="M100 100 Q118 70 138 54" fill="none" stroke="#FFD166" stroke-width="5" stroke-linecap="round"/>
  <circle cx="140" cy="52" r="6" fill="#FFD166"/><circle cx="132" cy="46" r="4" fill="#FFD166"/><circle cx="146" cy="60" r="4" fill="#FFD166"/>
</svg>''';

  /// The main picture of each theme, for the staff previews.
  static String hero(String themeId) => switch (themeId) {
    'halloween' => pumpkin,
    'christmas' => tree,
    'newYear' => toast,
    'valentine' => heart,
    'carnival' => mask,
    'easter' => eggs.first,
    'summer' => iceCream,
    _ => heart,
  };

  /// What the venue logo wears while the theme is on.
  static String accessory(String themeId) => switch (themeId) {
    'halloween' => witchHat,
    'christmas' => santaHat,
    'newYear' => partyHat,
    'valentine' => heart,
    'carnival' => jesterHat,
    'easter' => bunnyEars,
    'summer' => hibiscus,
    _ => heart,
  };
}
