import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme.dart';
import '../../widgets/common.dart';

/// A titled card grouping the settings of one section.
class SectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget child;

  /// Defaults to the palette's primary colour.
  final Color? accent;
  final Widget? trailing;

  const SectionCard({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    required this.child,
    this.accent,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final accent = this.accent ?? S.primary;
    return Panel(
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: accent),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: ST.h2),
                    if (subtitle != null) Text(subtitle!, style: ST.small),
                  ],
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 20),
          // List tiles inside paint their ink on this transparent Material.
          Material(type: MaterialType.transparency, child: child),
        ],
      ),
    );
  }
}

/// Label on the left, control on the right; stacks on narrow widths.
class SettingRow extends StatelessWidget {
  final String label;
  final String? help;
  final Widget child;
  const SettingRow({
    super.key,
    required this.label,
    this.help,
    required this.child,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: LayoutBuilder(
      builder: (context, box) {
        final text = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: ST.h3),
            if (help != null) Text(help!, style: ST.small),
          ],
        );
        if (box.maxWidth < 560) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [text, const SizedBox(height: 8), child],
          );
        }
        return Row(
          children: [
            SizedBox(width: 260, child: text),
            const SizedBox(width: 20),
            Expanded(
              child: Align(alignment: Alignment.centerLeft, child: child),
            ),
          ],
        );
      },
    ),
  );
}

/// Text field that follows [value] when it changes from outside (e.g. a
/// JSON edit or "Annulla modifiche") without fighting the user's typing.
class SyncedTextField extends StatefulWidget {
  final String value;
  final ValueChanged<String> onChanged;
  final String? label;
  final String? hint;
  final bool numeric;
  final bool decimal;
  final bool obscure;
  final double? width;
  final String? suffix;

  const SyncedTextField({
    super.key,
    required this.value,
    required this.onChanged,
    this.label,
    this.hint,
    this.numeric = false,
    this.decimal = false,
    this.obscure = false,
    this.width,
    this.suffix,
  });

  @override
  State<SyncedTextField> createState() => _SyncedTextFieldState();
}

class _SyncedTextFieldState extends State<SyncedTextField> {
  late final _controller = TextEditingController(text: widget.value);

  @override
  void didUpdateWidget(SyncedTextField old) {
    super.didUpdateWidget(old);
    if (widget.value != _controller.text) {
      _controller.value = TextEditingValue(
        text: widget.value,
        selection: TextSelection.collapsed(offset: widget.value.length),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final field = TextField(
      controller: _controller,
      obscureText: widget.obscure,
      keyboardType: widget.numeric
          ? TextInputType.numberWithOptions(decimal: widget.decimal)
          : null,
      inputFormatters: widget.numeric
          ? [
              FilteringTextInputFormatter.allow(
                RegExp(widget.decimal ? r'[0-9.]' : r'[0-9]'),
              ),
            ]
          : null,
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: widget.hint,
        suffixText: widget.suffix,
        isDense: true,
      ),
      onChanged: widget.onChanged,
    );
    return widget.width == null
        ? field
        : SizedBox(width: widget.width, child: field);
  }
}
