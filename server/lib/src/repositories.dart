import 'dart:convert';

import 'package:kiosk_core/kiosk_core.dart';
import 'package:sqlite3/sqlite3.dart' show Row;

import 'database.dart';

Map<String, Object?> _decode(Object? data) =>
    (jsonDecode(data as String) as Map).cast<String, Object?>();

class SettingsRepository {
  final AppDatabase _db;
  SettingsRepository(this._db);

  static const _key = 'kiosk';

  KioskSettings load() {
    final json = _db.readSetting(_key);
    if (json == null) return const KioskSettings();
    return KioskSettings.fromJson((json as Map).cast());
  }

  void save(KioskSettings settings) =>
      _db.writeSetting(_key, settings.toJson());

  bool get isInitialized => _db.readSetting(_key) != null;
}

class MenuRepository {
  final AppDatabase _db;
  MenuRepository(this._db);

  Menu loadAll() => Menu(
    categories: categories(),
    products: products(),
    modifierGroups: modifierGroups(),
  );

  /// The menu as the kiosk sees it: only enabled categories and products,
  /// and only groups/options actually usable.
  Menu loadForKiosk() {
    final cats = categories().where((c) => c.enabled).toList();
    final catIds = {for (final c in cats) c.id};
    final prods = products()
        .where((p) => p.enabled && catIds.contains(p.categoryId))
        .toList();
    final groupIds = {for (final p in prods) ...p.modifierGroupIds};
    final groups = [
      for (final g in modifierGroups())
        if (groupIds.contains(g.id))
          ModifierGroup(
            id: g.id,
            name: g.name,
            minSelect: g.minSelect,
            maxSelect: g.maxSelect,
            options: g.options.where((o) => o.enabled).toList(),
          ),
    ];
    return Menu(categories: cats, products: prods, modifierGroups: groups);
  }

  List<Category> categories() => [
    for (final r in _db.db.select(
      'SELECT data FROM categories ORDER BY sort_order, rowid',
    ))
      Category.fromJson(_decode(r['data'])),
  ];

  List<Product> products() => [
    for (final r in _db.db.select(
      'SELECT data FROM products ORDER BY sort_order, rowid',
    ))
      Product.fromJson(_decode(r['data'])),
  ];

  List<ModifierGroup> modifierGroups() => [
    for (final r in _db.db.select(
      'SELECT data FROM modifier_groups ORDER BY rowid',
    ))
      ModifierGroup.fromJson(_decode(r['data'])),
  ];

  Category? category(String id) {
    final r = _db.db.select('SELECT data FROM categories WHERE id = ?', [id]);
    return r.isEmpty ? null : Category.fromJson(_decode(r.first['data']));
  }

  Product? product(String id) {
    final r = _db.db.select('SELECT data FROM products WHERE id = ?', [id]);
    return r.isEmpty ? null : Product.fromJson(_decode(r.first['data']));
  }

  ModifierGroup? modifierGroup(String id) {
    final r = _db.db.select('SELECT data FROM modifier_groups WHERE id = ?', [
      id,
    ]);
    return r.isEmpty ? null : ModifierGroup.fromJson(_decode(r.first['data']));
  }

  void upsertCategory(Category c) => _db.db.execute(
    'INSERT INTO categories(id, sort_order, data) VALUES(?, ?, ?) '
    'ON CONFLICT(id) DO UPDATE SET sort_order = excluded.sort_order, '
    'data = excluded.data',
    [c.id, c.sortOrder, jsonEncode(c.toJson())],
  );

  void upsertProduct(Product p) => _db.db.execute(
    'INSERT INTO products(id, category_id, sort_order, data) '
    'VALUES(?, ?, ?, ?) ON CONFLICT(id) DO UPDATE SET '
    'category_id = excluded.category_id, sort_order = excluded.sort_order, '
    'data = excluded.data',
    [p.id, p.categoryId, p.sortOrder, jsonEncode(p.toJson())],
  );

  void upsertModifierGroup(ModifierGroup g) => _db.db.execute(
    'INSERT INTO modifier_groups(id, data) VALUES(?, ?) '
    'ON CONFLICT(id) DO UPDATE SET data = excluded.data',
    [g.id, jsonEncode(g.toJson())],
  );

