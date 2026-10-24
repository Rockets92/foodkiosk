import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:kiosk_core/kiosk_core.dart';

import '../../theme.dart';
import 'fields.dart';

/// Colour palette of the kiosk and of this app, one card per preset with a
/// miniature of the totem drawn in its colours; then the holiday themes.
class AppearanceSection extends StatelessWidget {
  final String selected;
  final String venueName;
  final ValueChanged<String> onChanged;

  /// [HolidayMode.none], [HolidayMode.auto] or a [HolidayTheme] id.
  final String holiday;
  final ValueChanged<String> onHolidayChanged;

  /// Today, for the automatic mode; a parameter for the tests.
  final DateTime? today;

  const AppearanceSection({
    super.key,
    required this.selected,
    required this.venueName,
    required this.onChanged,
    required this.holiday,
    required this.onHolidayChanged,
    this.today,
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
          final now = today ?? DateTime.now();
          final todays = HolidayTheme.forDate(now);
          final active = HolidayMode.resolve(holiday, now);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (active != null) ...[
                _Notice(
                  'Il tema "${active.name}" è attivo: i suoi colori '
                  'sostituiscono la palette finché resta acceso.',
                ),
                const SizedBox(height: 16),
              ],
              Wrap(
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
              ),
              const SizedBox(height: 28),
              const Divider(height: 1),
              const SizedBox(height: 22),
              Row(
                children: [
                  Icon(Icons.celebration_rounded, color: S.primary),
                  const SizedBox(width: 10),
                  const Text('Temi delle festività', style: ST.h3),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'Colori, illustrazioni e animazioni a tema sulle schermate '
                'del totem (attesa, benvenuto, menu, carrello, conferma '
                'ordine). '
                'Accendine uno quando serve, oppure lascia che il '
                'calendario scelga da solo.',
                style: ST.small,
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  SizedBox(
                    width: width,
                    child: _HolidayModeCard(
                      id: HolidayMode.none,
                      icon: Icons.block_rounded,
                      title: 'Nessun tema',
                      subtitle: 'Solo la palette scelta qui sopra',
                      selected: holiday == HolidayMode.none,
                      onTap: () => onHolidayChanged(HolidayMode.none),
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: _HolidayModeCard(
                      id: HolidayMode.auto,
                      icon: Icons.event_repeat_rounded,
                      title: 'Automatico',
                      subtitle: todays == null
                          ? 'Segue il calendario. Oggi nessuna festività'
                          : 'Segue il calendario. Oggi: ${todays.name}',
                      selected: holiday == HolidayMode.auto,
                      onTap: () => onHolidayChanged(HolidayMode.auto),
                    ),
                  ),
                  for (final theme in HolidayTheme.presets)
                    SizedBox(
                      width: width,
                      child: _HolidayCard(
                        theme: theme,
                        venueName: venueName,
                        selected: holiday == theme.id,
                        onTap: () => onHolidayChanged(theme.id),
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  final String text;
  const _Notice(this.text);

  @override
  Widget build(BuildContext context) => Container(
    key: const ValueKey('holiday-active-notice'),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: S.primary.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      children: [
        Icon(Icons.celebration_rounded, color: S.primary, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text, style: ST.small.copyWith(color: S.ink)),
        ),
      ],
    ),
  );
}

/// Card frame shared by the holiday choices.
class _ChoiceFrame extends StatelessWidget {
  final String id;
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  final Widget child;

  const _ChoiceFrame({
    required this.id,
    required this.color,
    required this.selected,
    required this.onTap,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      key: ValueKey('holiday-$id'),
      duration: S.fast,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: selected ? color : S.line,
          width: selected ? 3 : 1.5,
        ),
        boxShadow: selected
            ? [
                BoxShadow(
                  color: color.withValues(alpha: 0.25),
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
          child: Stack(
            children: [
              child,
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
                      color: color,
                      size: 24,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "No theme" and "automatic".
class _HolidayModeCard extends StatelessWidget {
  final String id;
  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _HolidayModeCard({
    required this.id,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return _ChoiceFrame(
      id: id,
      color: S.primary,
      selected: selected,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 170,
            color: S.background,
            child: Icon(icon, size: 64, color: S.muted),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: ST.h3),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: ST.small,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A holiday theme, previewed as the kiosk idle screen in miniature.
class _HolidayCard extends StatelessWidget {
  final HolidayTheme theme;
  final String venueName;
  final bool selected;
  final VoidCallback onTap;

  const _HolidayCard({
    required this.theme,
    required this.venueName,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = theme.palette;
    return _ChoiceFrame(
      id: theme.id,
      color: Color(p.primary),
      selected: selected,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 170,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(p.primaryLight),
                  Color(p.primary),
                  Color(p.primaryDark),
                ],
              ),
            ),
            child: Stack(
              children: [
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  height: 22,
                  child: CustomPaint(painter: _BuntingPainter(theme)),
                ),
                Positioned(
                  left: 16,
                  right: 16,
                  top: 26,
                  bottom: 34,
                  child: SvgPicture.string(HolidayArt.hero(theme.id)),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 10,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Color(p.accent),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Tocca per ordinare',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: S.ink,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(theme.name, style: ST.h3)),
                    for (final c in [p.primary, p.accent])
                      Container(
                        width: 18,
                        height: 18,
                        margin: const EdgeInsets.only(left: 4),
                        decoration: BoxDecoration(
                          color: Color(c),
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0x22000000)),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  theme.description,
                  style: ST.small,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.event_rounded, size: 14, color: S.muted),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        theme.period,
                        style: ST.small.copyWith(color: S.muted, fontSize: 12),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Little pennants across the top of a holiday preview.
class _BuntingPainter extends CustomPainter {
  final HolidayTheme theme;
  _BuntingPainter(this.theme);

  @override
  void paint(Canvas canvas, Size size) {
    final p = theme.palette;
    final colors = [
      Color(p.accent),
      Colors.white,
      Color(p.primaryLight),
      Color(p.accent),
    ];
    canvas.drawLine(
      Offset.zero,
      Offset(size.width, 0),
      Paint()
        ..color = Colors.white54
        ..strokeWidth = 1.5,
    );
    const step = 20.0;
    for (var i = 0; i * step < size.width; i++) {
      final x = i * step + 4;
      canvas.drawPath(
        Path()
          ..moveTo(x, 0)
          ..lineTo(x + 12, 0)
          ..lineTo(x + 6, size.height * 0.7)
          ..close(),
        Paint()..color = colors[i % colors.length].withValues(alpha: 0.9),
      );
    }
  }

  @override
  bool shouldRepaint(_BuntingPainter old) => old.theme.id != theme.id;
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
