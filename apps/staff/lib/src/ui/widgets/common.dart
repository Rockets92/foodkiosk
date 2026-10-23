import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:kiosk_core/kiosk_core.dart';

import '../../api.dart';
import '../../session.dart';
import '../theme.dart';

/// White rounded card used to group content.
class Panel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;
  const Panel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.color = Colors.white,
  });

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(S.radius),
      boxShadow: S.shadow,
    ),
    // A Material so list tiles and ink splashes inside paint correctly.
    child: Material(
      color: color,
      borderRadius: BorderRadius.circular(S.radius),
      clipBehavior: Clip.antiAlias,
      child: Padding(padding: padding, child: child),
    ),
  );
}

/// Title row at the top of every page, with optional actions.
class PageHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> actions;
  const PageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(28, 24, 28, 16),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: ST.h1),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(subtitle!, style: ST.small),
              ],
            ],
          ),
        ),
        for (final a in actions) ...[const SizedBox(width: 10), a],
      ],
    ),
  );
}

/// Small coloured label (order status, payment, ...).
class Pill extends StatelessWidget {
  final String text;
  final Color color;
  final IconData? icon;
  const Pill(this.text, {super.key, required this.color, this.icon});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
        ],
        Text(
          text,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
      ],
    ),
  );
}

/// Product or option picture from the server (SVG or bitmap).
class ServerImage extends StatelessWidget {
  final String? path;
  final double size;
  final double radius;

  /// Repaints an SVG in the palette colours (for the placeholder logo).
  final bool recolor;
  const ServerImage(
    this.path, {
    super.key,
    this.size = 56,
    this.radius = 14,
    this.recolor = false,
  });

  @override
  Widget build(BuildContext context) {
    final url = context.staff.api.imageUrl(path);
    final placeholder = Icon(
      Icons.image_outlined,
      color: S.muted,
      size: size * 0.45,
    );
    Widget image;
    if (url == null) {
      image = placeholder;
    } else if (url.toLowerCase().endsWith('.svg')) {
      image = SvgPicture.network(
        url,
        fit: BoxFit.contain,
        colorMapper: recolor ? PaletteColorMapper(S.palette) : null,
        placeholderBuilder: (_) => placeholder,
        errorBuilder: (_, _, _) => placeholder,
      );
    } else {
      image = Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => placeholder,
      );
    }
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFFF6F1E9),
        borderRadius: BorderRadius.circular(radius),
      ),
      alignment: Alignment.center,
      padding: EdgeInsets.all(url != null && url.endsWith('.svg') ? 4 : 0),
      child: image,
    );
  }
}

/// Empty or error placeholder in the middle of a page.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.action,
  });

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 64, color: S.muted),
          const SizedBox(height: 12),
          Text(title, style: ST.h2, textAlign: TextAlign.center),
          if (message != null) ...[
            const SizedBox(height: 6),
            Text(message!, style: ST.small, textAlign: TextAlign.center),
          ],
          if (action != null) ...[const SizedBox(height: 18), action!],
        ],
      ),
    ),
  );
}

Future<bool> confirm(
  BuildContext context, {
  required String title,
  String? message,
  String confirmLabel = 'Conferma',
  bool destructive = false,
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title, style: ST.h2),
        content: message == null ? null : Text(message, style: ST.body),
        actions: [
          TextButton(
            key: const ValueKey('confirm-no'),
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            key: const ValueKey('confirm-yes'),
            style: destructive
                ? FilledButton.styleFrom(backgroundColor: S.primary)
                : null,
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    ) ??
    false;

void showMessage(BuildContext context, String text, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(content: Text(text), backgroundColor: error ? S.primary : S.ink),
    );
}

/// Runs a server call, showing errors as a snackbar. Returns null on error.
Future<T?> guard<T>(BuildContext context, Future<T> Function() call) async {
  try {
    return await call();
  } on ApiError catch (e) {
    if (context.mounted) showMessage(context, e.message, error: true);
    return null;
  }
}

String serviceModeLabel(ServiceMode m) => switch (m) {
  ServiceMode.eatIn => 'Mangio qui',
  ServiceMode.takeAway => 'Porto via',
};

IconData serviceModeIcon(ServiceMode m) => switch (m) {
  ServiceMode.eatIn => Icons.restaurant_rounded,
  ServiceMode.takeAway => Icons.shopping_bag_rounded,
};

(String, Color) paymentStatusLabel(PaymentStatus s) => switch (s) {
  PaymentStatus.notRequired => ('Pagamento esterno', S.muted),
  PaymentStatus.awaitingCounter => ('Da incassare', S.warning),
  PaymentStatus.awaitingKiosk => ('Attesa pagamento totem', S.warning),
  PaymentStatus.processing => ('Pagamento in corso', S.info),
  PaymentStatus.paid => ('Pagato', S.success),
  PaymentStatus.failed => ('Pagamento rifiutato', S.primary),
  PaymentStatus.refunded => ('Rimborsato', S.muted),
};

(String, Color) kitchenStatusLabel(KitchenStatus s) => switch (s) {
  KitchenStatus.none => ('Non in cucina', S.muted),
  KitchenStatus.queued => ('Da preparare', S.warning),
  KitchenStatus.preparing => ('In preparazione', S.info),
  KitchenStatus.ready => ('Pronto', S.success),
  KitchenStatus.collected => ('Consegnato', S.muted),
};

(String, Color) orderStatusLabel(OrderStatus s) => switch (s) {
  OrderStatus.open => ('Aperto', S.info),
  OrderStatus.completed => ('Completato', S.success),
  OrderStatus.cancelled => ('Annullato', S.primary),
};

String flowActionLabel(FlowAction a) => switch (a) {
  FlowAction.printCustomerTicket => 'Scontrino cliente',
  FlowAction.printKitchenTicket => 'Stampa in cucina',
  FlowAction.sendToKitchenDisplay => 'Schermo cucina',
  FlowAction.issueFiscalDocument => 'Documento fiscale',
  FlowAction.announceOnPickupScreen => 'Schermo ritiro',
};

String flowEventLabel(FlowEvent e) => switch (e) {
  FlowEvent.submitted => 'Ordine confermato',
  FlowEvent.paid => 'Ordine pagato',
  FlowEvent.ready => 'Ordine pronto',
};

String paymentModeLabel(PaymentMode m) => switch (m) {
  PaymentMode.none => 'Nessun pagamento',
  PaymentMode.counter => 'In cassa',
  PaymentMode.kiosk => 'Sul totem (POS)',
  PaymentMode.customerChoice => 'A scelta del cliente',
};

String hhmm(DateTime t) {
  final l = t.toLocal();
  return '${l.hour.toString().padLeft(2, '0')}:'
      '${l.minute.toString().padLeft(2, '0')}';
}

String orderNumber(int n) => n.toString().padLeft(3, '0');
