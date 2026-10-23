import 'package:kiosk_core/kiosk_core.dart';

import 'errors.dart';
import 'event_bus.dart';
import 'ids.dart';
import 'repositories.dart';

/// Validated menu editing for the admin panel.
class MenuService {
  final MenuRepository _repo;
  final EventBus _bus;

  MenuService(this._repo, this._bus);

  Menu kioskMenu() => _repo.loadForKiosk();
  Menu fullMenu() => _repo.loadAll();

  void _changed() => _bus.emit(ServerEvent.menuUpdated);

  Map<String, Object?> _withId(Map<String, Object?> json, String? id) {
    final name = LocalizedText.fromJson(json['name']);
    if (name.isEmpty) {
      throw ApiException.badRequest('nameRequired', 'A name is required.');
    }
    return {...json, 'id': id ?? json['id'] ?? slugId(name.resolve('it'))};
  }

  T _parse<T>(T Function() parse) {
    try {
      return parse();
    } on TypeError catch (e) {
      throw ApiException.badRequest('invalidBody', 'Malformed data: $e');
    }
  }

  Category saveCategory(Map<String, Object?> json, {String? id}) {
    if (id != null && _repo.category(id) == null) {
      throw ApiException.notFound('Category');
    }
    final c = _parse(() => Category.fromJson(_withId(json, id)));
    _repo.upsertCategory(c);
    _changed();
    return c;
  }

  void deleteCategory(String id) {
    if (_repo.countProductsIn(id) > 0) {
      throw ApiException.conflict(
        'categoryNotEmpty',
        'Move or delete the products of this category first.',
      );
    }
    if (!_repo.deleteCategory(id)) throw ApiException.notFound('Category');
    _changed();
  }

  Product saveProduct(Map<String, Object?> json, {String? id}) {
    if (id != null && _repo.product(id) == null) {
      throw ApiException.notFound('Product');
    }
    final p = _parse(() => Product.fromJson(_withId(json, id)));
    if (_repo.category(p.categoryId) == null) {
      throw ApiException.badRequest(
        'unknownCategory',
        'Category "${p.categoryId}" does not exist.',
      );
    }
    if (p.priceCents < 0) {
      throw ApiException.badRequest(
        'invalidPrice',
        'The price cannot be negative.',
      );
    }
    if (p.vatRate < 0 || p.vatRate > 100) {
      throw ApiException.badRequest('invalidVat', 'Invalid VAT rate.');
    }
    for (final gid in p.modifierGroupIds) {
      if (_repo.modifierGroup(gid) == null) {
        throw ApiException.badRequest(
          'unknownModifierGroup',
          'Option group "$gid" does not exist.',
        );
      }
    }
    _repo.upsertProduct(p);
    _changed();
    return p;
  }

  /// Quick toggles used from the admin list and the kitchen ("esaurito").
  Product patchProduct(
    String id, {
    bool? soldOut,
    bool? enabled,
    int? stockQty,
  }) {
    final p = _repo.product(id) ?? (throw ApiException.notFound('Product'));
    if (stockQty != null && stockQty < 0) {
      throw ApiException.badRequest(
        'invalidStock',
        'Stock cannot be negative.',
      );
    }
    final next = p.copyWith(
      soldOut: soldOut,
      enabled: enabled,
      stockQty: stockQty,
    );
    _repo.upsertProduct(next);
    _changed();
    return next;
  }

  void deleteProduct(String id) {
    if (!_repo.deleteProduct(id)) throw ApiException.notFound('Product');
    _changed();
  }

  ModifierGroup saveModifierGroup(Map<String, Object?> json, {String? id}) {
    if (id != null && _repo.modifierGroup(id) == null) {
      throw ApiException.notFound('Option group');
    }
    final withId = _withId(json, id);
    final options = [
      for (final o in (withId['options'] as List? ?? const []))
        _withId((o as Map).cast(), null),
    ];
    final g = _parse(
      () => ModifierGroup.fromJson({...withId, 'options': options}),
    );
    if (g.minSelect < 0 ||
        g.maxSelect < 0 ||
        (g.maxSelect > 0 && g.minSelect > g.maxSelect)) {
      throw ApiException.badRequest(
        'invalidLimits',
        'Invalid minimum/maximum selection.',
      );
    }
    if (g.minSelect > g.options.length) {
      throw ApiException.badRequest(
        'invalidLimits',
        'The group requires more choices than it has options.',
      );
    }
    if (g.options.map((o) => o.id).toSet().length != g.options.length) {
      throw ApiException.badRequest(
        'duplicateOption',
        'Option ids must be unique.',
      );
    }
    _repo.upsertModifierGroup(g);
    _changed();
    return g;
  }

  void deleteModifierGroup(String id) {
    final used = _repo.products().where((p) => p.modifierGroupIds.contains(id));
    if (used.isNotEmpty) {
      throw ApiException.conflict(
        'groupInUse',
        'The group is used by ${used.length} product(s); detach it first.',
      );
    }
    if (!_repo.deleteModifierGroup(id)) {
      throw ApiException.notFound('Option group');
    }
    _changed();
  }
}
