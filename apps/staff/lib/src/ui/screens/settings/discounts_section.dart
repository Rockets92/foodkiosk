import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:kiosk_core/kiosk_core.dart';

import '../../theme.dart';
import 'fields.dart';

/// Discount codes: on or off, and which ways of entering them the venue
/// has (on-screen keyboard, a QR/barcode reader on the totem, the till).
class DiscountsSection extends StatelessWidget {
  final DiscountSettings value;
  final ValueChanged<DiscountSettings> onChanged;
  const DiscountsSection({
    super.key,
    required this.value,
    required this.onChanged,
  });

  DiscountSettings _with({
    bool? enabled,
    bool? manualEntry,
    bool? scanner,
    bool? atCounter,
  }) => DiscountSettings(
    enabled: enabled ?? value.enabled,
    manualEntry: manualEntry ?? value.manualEntry,
    scanner: scanner ?? value.scanner,
    atCounter: atCounter ?? value.atCounter,
  );

  @override
  Widget build(BuildContext context) {
    final v = value;
    final nowhere = v.enabled && !v.onKiosk && !v.onCounter;
    return SectionCard(
      icon: Icons.local_offer_rounded,
      title: 'Codici sconto',
      subtitle:
          'Percentuali, importi e prodotti in omaggio: dove si accettano e '
          'come si inseriscono',
      accent: S.success,
      trailing: Transform.scale(
        scale: 1.2,
        child: Switch(
          key: const ValueKey('discounts-switch'),
          value: v.enabled,
          onChanged: (on) => onChanged(_with(enabled: on)),
        ),
      ),
      child: AnimatedSize(
        duration: S.medium,
        curve: Curves.easeOutCubic,
        alignment: Alignment.topCenter,
        child: !v.enabled
            ? const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Spenti: il totem e la cassa non mostrano niente dei codici '
                  'sconto e la sezione "Sconti" è nascosta.',
                  style: ST.small,
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  LayoutBuilder(
                    builder: (context, box) {
                      final cards = [
                        _ModeCard(
                          key: const ValueKey('discounts-manual'),
                          icon: Icons.keyboard_rounded,
                          title: 'Tastiera sul totem',
                          text:
                              'Nel carrello il cliente tocca "Hai un codice '
                              'sconto?" e lo scrive con la tastiera a schermo.',
                          selected: v.manualEntry,
                          onTap: () =>
                              onChanged(_with(manualEntry: !v.manualEntry)),
                        ),
                        _ModeCard(
                          key: const ValueKey('discounts-scanner'),
                          icon: Icons.qr_code_scanner_rounded,
                          title: 'Lettore QR / barcode',
                          text:
                              'Per totem con lettore integrato: il coupon si '
                              'applica appena scansionato, anche dalla '
                              'schermata di attesa.',
                          selected: v.scanner,
                          onTap: () => onChanged(_with(scanner: !v.scanner)),
                        ),
                        _ModeCard(
                          key: const ValueKey('discounts-counter'),
                          icon: Icons.point_of_sale_rounded,
                          title: 'In cassa',
                          text:
                              'Il cassiere applica i codici agli ordini, '
                              'scrivendoli o con un lettore collegato al PC.',
                          selected: v.atCounter,
                          onTap: () =>
                              onChanged(_with(atCounter: !v.atCounter)),
                        ),
                      ];
                      if (box.maxWidth < 760) {
                        return Column(
                          children: [
                            for (final c in cards)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: c,
                              ),
                          ],
                        );
                      }
                      return IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (final (i, c) in cards.indexed) ...[
                              if (i > 0) const SizedBox(width: 12),
                              Expanded(child: c),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
                  if (nowhere)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        'Scegli almeno un modo per inserire i codici, '
                        'oppure spegnili.',
                        style: ST.small.copyWith(color: S.red),
                      ).animate().shake(hz: 4, duration: 400.ms),
                    ),
                  if (v.scanner || v.atCounter) const _ScannerHelp(),
                ],
              ),
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;
  final bool selected;
  final VoidCallback onTap;
  const _ModeCard({
    super.key,
    required this.icon,
    required this.title,
    required this.text,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => InkWell(
    borderRadius: BorderRadius.circular(18),
    onTap: onTap,
    child: AnimatedContainer(
      duration: S.medium,
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: selected ? S.success.withValues(alpha: 0.08) : S.background,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: selected ? S.success : S.line,
          width: selected ? 2 : 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AnimatedContainer(
                duration: S.medium,
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: selected ? S.success : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: selected ? Colors.white : S.inkSoft),
              ),
              const Spacer(),
              AnimatedSwitcher(
                duration: S.fast,
                child: Icon(
                  selected
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  key: ValueKey(selected),
                  color: selected ? S.success : S.muted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(title, style: ST.h3),
          const SizedBox(height: 2),
          Text(text, style: ST.small),
        ],
      ),
    ),
  );
}

/// How to connect a reader, and a field to try it.
class _ScannerHelp extends StatefulWidget {
  const _ScannerHelp();

  @override
  State<_ScannerHelp> createState() => _ScannerHelpState();
}

class _ScannerHelpState extends State<_ScannerHelp> {
  final _controller = TextEditingController();
  String? _read;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final read = _read;
    final code = read == null ? null : DiscountCode.normalize(read);
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: S.info.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.usb_rounded, color: S.info),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Collegare il lettore', style: ST.h3),
                const SizedBox(height: 2),
                const Text(
                  'Usa un lettore USB in modalità tastiera (HID) con invio '
                  '(Enter) dopo il codice: è l\'impostazione di fabbrica di '
                  'quasi tutti i lettori, nessun driver da installare. Legge '
                  'QR code e codici a barre; un QR con un link è accettato se '
                  'il link contiene ?code=CODICE.',
                  style: ST.small,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    SizedBox(
                      width: 300,
                      child: TextField(
                        key: const ValueKey('scanner-test'),
                        controller: _controller,
                        decoration: const InputDecoration(
                          isDense: true,
                          prefixIcon: Icon(Icons.qr_code_scanner_rounded),
                          hintText: 'Prova: clicca qui e scansiona',
                        ),
                        onSubmitted: (v) {
                          setState(() => _read = v);
                          _controller.clear();
                        },
                      ),
                    ),
                    const SizedBox(width: 14),
                    if (code != null)
                      Flexible(
                        child: Text(
                          DiscountCode.isValidCode(code)
                              ? 'Letto: $code ✓'
                              : 'Letto "$read": non è un codice valido',
                          style: ST.body.copyWith(
                            fontWeight: FontWeight.w700,
                            color: DiscountCode.isValidCode(code)
                                ? S.success
                                : S.red,
                          ),
                        ).animate(key: ValueKey(read)).fadeIn().slideX(),
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
