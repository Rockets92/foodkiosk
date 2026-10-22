import 'package:flutter/material.dart';
import 'package:kiosk_core/kiosk_core.dart';

import '../../theme.dart';
import 'fields.dart';

/// Colour palette of the kiosk and of this app, one card per preset with a
/// miniature of the totem drawn in its colours.
class AppearanceSection extends StatelessWidget {
  final String selected;
  final String venueName;
  final ValueChanged<String> onChanged;

  const AppearanceSection({
    super.key,
    required this.selected,
    required this.venueName,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      icon: Icons.palette_rounded,
      title: 'Aspetto',
      subtitle:
          'Colori del totem, del monitor ritiro e dell\'app staff. '
          'Si applicano a tutti i dispositivi appena salvi.',
      child: LayoutBuilder(
        builder: (context, box) {
          const gap = 16.0;
          final columns = (box.maxWidth / 240).floor().clamp(1, 4);
          final width = (box.maxWidth - gap * (columns - 1)) / columns;
          return Wrap(
            spacing: gap,
            runSpacing: gap,
            children: [
              for (final p in ColorPalette.presets)
                SizedBox(
                  width: width,
                  child: _PaletteCard(
                    palette: p,
                    venueName: venueName,
                    selected: p.id == selected,
                    onTap: () => onChanged(p.id),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _PaletteCard extends StatelessWidget {
  final ColorPalette palette;
  final String venueName;
  final bool selected;
  final VoidCallback onTap;

  const _PaletteCard({
    required this.palette,
    required this.venueName,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Color(palette.primary);
    return AnimatedContainer(
      key: ValueKey('palette-${palette.id}'),
      duration: S.fast,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: selected ? primary : S.line,
          width: selected ? 3 : 1.5,
        ),
        boxShadow: selected
            ? [
                BoxShadow(
                  color: primary.withValues(alpha: 0.25),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Stack(
                children: [
                  _Miniature(palette: palette, venueName: venueName),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: AnimatedScale(
                      duration: S.fast,
                      scale: selected ? 1 : 0,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.check_circle_rounded,
                          color: primary,
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(palette.name, style: ST.h3)),
                        for (final c in [
                          palette.primary,
                          palette.accent,
                          palette.background,
                        ])
                          Container(
                            width: 18,
                            height: 18,
                            margin: const EdgeInsets.only(left: 4),
                            decoration: BoxDecoration(
                              color: Color(c),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: const Color(0x22000000),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      palette.description,
                      style: ST.small,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The kiosk menu screen in miniature: hero header, category rail,
/// product tiles and the cart bar.
class _Miniature extends StatelessWidget {
  final ColorPalette palette;
  final String venueName;
  const _Miniature({required this.palette, required this.venueName});

  @override
  Widget build(BuildContext context) {
    final primary = Color(palette.primary);
    final accent = Color(palette.accent);
    final background = Color(palette.background);

    Widget tile(Color tint) => Expanded(
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: const [
            BoxShadow(
              color: Color(0x14000000),
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 34,
              decoration: BoxDecoration(
                color: tint,
                borderRadius: BorderRadius.circular(7),
              ),
              child: const Center(
                child: Icon(
                  Icons.lunch_dining_rounded,
                  size: 24,
                  color: Color(0xFFB5763A),
                ),
              ),
            ),
            const SizedBox(height: 5),
            Container(
              height: 5,
              width: 40,
              decoration: BoxDecoration(
                color: S.ink,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: accent,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                '€ 6,50',
                style: TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.w800,
                  color: S.ink,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    return Container(
      height: 170,
      color: background,
      child: Column(
        children: [
          Container(
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(palette.primaryLight),
                  primary,
                  Color(palette.primaryDark),
                ],
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: accent,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.restaurant_rounded,
                    size: 12,
                    color: S.ink,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    venueName.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 10,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    children: [
                      for (var i = 0; i < 3; i++)
                        Container(
                          width: 26,
                          height: 18,
                          margin: const EdgeInsets.only(bottom: 5),
                          decoration: BoxDecoration(
                            color: i == 0 ? primary : Colors.white,
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 8),
                  tile(const Color(0xFFFFE9D6)),
                  const SizedBox(width: 6),
                  tile(const Color(0xFFFFF1C7)),
                ],
              ),
            ),
          ),
          Container(
            height: 28,
            margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: S.ink,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.shopping_bag_rounded,
                  size: 14,
                  color: Colors.white,
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: const Text(
                    'Ordina',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: S.ink,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
