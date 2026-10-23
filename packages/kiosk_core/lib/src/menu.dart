import 'allergen.dart';
import 'localized_text.dart';
import 'money.dart';
import 'order.dart';

List<T> _parseEnumList<T>(Object? json, T? Function(String) parse) => [
  for (final code in (json as List? ?? const [])) ?parse(code as String),
];

class Category {
  final String id;
  final LocalizedText name;
  final LocalizedText description;
  final String? imageUrl;
  final int sortOrder;
  final bool enabled;

  /// Service modes in which the category is shown; empty means all.
  final Set<ServiceMode> serviceModes;

  const Category({
    required this.id,
    required this.name,
    this.description = const LocalizedText.empty(),
    this.imageUrl,
    this.sortOrder = 0,
    this.enabled = true,
    this.serviceModes = const {},
  });

  bool visibleFor(ServiceMode mode) =>
      serviceModes.isEmpty || serviceModes.contains(mode);

  factory Category.fromJson(Map<String, Object?> json) => Category(
    id: json['id'] as String,
    name: LocalizedText.fromJson(json['name']),
    description: LocalizedText.fromJson(json['description']),
    imageUrl: json['imageUrl'] as String?,
    sortOrder: json['sortOrder'] as int? ?? 0,
    enabled: json['enabled'] as bool? ?? true,
    serviceModes: _parseEnumList(
      json['serviceModes'],
      ServiceMode.tryParse,
    ).toSet(),
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name.toJson(),
    'description': description.toJson(),
    'imageUrl': imageUrl,
    'sortOrder': sortOrder,
    'enabled': enabled,
    'serviceModes': [for (final m in serviceModes) m.name],
  };

  Category copyWith({
    LocalizedText? name,
    LocalizedText? description,
    String? imageUrl,
    int? sortOrder,
    bool? enabled,
    Set<ServiceMode>? serviceModes,
  }) => Category(
    id: id,
    name: name ?? this.name,
    description: description ?? this.description,
    imageUrl: imageUrl ?? this.imageUrl,
    sortOrder: sortOrder ?? this.sortOrder,
    enabled: enabled ?? this.enabled,
    serviceModes: serviceModes ?? this.serviceModes,
  );
}

/// One selectable option inside a [ModifierGroup] (e.g. "Bacon +1,00 €").
class ModifierOption {
  final String id;
  final LocalizedText name;
  final Cents priceDeltaCents;
  final List<Allergen> allergens;
  final bool enabled;
  final bool selectedByDefault;

  /// Optional picture, shown on the kiosk as an illustrated choice.
  final String? imageUrl;

  const ModifierOption({
    required this.id,
    required this.name,
    this.imageUrl,
    this.priceDeltaCents = 0,
    this.allergens = const [],
    this.enabled = true,
    this.selectedByDefault = false,
  });

  factory ModifierOption.fromJson(Map<String, Object?> json) => ModifierOption(
    id: json['id'] as String,
    name: LocalizedText.fromJson(json['name']),
    imageUrl: json['imageUrl'] as String?,
    priceDeltaCents: json['priceDeltaCents'] as int? ?? 0,
    allergens: _parseEnumList(json['allergens'], Allergen.tryParse),
    enabled: json['enabled'] as bool? ?? true,
    selectedByDefault: json['selectedByDefault'] as bool? ?? false,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name.toJson(),
    'imageUrl': imageUrl,
    'priceDeltaCents': priceDeltaCents,
    'allergens': [for (final a in allergens) a.name],
    'enabled': enabled,
    'selectedByDefault': selectedByDefault,
  };
}

/// A set of choices attached to products: sizes, sides, extras, removals.
class ModifierGroup {
  final String id;
  final LocalizedText name;
  final int minSelect;

  /// Maximum number of options; 0 means unlimited.
  final int maxSelect;
  final List<ModifierOption> options;

  const ModifierGroup({
    required this.id,
    required this.name,
    this.minSelect = 0,
    this.maxSelect = 1,
    this.options = const [],
  });

  bool get required => minSelect > 0;

  ModifierOption? option(String id) {
    for (final o in options) {
      if (o.id == id) return o;
    }
    return null;
  }

  factory ModifierGroup.fromJson(Map<String, Object?> json) => ModifierGroup(
    id: json['id'] as String,
    name: LocalizedText.fromJson(json['name']),
    minSelect: json['minSelect'] as int? ?? 0,
    maxSelect: json['maxSelect'] as int? ?? 1,
    options: [
      for (final o in (json['options'] as List? ?? const []))
        ModifierOption.fromJson((o as Map).cast()),
    ],
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name.toJson(),
    'minSelect': minSelect,
    'maxSelect': maxSelect,
    'options': [for (final o in options) o.toJson()],
  };
}

class Product {
  final String id;
  final String categoryId;
  final LocalizedText name;
  final LocalizedText description;
  final String? imageUrl;
  final Cents priceCents;

