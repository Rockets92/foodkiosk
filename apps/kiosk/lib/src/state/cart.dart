import 'package:flutter/foundation.dart';
import 'package:kiosk_core/kiosk_core.dart';

/// One line of the cart, before the order is sent. Prices shown on the
/// kiosk are a preview: the server re-prices everything on submission.
@immutable
class CartLine {
  final String productId;
  final List<String> optionIds;
  final int quantity;

  const CartLine({
    required this.productId,
    this.optionIds = const [],
    this.quantity = 1,
  });

  CartLine copyWith({List<String>? optionIds, int? quantity}) => CartLine(
    productId: productId,
    optionIds: optionIds ?? this.optionIds,
    quantity: quantity ?? this.quantity,
  );

  /// Same product with the same options: adding it again bumps quantity.
  bool sameItemAs(CartLine other) =>
      productId == other.productId &&
      setEquals(optionIds.toSet(), other.optionIds.toSet());

  OrderRequestLine toRequest() => OrderRequestLine(
    productId: productId,
    quantity: quantity,
    optionIds: optionIds,
  );
}

/// Price of one unit of [product] with [optionIds], from the menu.
Cents unitPrice(Menu menu, Product product, Iterable<String> optionIds) {
  var total = product.priceCents;
  final ids = optionIds.toSet();
  for (final gid in product.modifierGroupIds) {
    final group = menu.modifierGroup(gid);
    if (group == null) continue;
    for (final o in group.options) {
      if (ids.contains(o.id)) total += o.priceDeltaCents;
    }
  }
  return total;
}

/// Options preselected when opening a product.
List<String> defaultOptions(Menu menu, Product product) => [
  for (final gid in product.modifierGroupIds)
    if (menu.modifierGroup(gid) case final group?)
      for (final o in group.options)
        if (o.selectedByDefault && o.enabled) o.id,
];

/// Whether the selection in [group] respects its min/max limits.
bool groupSatisfied(ModifierGroup group, Set<String> selected) {
  final n = group.options.where((o) => selected.contains(o.id)).length;
  return n >= group.minSelect && (group.maxSelect == 0 || n <= group.maxSelect);
}
