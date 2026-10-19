/// Generated placeholder images, used until the venue uploads real photos
/// and a logo. `/media/placeholder/<label>.svg?` -> a coloured tile with
/// the label, colour derived from the label so each product differs.
String placeholderSvg(String name) {
  final label = Uri.decodeComponent(
    name,
  ).replaceAll(RegExp(r'\.svg$'), '').replaceAll(RegExp(r'[-_]+'), ' ').trim();
  final text = _escape(label.isEmpty ? 'Food Kiosk' : label);
  final hue = label.codeUnits.fold<int>(7, (h, c) => (h * 31 + c) % 360);
  final isLogo = label.toLowerCase() == 'logo';
  return '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 400 400" width="400" height="400">
  <defs>
    <linearGradient id="g" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="hsl($hue,70%,62%)"/>
      <stop offset="1" stop-color="hsl(${(hue + 40) % 360},70%,45%)"/>
    </linearGradient>
  </defs>
  <rect width="400" height="400" rx="${isLogo ? 200 : 32}" fill="url(#g)"/>
  <circle cx="200" cy="165" r="70" fill="rgba(255,255,255,0.25)"/>
  <text x="200" y="${isLogo ? 215 : 300}" text-anchor="middle"
        font-family="Segoe UI, Roboto, Helvetica, Arial, sans-serif"
        font-size="${text.length > 14 ? 30 : 38}" font-weight="700" fill="#fff">$text</text>
</svg>''';
}

String _escape(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');