  /// VAT rate in percent (10 for food served in Italy, 22 for some drinks).
  final double vatRate;
  final List<Allergen> allergens;
  final List<DietaryTag> tags;
  final int? kcal;
  final int sortOrder;

  /// Short promotional label shown on the product card ("Novità", "Top").
  final LocalizedText badge;

  /// Shown on the kiosk at all.
  final bool enabled;

  /// Temporarily sold out ("esaurito"): shown greyed out, not orderable.
  final bool soldOut;

  /// When true and stock tracking is on in settings, [stockQty] is
  /// decremented on each order and the product sells out at 0.
  final bool trackStock;
  final int stockQty;
  final List<String> modifierGroupIds;

  const Product({
    required this.id,
    required this.categoryId,
    required this.name,
    required this.priceCents,
    this.description = const LocalizedText.empty(),
    this.imageUrl,
    this.vatRate = 10,
    this.allergens = const [],
    this.tags = const [],
    this.kcal,
    this.sortOrder = 0,
    this.badge = const LocalizedText.empty(),
    this.enabled = true,
    this.soldOut = false,
    this.trackStock = false,
    this.stockQty = 0,
    this.modifierGroupIds = const [],
  });

  factory Product.fromJson(Map<String, Object?> json) => Product(
    id: json['id'] as String,
    categoryId: json['categoryId'] as String,
    name: LocalizedText.fromJson(json['name']),
    description: LocalizedText.fromJson(json['description']),
    imageUrl: json['imageUrl'] as String?,
    badge: LocalizedText.fromJson(json['badge']),
    priceCents: json['priceCents'] as int,
    vatRate: (json['vatRate'] as num? ?? 10).toDouble(),
    allergens: _parseEnumList(json['allergens'], Allergen.tryParse),
    tags: _parseEnumList(json['tags'], DietaryTag.tryParse),
    kcal: json['kcal'] as int?,
    sortOrder: json['sortOrder'] as int? ?? 0,
    enabled: json['enabled'] as bool? ?? true,
    soldOut: json['soldOut'] as bool? ?? false,
    trackStock: json['trackStock'] as bool? ?? false,
    stockQty: json['stockQty'] as int? ?? 0,
    modifierGroupIds: [
      for (final id in (json['modifierGroupIds'] as List? ?? const []))
        id as String,
    ],
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'categoryId': categoryId,
    'name': name.toJson(),
    'description': description.toJson(),
    'imageUrl': imageUrl,
    'badge': badge.toJson(),
    'priceCents': priceCents,
    'vatRate': vatRate,
    'allergens': [for (final a in allergens) a.name],
    'tags': [for (final t in tags) t.name],
    'kcal': kcal,
    'sortOrder': sortOrder,
    'enabled': enabled,
    'soldOut': soldOut,
    'trackStock': trackStock,
    'stockQty': stockQty,
    'modifierGroupIds': modifierGroupIds,
  };

  Product copyWith({bool? soldOut, int? stockQty, bool? enabled}) =>
      Product.fromJson({
        ...toJson(),
        'soldOut': ?soldOut,
        'stockQty': ?stockQty,
        'enabled': ?enabled,
      });
}

/// The whole menu as served to the kiosk.
class Menu {
  final List<Category> categories;
  final List<Product> products;
  final List<ModifierGroup> modifierGroups;

  const Menu({
    this.categories = const [],
    this.products = const [],
    this.modifierGroups = const [],
  });

  Product? product(String id) {
    for (final p in products) {
      if (p.id == id) return p;
    }
    return null;
  }

  ModifierGroup? modifierGroup(String id) {
    for (final g in modifierGroups) {
      if (g.id == id) return g;
    }
    return null;
  }

  List<Product> productsIn(String categoryId) =>
      products.where((p) => p.categoryId == categoryId).toList()
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

  /// All allergens of a product including those of the chosen options.
  List<Allergen> allergensFor(Product product, Iterable<String> optionIds) {
    final result = {...product.allergens};
    for (final gid in product.modifierGroupIds) {
      final group = modifierGroup(gid);
      if (group == null) continue;
      for (final oid in optionIds) {
        final opt = group.option(oid);
        if (opt != null) result.addAll(opt.allergens);
      }
    }
    return Allergen.values.where(result.contains).toList();
  }

  factory Menu.fromJson(Map<String, Object?> json) => Menu(
    categories: [
      for (final c in (json['categories'] as List? ?? const []))
        Category.fromJson((c as Map).cast()),
    ],
    products: [
      for (final p in (json['products'] as List? ?? const []))
        Product.fromJson((p as Map).cast()),
    ],
    modifierGroups: [
      for (final g in (json['modifierGroups'] as List? ?? const []))
        ModifierGroup.fromJson((g as Map).cast()),
    ],
  );

  Map<String, Object?> toJson() => {
    'categories': [for (final c in categories) c.toJson()],
    'products': [for (final p in products) p.toJson()],
    'modifierGroups': [for (final g in modifierGroups) g.toJson()],
  };
}
