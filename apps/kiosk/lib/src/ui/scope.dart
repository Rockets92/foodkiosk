import 'package:flutter/widgets.dart';
import 'package:kiosk_core/kiosk_core.dart';

import '../i18n.dart';
import '../state/kiosk_controller.dart';

class KioskScope extends InheritedNotifier<KioskController> {
  const KioskScope({
    super.key,
    required KioskController controller,
    required super.child,
  }) : super(notifier: controller);

  static KioskController of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<KioskScope>()!.notifier!;
}

extension KioskContext on BuildContext {
  KioskController get kiosk => KioskScope.of(this);
  Strings get t => Strings(kiosk.language);
  String money(Cents c) =>
      formatCents(c, symbol: kiosk.settings.currencySymbol);
}