  bool deleteCategory(String id) {
    _db.db.execute('DELETE FROM categories WHERE id = ?', [id]);
    return _db.db.updatedRows > 0;
  }

  bool deleteProduct(String id) {
    _db.db.execute('DELETE FROM products WHERE id = ?', [id]);
    return _db.db.updatedRows > 0;
  }

  bool deleteModifierGroup(String id) {
    _db.db.execute('DELETE FROM modifier_groups WHERE id = ?', [id]);
    return _db.db.updatedRows > 0;
  }

  int countProductsIn(String categoryId) =>
      _db.db.select(
            'SELECT COUNT(*) AS n FROM products WHERE category_id = ?',
            [categoryId],
          ).first['n']
          as int;

  bool get isEmpty =>
      _db.db.select('SELECT COUNT(*) AS n FROM categories').first['n'] == 0;
}

class OrderRepository {
  final AppDatabase _db;
  OrderRepository(this._db);

  static String businessDay(DateTime t) {
    final l = t.toLocal();
    return '${l.year.toString().padLeft(4, '0')}-'
        '${l.month.toString().padLeft(2, '0')}-'
        '${l.day.toString().padLeft(2, '0')}';
  }

  /// Next customer-facing number for the business day of [now] (1..999,
  /// then wraps). Must be called inside a transaction.
  int nextNumber(DateTime now) {
    final day = businessDay(now);
    final last = _db.db.select(
      'SELECT number FROM orders WHERE business_day = ? '
      'ORDER BY created_at DESC, rowid DESC LIMIT 1',
      [day],
    );
    if (last.isEmpty) return 1;
    final n = last.first['number'] as int;
    return n >= 999 ? 1 : n + 1;
  }

  void insert(Order o) => _db.db.execute(
    'INSERT INTO orders(id, number, business_day, created_at, status, '
    'payment_status, kitchen_status, is_demo, data) '
    'VALUES(?, ?, ?, ?, ?, ?, ?, ?, ?)',
    [
      o.id,
      o.number,
      businessDay(o.createdAt),
      o.createdAt.toUtc().toIso8601String(),
      o.status.name,
      o.paymentStatus.name,
      o.kitchenStatus.name,
      o.isDemo ? 1 : 0,
      jsonEncode(o.toJson()),
    ],
  );

  void update(Order o) => _db.db.execute(
    'UPDATE orders SET status = ?, payment_status = ?, kitchen_status = ?, '
    'data = ? WHERE id = ?',
    [
      o.status.name,
      o.paymentStatus.name,
      o.kitchenStatus.name,
      jsonEncode(o.toJson()),
      o.id,
    ],
  );

  Order? byId(String id) {
    final r = _db.db.select('SELECT data FROM orders WHERE id = ?', [id]);
    return r.isEmpty ? null : Order.fromJson(_decode(r.first['data']));
  }

  List<Order> query({
    String? businessDay,
    int? number,
    OrderStatus? status,
    PaymentStatus? paymentStatus,
    List<KitchenStatus>? kitchenStatuses,
    bool? isDemo,
    int limit = 200,
  }) {
    final where = <String>[];
    final args = <Object?>[];
    if (businessDay != null) {
      where.add('business_day = ?');
      args.add(businessDay);
    }
    if (number != null) {
      where.add('number = ?');
      args.add(number);
    }
    if (status != null) {
      where.add('status = ?');
      args.add(status.name);
    }
    if (paymentStatus != null) {
      where.add('payment_status = ?');
      args.add(paymentStatus.name);
    }
    if (kitchenStatuses != null && kitchenStatuses.isNotEmpty) {
      where.add(
        'kitchen_status IN (${List.filled(kitchenStatuses.length, '?').join(',')})',
      );
      args.addAll(kitchenStatuses.map((k) => k.name));
    }
    if (isDemo != null) {
      where.add('is_demo = ?');
      args.add(isDemo ? 1 : 0);
    }
    final sql = StringBuffer('SELECT data FROM orders');
    if (where.isNotEmpty) sql.write(' WHERE ${where.join(' AND ')}');
    sql.write(' ORDER BY created_at DESC, rowid DESC LIMIT ?');
    args.add(limit);
    return [
      for (final r in _db.db.select(sql.toString(), args))
        Order.fromJson(_decode(r['data'])),
    ];
  }
}

