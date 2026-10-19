import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../scope.dart';

/// Image from the server; supports the SVG placeholders and real photos.
class NetImage extends StatelessWidget {
  final String? path;
  final BoxFit fit;

  const NetImage(this.path, {super.key, this.fit = BoxFit.cover});

  @override
  Widget build(BuildContext context) {
    final url = context.kiosk.backend.imageUrl(path);
    final fallback = ColoredBox(
      color: Theme.of(context).colorScheme.secondaryContainer,
      child: const Center(child: Icon(Icons.fastfood, size: 64)),
    );
    if (url == null) return fallback;
    if (Uri.parse(url).path.endsWith('.svg')) {
      return SvgPicture.network(
        url,
        fit: fit,
        placeholderBuilder: (_) => fallback,
      );
    }
    return Image.network(url, fit: fit, errorBuilder: (_, _, _) => fallback);
  }
}
