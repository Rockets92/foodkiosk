import 'dart:convert';

import 'package:sqlite3/sqlite3.dart';

/// Thin wrapper around SQLite with versioned migrations.
///
/// Entities are stored as JSON documents (the shapes come from
/// `kiosk_core`), with the few columns we filter or sort on extracted.
class AppDatabase {
  final Database db;

  AppDatabase._(this.db);

  factory AppDatabase.open(String path) {
    final db = sqlite3.open(path);
    db.execute('PRAGMA journal_mode = WAL;');
    db.execute('PRAGMA foreign_keys = ON;');
    return AppDatabase._(db)..migrate();
  }

  factory AppDatabase.inMemory() =>
      AppDatabase._(sqlite3.openInMemory())..migrate();

  static const _migrations = <String>[
    '''
    CREATE TABLE settings (
      key TEXT PRIMARY KEY,
      value TEXT NOT NULL
    );
    CREATE TABLE categories (
      id TEXT PRIMARY KEY,
      sort_order INTEGER NOT NULL DEFAULT 0,
      data TEXT NOT NULL
    );
    CREATE TABLE modifier_groups (
      id TEXT PRIMARY KEY,
      data TEXT NOT NULL
    );
    CREATE TABLE products (
      id TEXT PRIMARY KEY,
      category_id TEXT NOT NULL,
      sort_order INTEGER NOT NULL DEFAULT 0,
      data TEXT NOT NULL
    );
    CREATE INDEX products_category ON products(category_id);
    CREATE TABLE orders (
      id TEXT PRIMARY KEY,
      number INTEGER NOT NULL,
      business_day TEXT NOT NULL,
      created_at TEXT NOT NULL,
      status TEXT NOT NULL,
      payment_status TEXT NOT NULL,
      kitchen_status TEXT NOT NULL,
      is_demo INTEGER NOT NULL DEFAULT 0,
      data TEXT NOT NULL
    );
    CREATE INDEX orders_day_number ON orders(business_day, number);
    CREATE INDEX orders_status ON orders(status, kitchen_status);
    CREATE TABLE print_jobs (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      created_at TEXT NOT NULL,
      printer TEXT NOT NULL,
      kind TEXT NOT NULL,
      order_id TEXT,
      content TEXT NOT NULL,
      status TEXT NOT NULL,
      error TEXT
    );
    ''',
    '''
    CREATE TABLE discount_codes (
      id TEXT PRIMARY KEY,
      code TEXT NOT NULL UNIQUE,
      used_count INTEGER NOT NULL DEFAULT 0,
      data TEXT NOT NULL
    );
    ''',
  ];

  int get schemaVersion =>
      db.select('PRAGMA user_version;').first.columnAt(0) as int;

  void migrate() {
    var version = schemaVersion;
    while (version < _migrations.length) {
      transaction(() {
        db.execute(_migrations[version]);
        db.execute('PRAGMA user_version = ${version + 1};');
      });
      version++;
    }
  }

  T transaction<T>(T Function() body) {
    db.execute('BEGIN IMMEDIATE;');
    try {
      final result = body();
      db.execute('COMMIT;');
      return result;
    } catch (_) {
      db.execute('ROLLBACK;');
      rethrow;
    }
  }

  Object? readSetting(String key) {
    final rows = db.select('SELECT value FROM settings WHERE key = ?', [key]);
    if (rows.isEmpty) return null;
    return jsonDecode(rows.first['value'] as String);
  }

  void writeSetting(String key, Object? value) {
    db.execute(
      'INSERT INTO settings(key, value) VALUES(?, ?) '
      'ON CONFLICT(key) DO UPDATE SET value = excluded.value',
      [key, jsonEncode(value)],
    );
  }

  void deleteSetting(String key) =>
      db.execute('DELETE FROM settings WHERE key = ?', [key]);

  void close() => db.close();
}