/// Discount codes. The use counter lives in its own column so that
/// claiming a use is a single atomic update.
class DiscountRepository {
  final AppDatabase _db;
  DiscountRepository(this._db);

  DiscountCode _read(Row r) => DiscountCode.fromJson(
    _decode(r['data']),
  ).copyWith(usedCount: r['used_count'] as int);

  List<DiscountCode> all() => [
    for (final r in _db.db.select(
      'SELECT data, used_count FROM discount_codes ORDER BY rowid DESC',
    ))
      _read(r),
  ];

  DiscountCode? byId(String id) {
    final r = _db.db.select(
      'SELECT data, used_count FROM discount_codes WHERE id = ?',
      [id],
    );
    return r.isEmpty ? null : _read(r.first);
  }

  DiscountCode? byCode(String code) {
    final r = _db.db.select(
      'SELECT data, used_count FROM discount_codes WHERE code = ?',
      [code],
    );
    return r.isEmpty ? null : _read(r.first);
  }

  /// Saves everything but the use counter.
  void upsert(DiscountCode c) => _db.db.execute(
    'INSERT INTO discount_codes(id, code, data) VALUES(?, ?, ?) '
    'ON CONFLICT(id) DO UPDATE SET code = excluded.code, '
    'data = excluded.data',
    [c.id, c.code, jsonEncode(c.toJson())],
  );

  bool delete(String id) {
    _db.db.execute('DELETE FROM discount_codes WHERE id = ?', [id]);
    return _db.db.updatedRows > 0;
  }

  /// Takes one use if the limit allows; false when exhausted.
  bool claim(String id, int? maxUses) {
    _db.db.execute(
      'UPDATE discount_codes SET used_count = used_count + 1 '
      'WHERE id = ? AND (? IS NULL OR used_count < ?)',
      [id, maxUses, maxUses],
    );
    return _db.db.updatedRows > 0;
  }

  void release(String id) => _db.db.execute(
    'UPDATE discount_codes SET used_count = MAX(used_count - 1, 0) '
    'WHERE id = ?',
    [id],
  );

  void resetUses(String id) => _db.db.execute(
    'UPDATE discount_codes SET used_count = 0 WHERE id = ?',
    [id],
  );

  bool get isEmpty =>
      _db.db.select('SELECT COUNT(*) AS n FROM discount_codes').first['n'] == 0;
}

class PrintJob {
  final int id;
  final DateTime createdAt;
  final String printer;
  final String kind;
  final String? orderId;
  final String content;
  final String status;
  final String? error;

  const PrintJob({
    required this.id,
    required this.createdAt,
    required this.printer,
    required this.kind,
    required this.orderId,
    required this.content,
    required this.status,
    required this.error,
  });

  Map<String, Object?> toJson() => {
    'id': id,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'printer': printer,
    'kind': kind,
    'orderId': orderId,
    'content': content,
    'status': status,
    'error': error,
  };
}

class PrintJobRepository {
  final AppDatabase _db;
  PrintJobRepository(this._db);

  int insert({
    required String printer,
    required String kind,
    required String? orderId,
    required String content,
    required String status,
    String? error,
  }) {
    _db.db.execute(
      'INSERT INTO print_jobs(created_at, printer, kind, order_id, content, '
      'status, error) VALUES(?, ?, ?, ?, ?, ?, ?)',
      [
        DateTime.now().toUtc().toIso8601String(),
        printer,
        kind,
        orderId,
        content,
        status,
        error,
      ],
    );
    return _db.db.lastInsertRowId;
  }

  List<PrintJob> recent({String? orderId, int limit = 50}) => [
    for (final r in _db.db.select(
      'SELECT * FROM print_jobs '
      '${orderId != null ? 'WHERE order_id = ? ' : ''}'
      'ORDER BY id DESC LIMIT ?',
      [?orderId, limit],
    ))
      PrintJob(
        id: r['id'] as int,
        createdAt: DateTime.parse(r['created_at'] as String),
        printer: r['printer'] as String,
        kind: r['kind'] as String,
        orderId: r['order_id'] as String?,
        content: r['content'] as String,
        status: r['status'] as String,
        error: r['error'] as String?,
      ),
  ];
}
