import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../scope.dart';
import '../theme.dart';

/// Image from the server; supports the SVG illustrations and real photos.
class NetImage extends StatelessWidget {
  final String? path;
  final BoxFit fit;

  /// Repaints an SVG in the palette colours (for the placeholder logo).
  final bool recolor;

  const NetImage(
    this.path, {
    super.key,
    this.fit = BoxFit.contain,
    this.recolor = false,
  });

  @override
  Widget build(BuildContext context) {
    final url = context.kiosk.backend.imageUrl(path);
    const fallback = Center(
      child: Icon(
        Icons.lunch_dining_rounded,
        size: 72,
        color: Color(0x33000000),
      ),
    );
    if (url == null) return fallback;
    if (Uri.parse(url).path.endsWith('.svg')) {
      return SvgPicture.network(
        url,
        fit: fit,
        colorMapper: recolor ? PaletteColorMapper(K.palette) : null,
        placeholderBuilder: (_) => const SizedBox.expand(),
      );
    }
    return Image.network(
      url,
      fit: fit,
      gaplessPlayback: true,
      errorBuilder: (_, _, _) => fallback,
      frameBuilder: (_, child, frame, sync) => AnimatedOpacity(
        opacity: sync || frame != null ? 1 : 0,
        duration: const Duration(milliseconds: 300),
        child: child,
      ),
    );
  }
}

/// UI illustration bundled with the app.
class Illustration extends StatelessWidget {
  final String name;
  final double? size;

  /// Repaints the brand red and yellow in the palette colours.
  final bool recolor;
  const Illustration(this.name, {super.key, this.size, this.recolor = true});

  @override
  Widget build(BuildContext context) => SvgPicture.asset(
    'assets/illustrations/$name.svg',
    width: size,
    height: size,
    colorMapper: recolor ? PaletteColorMapper(K.palette) : null,
  );
}
