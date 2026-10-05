import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class TradeRecordDb {
  TradeRecordDb._();

  static final TradeRecordDb instance = TradeRecordDb._();

  static const String _tableName = 'trade_records';
  static Database? _database;

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
      version: 4,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $_tableName (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            balance REAL NOT NULL,
            investment REAL NOT NULL,
            leverage REAL NOT NULL,
            entry_price REAL NOT NULL,
            target_price REAL,
            stop_loss REAL NOT NULL,
            is_long INTEGER NOT NULL DEFAULT 1,
            remark TEXT,
            created_at TEXT NOT NULL
          )
        ''');
      },
      onOpen: (db) async {
        await _ensureColumns(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        await _ensureColumns(db);
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
      await db.execute(
        'ALTER TABLE $_tableName ADD COLUMN target_price REAL',
      );
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
    return db.insert(_tableName, {
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
