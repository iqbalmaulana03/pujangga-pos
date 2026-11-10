import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as path;
import 'package:pujangga_pos/core/database/app_database.dart';
import 'package:pujangga_pos/core/errors/app_exception.dart';
import 'package:pujangga_pos/features/pengaturan/data/services/app_backup_payload_builder.dart';
import 'package:pujangga_pos/features/pengaturan/data/services/app_backup_service.dart';
import 'package:pujangga_pos/features/pengaturan/data/services/app_restore_service.dart';
import 'package:pujangga_pos/features/pengaturan/domain/entities/app_backup_restore_candidate.dart';
import 'package:pujangga_pos/features/riwayat/data/datasources/riwayat_local_data_source.dart';
import 'package:pujangga_pos/features/transaksi/data/datasources/transaction_local_data_source.dart';
import 'package:pujangga_pos/features/transaksi/domain/entities/transaksi_cart_item.dart';
import 'package:pujangga_pos/features/transaksi/domain/entities/transaksi_item.dart';
import 'package:pujangga_pos/features/transaksi/domain/entities/transaksi_submit_request.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

typedef Tables = Map<String, List<Map<String, Object?>>>;

void main() {
  late Directory temporary;
  late AppDatabase database;
  late Database db;
  late AppRestoreService service;
  late Tables tables;
  const stamp = '2026-07-12T10:00:00.000';

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  Future<Tables> snapshot() async => {
    for (final table in AppBackupService.backupTables)
      table: [
        for (final row in await db.query(table, orderBy: 'id')) {...row},
      ],
  };

  Future<File> writeBackup({int? schema}) async {
    final payload = const AppBackupPayloadBuilder().build(
      generatedAt: DateTime.utc(2026, 7, 12),
      tables: tables,
    );
    if (schema != null) {
      (payload['database'] as Map)['schema_version'] = schema;
      payload['format_version'] = 2;
      if (schema < 16) {
        for (final row in tables['sales_transactions']!) {
          row.remove('checkout_id');
        }
      }
      if (schema < 15) {
        (payload['tables'] as Map).remove('employee_compensation_periods');
        (payload['table_counts'] as Map).remove(
          'employee_compensation_periods',
        );
      }
      if (schema < 14) {
        for (final row in tables['employees']!) {
          row.remove('commission_scope');
        }
        for (final row in tables['sales_transactions']!) {
          row.remove('commission_scope_snapshot');
        }
      }
      if (schema < 13) {
        for (final row in tables['sales_transactions']!) {
          for (final key in [
            'employee_id',
            'employee_name_snapshot',
            'compensation_type_snapshot',
            'commission_percent_snapshot',
            'monthly_salary_snapshot',
            'commission_amount',
          ]) {
            row.remove(key);
          }
        }
        for (final row in tables['expenses']!) {
          for (final key in [
            'source_type',
            'source_id',
            'employee_id',
            'period_key',
          ]) {
            row.remove(key);
          }
        }
        (payload['tables'] as Map).remove('employees');
        (payload['table_counts'] as Map).remove('employees');
      }
      // The builder copies rows; rebuild the modified legacy rows.
      final payloadTables = payload['tables'] as Map;
      for (final table in tables.keys.where(payloadTables.containsKey)) {
        payloadTables[table] = tables[table];
      }
    }
    return File(path.join(temporary.path, 'backup.json'))
      ..writeAsStringSync(jsonEncode(payload));
  }

  AppBackupRestoreCandidate candidate() => AppBackupRestoreCandidate(
    filePath: 'synthetic.json',
    fileName: 'synthetic.json',
    generatedAt: DateTime(2026, 7, 12),
    schemaVersion: 16,
    tables: tables,
    recordCounts: {
      for (final entry in tables.entries) entry.key: entry.value.length,
    },
  );

  setUp(() async {
    temporary = await Directory.systemTemp.createTemp('pujangga_restore_49_');
    database = _PathDatabase(path.join(temporary.path, 'disposable.sqlite'));
    expect(path.dirname(await database.databasePath()), temporary.path);
    db = await database.database();
    expect(
      (await db.rawQuery('PRAGMA database_list')).single['file'],
      await database.databasePath(),
    );
    service = AppRestoreService(
      database: database,
      logger: Logger('restore-49'),
    );
    final employeeId = await db.insert('employees', {
      'name': 'Karyawan sintetis',
      'compensation_type': 'monthly_salary',
      'monthly_salary': 1000000,
      'effective_from': stamp,
      'created_at': stamp,
      'updated_at': stamp,
    });
    await db.insert('employee_compensation_periods', {
      'employee_id': employeeId,
      'employee_name': 'Karyawan sintetis',
      'is_active': 1,
      'compensation_type': 'monthly_salary',
      'monthly_salary': 1000000,
      'valid_from': stamp,
    });
    await db.insert('expenses', {
      'amount': 1000,
      'category': 'Operasional',
      'expense_date': stamp,
      'created_at': stamp,
      'updated_at': stamp,
    });
    await db.insert('capital_history', {'amount': 100000, 'created_at': stamp});
    final itemId = await db.insert('items', {
      'name': 'Barang sintetis',
      'item_type': 'product',
      'sale_price': 10000,
      'stock_qty': 10,
      'created_at': stamp,
      'updated_at': stamp,
    });
    await TransactionLocalDataSource(database: database).saveTransaction(
      TransaksiSubmitRequest(
        items: [
          TransaksiCartItem(
            item: TransaksiItem(
              id: '$itemId',
              name: 'Barang sintetis',
              category: '',
              itemType: 'barang',
              sellingPrice: 10000,
              isActive: true,
              stockQuantity: 10,
            ),
            quantity: 2,
            itemDiscountAmount: 1000,
          ),
        ],
        orderDiscountAmount: 500,
        taxAmount: 100,
        paymentMethod: 'tunai',
        cashPaidAmount: 20000,
      ),
    );
    tables = await snapshot();
  });

  tearDown(() async {
    await database.reset();
    await temporary.delete(recursive: true);
  });

  final invalid = <String, void Function(Tables)>{
    for (final date in [
      'bukan-tanggal',
      '',
      '2026-02-30T12:00:00',
      '2025-02-29',
      '2026-13-01',
      '2026-07-12T24:00:00',
      '2026-07-12T10:60:00',
      '2026-07-12T10:00:60',
      '2026-07-12T10:00:00+24:00',
    ])
      'transaction date $date': (t) =>
          t['sales_transactions']!.single['transaction_date'] = date,
    'expense date': (t) => t['expenses']!.single['expense_date'] = 'rusak',
    'created date': (t) => t['items']!.single['created_at'] = 'rusak',
    'updated date': (t) => t['app_settings']!.single['updated_at'] = 'rusak',
    'effective date': (t) => t['employees']!.single['effective_from'] = 'rusak',
    'period start': (t) =>
        t['employee_compensation_periods']!.single['valid_from'] = 'rusak',
    'period end': (t) =>
        t['employee_compensation_periods']!.single['valid_until'] = 'rusak',
    'period order': (t) =>
        t['employee_compensation_periods']!.single['valid_until'] =
            '2026-01-01',
    'payment enum': (t) =>
        t['sales_transactions']!.single['payment_method'] = 'unknown',
    'status enum': (t) => t['sales_transactions']!.single['status'] = 'unknown',
    'snapshot enum': (t) =>
        t['sales_transaction_items']!.single['item_type_snapshot'] = 'unknown',
    'compensation enum': (t) =>
        t['employees']!.single['compensation_type'] = 'unknown',
    'scope enum': (t) =>
        t['sales_transactions']!.single['commission_scope_snapshot'] =
            'unknown',
    'movement enum': (t) =>
        t['stock_movements']!.single['movement_type'] = 'unknown',
    'reference enum': (t) =>
        t['stock_movements']!.single['reference_type'] = 'unknown',
    'source enum': (t) => t['expenses']!.single['source_type'] = 'unknown',
    'boolean': (t) => t['app_settings']!.single['stock_allow_negative'] = 2,
    'zero quantity': (t) => t['sales_transaction_items']!.single['qty'] = 0,
    'negative quantity': (t) =>
        t['sales_transaction_items']!.single['qty'] = -1,
    'negative price': (t) => t['items']!.single['sale_price'] = -1,
    'negative total': (t) =>
        t['sales_transactions']!.single['total_amount'] = -1,
    'negative discount': (t) =>
        t['sales_transaction_items']!.single['line_discount_amount'] = -1,
    'excess discount': (t) =>
        t['sales_transactions']!.single['discount_amount'] = 20001,
    'zero expense': (t) => t['expenses']!.single['amount'] = 0,
    'zero salary': (t) => t['employees']!.single['monthly_salary'] = 0,
    'commission range': (t) =>
        t['employees']!.single['commission_percent'] = 101,
    'line subtotal': (t) =>
        t['sales_transaction_items']!.single['line_subtotal'] = 19999,
    'line total': (t) =>
        t['sales_transaction_items']!.single['line_total'] = 19999,
    'header subtotal': (t) =>
        t['sales_transactions']!.single['subtotal_amount'] = 19999,
    'header total': (t) =>
        t['sales_transactions']!.single['total_amount'] = 19000,
    'missing details': (t) => t['sales_transaction_items']!.clear(),
    'orphan detail': (t) =>
        t['sales_transaction_items']!.single['transaction_id'] = 999,
    'missing item': (t) =>
        t['sales_transaction_items']!.single['item_id'] = 999,
    'insufficient cash': (t) =>
        t['sales_transactions']!.single['paid_amount'] = 1,
    'change amount': (t) =>
        t['sales_transactions']!.single['change_amount'] = 0,
    'stock balance': (t) => t['stock_movements']!.single['qty_after'] = 99,
  };

  for (final entry in invalid.entries) {
    test(
      'rejects ${entry.key} at inspection and direct restore, preserving all data',
      () async {
        final before = await snapshot();
        final sequence = await db.query('sqlite_sequence', orderBy: 'name');
        entry.value(tables);
        final file = await writeBackup();
        final rejectsBackup = throwsA(
          isA<AppException>().having((e) => e.code, 'code', 'backup_invalid'),
        );
        await expectLater(service.inspectBackupFile(file.path), rejectsBackup);
        await expectLater(service.restoreBackup(candidate()), rejectsBackup);
        expect(await snapshot(), before);
        expect(await db.query('sqlite_sequence', orderBy: 'name'), sequence);
      },
    );
  }

  for (final date in [
    '2024-02-29',
    '2026-07-12T10:00:00.123456',
    '2026-07-12T10:00:00.000Z',
    '2026-07-12T10:00:00+07:00',
  ]) {
    test('restores valid date $date and history remains readable', () async {
      tables['sales_transactions']!.single['transaction_date'] = date;
      final file = await writeBackup();
      final inspected = await service.inspectBackupFile(file.path);
      await db.update('items', {'name': 'Data aktif berbeda'});
      await service.restoreBackup(inspected);
      expect(await snapshot(), tables);
      final history = await RiwayatLocalDataSource(database: database)
          .getTransactions();
      expect(history, hasLength(1));
      expect(await db.rawQuery('PRAGMA foreign_key_check'), isEmpty);
    });
  }

  for (final schema in [12, 13, 14, 15]) {
    test('migrates and restores supported schema $schema', () async {
      final file = await writeBackup(schema: schema);
      final inspected = await service.inspectBackupFile(file.path);
      await service.restoreBackup(inspected);
      expect(
        (await snapshot())['sales_transactions'],
        inspected.tables['sales_transactions'],
      );
      expect(
        await RiwayatLocalDataSource(database: database).getTransactions(),
        hasLength(1),
      );
      expect(await db.rawQuery('PRAGMA foreign_key_check'), isEmpty);
    });
  }

  test('revalidates a candidate modified after inspection', () async {
    final file = await writeBackup();
    final inspected = await service.inspectBackupFile(file.path);
    final before = await snapshot();
    inspected.tables['sales_transactions']!.single['transaction_date'] =
        'bukan-tanggal';
    await expectLater(
      service.restoreBackup(inspected),
      throwsA(isA<AppException>()),
    );
    expect(await snapshot(), before);
  });

  test('keeps atomic rollback for SQLite constraints', () async {
    final before = await snapshot();
    tables['items']!.add({
      ...tables['items']!.single,
    }); // Duplicate primary key.
    await expectLater(
      service.restoreBackup(candidate()),
      throwsA(isA<DatabaseException>()),
    );
    expect(await snapshot(), before);
  });

  test(
    'accepts voided sales, noncash payment and floating point totals',
    () async {
      await RiwayatLocalDataSource(database: database).voidTransaction(
        tables['sales_transactions']!.single['invoice_no'] as String,
      );
      tables = await snapshot();
      final header = tables['sales_transactions']!.single;
      final line = tables['sales_transaction_items']!.single;
      header.addAll({
        'subtotal_amount': 0.3,
        'discount_amount': 0,
        'tax_amount': 0,
        'total_amount': 0.3,
        'payment_method': 'qris',
        'paid_amount': 0,
        'change_amount': 0,
      });
      line.addAll({
        'price_snapshot': 0.1,
        'qty': 3,
        'line_subtotal': 0.1 * 3,
        'line_discount_amount': 0,
        'line_total': 0.1 * 3,
      });
      await service.restoreBackup(candidate());
      expect(await snapshot(), tables);
    },
  );
}

class _PathDatabase extends AppDatabase {
  _PathDatabase(this.filePath);
  final String filePath;
  @override
  Future<String> databasePath() async => filePath;
}
