import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'gold_calculator.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class TradeRecordDb {
  TradeRecordDb._();

  static final TradeRecordDb instance = TradeRecordDb._();

  static const String _tableName = 'trade_records';
  static Database? _database;
  final ValueNotifier<int> changes = ValueNotifier(0);

  static Future<void> createSchema(DatabaseExecutor db) => db.execute('''
    CREATE TABLE trade_records (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      balance REAL, investment REAL, leverage REAL,
      entry_price REAL NOT NULL, target_price REAL, stop_loss REAL,
      is_long INTEGER NOT NULL DEFAULT 1, remark TEXT, created_at TEXT NOT NULL,
      record_type TEXT NOT NULL DEFAULT 'legacy', payload_json TEXT
    )
  ''');

  /// Called within sqflite's onUpgrade transaction; any failure rolls back.
  static Future<void> migrateToV5(DatabaseExecutor db) async {
    await db.execute('ALTER TABLE trade_records RENAME TO trade_records_v4');
    await createSchema(db);
    await db.execute(
      '''INSERT INTO trade_records
      (id, balance, investment, leverage, entry_price, target_price, stop_loss, is_long, remark, created_at)
      SELECT id, balance, investment, leverage, entry_price, target_price, stop_loss, is_long, remark, created_at FROM trade_records_v4''',
    );
    await db.execute('DROP TABLE trade_records_v4');
  }

  Future<int> insertGoldRecord(GoldResult result) async {
    final db = await _readyDatabase();
    final id = await db.insert(_tableName, {
      'record_type': 'xauusd',
      'payload_json': jsonEncode(result.payload),
      'entry_price': double.parse(
        (result.payload['inputs'] as Map)['Entry price'] as String,
      ),
      'is_long': result.payload['isLong'] == true ? 1 : 0,
      'remark': result.payload['remark'],
      'created_at': DateTime.now().toIso8601String(),
    });
    changes.value++;
    return id;
  }

  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }

    _database = await _initDb();
    return _database!;
  }

  Future<Database> _readyDatabase() async {
    final db = await database;
    await _ensureColumns(db);
    return db;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'calculator.db');

    return openDatabase(
      path,
      version: 5,
      onCreate: (db, version) async {
        await createSchema(db);
      },
      onOpen: (db) async {
        await _ensureColumns(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        await _ensureColumns(db);
        if (oldVersion < 5) await migrateToV5(db);
      },
    );
  }

  Future<void> _ensureColumns(Database db) async {
    final columns = await db.rawQuery('PRAGMA table_info($_tableName)');
    final hasIsLongColumn = columns.any((col) => col['name'] == 'is_long');
    final hasTargetPriceColumn = columns.any(
      (col) => col['name'] == 'target_price',
    );
    final hasRemarkColumn = columns.any((col) => col['name'] == 'remark');

    if (!hasIsLongColumn) {
      await db.execute(
        'ALTER TABLE $_tableName ADD COLUMN is_long INTEGER NOT NULL DEFAULT 1',
      );
    }

    if (!hasTargetPriceColumn) {
      await db.execute('ALTER TABLE $_tableName ADD COLUMN target_price REAL');
    }

    if (!hasRemarkColumn) {
      await db.execute('ALTER TABLE $_tableName ADD COLUMN remark TEXT');
    }
  }

  Future<int> insertTradeRecord({
    required double balance,
    required double investment,
    required double leverage,
    required double entryPrice,
    required double? targetPrice,
    required double stopLoss,
    required bool isLong,
    String? remark,
  }) async {
    final db = await _readyDatabase();
    final id = await db.insert(_tableName, {
      'balance': balance,
      'investment': investment,
      'leverage': leverage,
      'entry_price': entryPrice,
      'target_price': targetPrice,
      'stop_loss': stopLoss,
      'is_long': isLong ? 1 : 0,
      'remark': remark,
      'created_at': DateTime.now().toIso8601String(),
    });
    changes.value++;
    return id;
  }

  Future<List<Map<String, dynamic>>> getTradeRecords() async {
    final db = await _readyDatabase();
    return db.query(_tableName, orderBy: 'id DESC');
  }

  Future<int> deleteTradeRecordsByIds(List<int> ids) async {
    if (ids.isEmpty) {
      return 0;
    }

    final db = await _readyDatabase();
    final placeholders = List.filled(ids.length, '?').join(', ');
    return db.delete(
      _tableName,
      where: 'id IN ($placeholders)',
      whereArgs: ids,
    );
  }

  Future<int> clearTradeRecords() async {
    final db = await _readyDatabase();
    return db.delete(_tableName);
  }
}
