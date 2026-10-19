import 'illustrations.dart';

/// Generated placeholder images, used until the venue uploads real photos
/// and a logo. `/media/placeholder/<key>.svg` returns the food illustration
/// for known keys (see `illustrations.dart`), the placeholder logo for
/// `logo`, and otherwise a coloured tile with the text, so any product
/// still gets a distinct image.
String placeholderSvg(String name) {
  final key = Uri.decodeComponent(name).replaceAll(RegExp(r'\.svg$'), '');
  if (illustrations[key] case final svg?) return svg;
  if (key.toLowerCase() == 'logo') return _logo;
  final label = key.replaceAll(RegExp(r'[-_]+'), ' ').trim();
  final text = _escape(label.isEmpty ? 'Food Kiosk' : label);
  final hue = label.codeUnits.fold<int>(7, (h, c) => (h * 31 + c) % 360);
  return '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 400 400" width="400" height="400">
  <defs>
    <linearGradient id="g" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="hsl($hue,70%,62%)"/>
      <stop offset="1" stop-color="hsl(${(hue + 40) % 360},70%,45%)"/>
    </linearGradient>
  </defs>
  <rect width="400" height="400" rx="32" fill="url(#g)"/>
  <circle cx="200" cy="165" r="70" fill="rgba(255,255,255,0.25)"/>
  <text x="200" y="300" text-anchor="middle"
        font-family="Segoe UI, Roboto, Helvetica, Arial, sans-serif"
        font-size="${text.length > 14 ? 30 : 38}" font-weight="700" fill="#fff">$text</text>
</svg>''';
}

String _escape(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');

/// Placeholder brand mark: a round badge with a stylised burger.
const _logo = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 400 400" width="400" height="400">
  <circle cx="200" cy="200" r="196" fill="#FFC72C"/>
  <circle cx="200" cy="200" r="170" fill="#D62300"/>
  <path d="M110 190 q0 -80 90 -80 q90 0 90 80z" fill="#FFC72C"/>
  <rect x="100" y="204" width="200" height="26" rx="13" fill="#FFF3D6"/>
  <path d="M110 244 h180 q0 46 -46 46 h-88 q-46 0 -46 -46z" fill="#FFC72C"/>
  <circle cx="160" cy="150" r="6" fill="#D62300"/><circle cx="200" cy="138" r="6" fill="#D62300"/><circle cx="240" cy="150" r="6" fill="#D62300"/>
</svg>''';
