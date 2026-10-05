import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:calculator/utlis/trade_record_db.dart';
import 'package:calculator/utlis/gold_calculator.dart';

void main() {
  sqfliteFfiInit();
  test(
    'v4 migration preserves every old value and permits both gold modes',
    () async {
      final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
      addTearDown(db.close);
      await db.execute(
        'CREATE TABLE trade_records (id INTEGER PRIMARY KEY AUTOINCREMENT, balance REAL NOT NULL, investment REAL NOT NULL, leverage REAL NOT NULL, entry_price REAL NOT NULL, target_price REAL, stop_loss REAL NOT NULL, is_long INTEGER NOT NULL DEFAULT 1, remark TEXT, created_at TEXT NOT NULL)',
      );
      await db.insert('trade_records', {
        'id': 42,
        'balance': 1000,
        'investment': 1,
        'leverage': 10,
        'entry_price': 2000,
        'target_price': null,
        'stop_loss': 2,
        'is_long': 0,
        'remark': 'keep me',
        'created_at': '2026-01-01',
      });
      final before = (await db.query('trade_records')).single;
      await db.transaction(TradeRecordDb.migrateToV5);
      final after = (await db.query('trade_records')).single;
      for (final field in before.entries) {
        expect(after[field.key], field.value);
      }
      expect(after['record_type'], 'legacy');
      for (final lotMode in [true, false]) {
        final result = calculateGold(
          contract: const GoldContract(),
          lotMode: lotMode,
          isLong: true,
          percentRisk: false,
          inputs: {
            'Entry price': '2000',
            'Exit price': '2001',
            'Lot': '0.1',
            'Stop loss': '1990',
            'Risk amount': '100',
          },
        );
        final id = await db.insert('trade_records', {
          'record_type': 'xauusd',
          'entry_price': 2000,
          'created_at': '2026-02-01',
          'payload_json': jsonEncode(result.payload),
        });
        expect(id, greaterThan(42));
        final row = (await db.query(
          'trade_records',
          where: 'id = ?',
          whereArgs: [id],
        )).single;
        expect(
          GoldResult.decode(row['payload_json'] as String).rows,
          result.rows,
        );
        expect(row['leverage'], isNull);
      }
      expect((await db.query('trade_records')).length, 3);
      await db.delete(
        'trade_records',
        where: 'record_type = ?',
        whereArgs: ['xauusd'],
      );
      expect((await db.query('trade_records')).single['id'], 42);
    },
  );
}
