import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:pujangga_pos/core/database/app_database.dart';
import 'package:pujangga_pos/features/karyawan/data/repositories/employee_repository.dart';
import 'package:pujangga_pos/features/laporan/data/datasources/report_local_data_source.dart';
import 'package:pujangga_pos/features/laporan/domain/entities/report_period.dart';
import 'package:pujangga_pos/features/pengaturan/data/services/app_backup_service.dart';
import 'package:pujangga_pos/features/pengaturan/data/services/app_backup_payload_builder.dart';
import 'package:pujangga_pos/features/pengaturan/data/services/app_restore_service.dart';
import 'package:pujangga_pos/features/transaksi/data/datasources/transaction_local_data_source.dart';
import 'package:pujangga_pos/features/transaksi/domain/entities/transaksi_cart_item.dart';
import 'package:pujangga_pos/features/transaksi/domain/entities/transaksi_item.dart';
import 'package:pujangga_pos/features/transaksi/domain/entities/transaksi_submit_request.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Directory temporary;
  late AppDatabase database;
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });
  setUp(() async {
    temporary = await Directory.systemTemp.createTemp('pujangga_scope_');
    await databaseFactory.setDatabasesPath(temporary.path);
    database = AppDatabase();
    expect(await database.databasePath(), startsWith(temporary.path));
  });
  tearDown(() async {
    await database.reset();
    await temporary.delete(recursive: true);
  });

  Future<TransaksiCartItem> item(
    String type,
    double? cost, {
    double discount = 0,
  }) async {
    final db = await database.database();
    final stamp = DateTime.now().toIso8601String();
    final id = await db.insert('items', {
      'name': type,
      'item_type': type,
      'sale_price': 100000,
      'harga_modal': type == 'product' ? cost : null,
      'biaya_dasar': type == 'service' ? cost : null,
      'stock_qty': 100,
      'created_at': stamp,
      'updated_at': stamp,
    });
    return TransaksiCartItem(
      item: TransaksiItem(
        id: '$id',
        name: type,
        category: '',
        itemType: type == 'service' ? 'jasa' : 'barang',
        sellingPrice: 100000,
        isActive: true,
      ),
      quantity: 1,
      itemDiscountAmount: discount,
    );
  }

  Future<int> employee(String scope) async {
    await EmployeeRepository(database: database).save(
      name: 'Karyawan',
      isActive: true,
      compensationType: 'commission',
      commissionPercent: 10,
      commissionScope: scope,
      effectiveFrom: DateTime.now(),
    );
    return (await EmployeeRepository(
      database: database,
    ).getEmployees()).single.id;
  }

  for (final (scope, expected) in [
    ('all', 15000.0),
    ('service', 6000.0),
    ('product', 9000.0),
  ]) {
    test(
      'mixed basket $scope allocates discounts before tax and deducts commission once',
      () async {
        final lines = [
          await item('service', 0, discount: 40000),
          await item('product', 20000, discount: 10000),
        ];
        final source = TransactionLocalDataSource(database: database);
        final receipt = await source.saveTransaction(
          TransaksiSubmitRequest(
            items: lines,
            employeeId: await employee(scope),
            orderDiscountAmount: 0,
            taxAmount: 15000,
            paymentMethod: 'tunai',
            cashPaidAmount: 200000,
          ),
        );
        // 60k service + 90k product, no tax in commission base.
        expect(receipt.commissionAmount, expected);
        expect(receipt.commissionScope, scope);
        final home = await ReportLocalDataSource(
          database: database,
        ).getDashboardSummary();
        expect(home.marginToday, 130000);
        expect(home.marginTodayIsComplete, isTrue);
        expect(home.commissionExpensesToday, expected);
        expect(home.netProfitToday, 130000 - expected);
        final report = await ReportLocalDataSource(
          database: database,
        ).getSalesReportSnapshot(period: ReportPeriod.harian);
        expect(report.commissionExpenses, expected);
        expect(report.netProfit, home.netProfitToday);
        final second = await source.saveTransaction(
          TransaksiSubmitRequest(
            items: lines,
            employeeId: (await EmployeeRepository(
              database: database,
            ).getEmployees()).single.id,
            orderDiscountAmount: 30000,
            taxAmount: 12000,
            paymentMethod: 'tunai',
            cashPaidAmount: 200000,
          ),
        );
        expect(second.commissionAmount, closeTo(expected * 0.8, 0.00001));
      },
    );
  }

  test(
    'cost and commission snapshots survive master edits; unknown service cost remains unknown',
    () async {
      final zeroCost = await item('service', 0);
      final unknownCost = await item('service', null);
      final actualCost = await item('service', 25000);
      final id = await employee('service');
      final source = TransactionLocalDataSource(database: database);
      final receipt = await source.saveTransaction(
        TransaksiSubmitRequest(
          items: [zeroCost, actualCost, unknownCost],
          employeeId: id,
          orderDiscountAmount: 0,
          taxAmount: 0,
          paymentMethod: 'tunai',
          cashPaidAmount: 300000,
        ),
      );
      final db = await database.database();
      final before = await db.query('sales_transaction_items', orderBy: 'id');
      expect(before.map((r) => r['cost_price_snapshot']), [0.0, 25000.0, null]);
      await db.update('items', {'biaya_dasar': 50000});
      await EmployeeRepository(database: database).save(
        id: id,
        name: 'Nama baru',
        isActive: true,
        compensationType: 'commission',
        commissionPercent: 50,
        commissionScope: 'product',
        effectiveFrom: DateTime.now(),
      );
      final historical = (await source.getReceiptByInvoice(
        receipt.invoiceNumber,
      ))!;
      expect(historical.commissionScope, 'service');
      expect(historical.commissionPercent, 10);
      expect(historical.commissionAmount, 30000);
      expect(await db.query('sales_transaction_items', orderBy: 'id'), before);
      final home = await ReportLocalDataSource(
        database: database,
      ).getDashboardSummary();
      expect(home.marginTodayIsComplete, isFalse);
      expect(home.totalExpensesToday, 30000);
    },
  );

  test(
    'version 13 migration preserves historical commission and unknown cost',
    () async {
      final db = await database.database();
      final line = await item('service', null);
      final source = TransactionLocalDataSource(database: database);
      final receipt = await source.saveTransaction(
        TransaksiSubmitRequest(
          items: [line],
          employeeId: await employee('all'),
          orderDiscountAmount: 0,
          taxAmount: 0,
          paymentMethod: 'tunai',
          cashPaidAmount: 100000,
        ),
      );
      await db.execute('ALTER TABLE employees DROP COLUMN commission_scope');
      await db.execute(
        'ALTER TABLE sales_transactions DROP COLUMN commission_scope_snapshot',
      );
      await db.setVersion(13);
      await db.close();
      database = AppDatabase();
      final upgraded = await database.database();
      expect(await upgraded.getVersion(), 14);
      expect(
        (await EmployeeRepository(
          database: database,
        ).getEmployees()).single.commissionScope,
        'all',
      );
      expect(
        (await TransactionLocalDataSource(
          database: database,
        ).getReceiptByInvoice(receipt.invoiceNumber))!.commissionAmount,
        10000,
      );
      expect(
        (await upgraded.query(
          'sales_transaction_items',
        )).single['cost_price_snapshot'],
        isNull,
      );
    },
  );

  for (final version in [12, 13, 14]) {
    test(
      'backup schema $version preserves employees and snapshot on restore',
      () async {
        final db = await database.database();
        final line = await item('service', 0);
        await TransactionLocalDataSource(database: database).saveTransaction(
          TransaksiSubmitRequest(
            items: [line],
            employeeId: await employee('service'),
            orderDiscountAmount: 0,
            taxAmount: 0,
            paymentMethod: 'tunai',
            cashPaidAmount: 100000,
          ),
        );
        final tables = <String, List<Map<String, Object?>>>{};
        for (final table in AppBackupService.backupTables) {
          tables[table] = (await db.query(
            table,
          )).map((r) => Map<String, Object?>.from(r)).toList();
        }
        if (version < 14) {
          for (final row in tables['employees']!) {
            row.remove('commission_scope');
          }
          for (final row in tables['sales_transactions']!) {
            row.remove('commission_scope_snapshot');
          }
        }
        if (version < 13) {
          tables.remove('employees');
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
        }
        final payload = const AppBackupPayloadBuilder().build(
          generatedAt: DateTime.now(),
          tables: tables,
        );
        (payload['database'] as Map)['schema_version'] = version;
        final file = File('${temporary.path}/backup.json');
        await file.writeAsString(jsonEncode(payload));
        final restore = AppRestoreService(
          database: database,
          logger: Logger('isolated'),
        );
        final candidate = await restore.inspectBackupFile(file.path);
        await restore.restoreBackup(candidate);
        final employees = await EmployeeRepository(
          database: database,
        ).getEmployees();
        expect(employees, hasLength(version == 12 ? 0 : 1));
        if (version > 12) {
          expect(
            employees.single.commissionScope,
            version == 14 ? 'service' : 'all',
          );
          expect(
            (await db.query('sales_transactions')).single['commission_amount'],
            10000,
          );
        }
        expect(
          (await db.query(
            'sales_transaction_items',
          )).single['cost_price_snapshot'],
          0,
        );
      },
    );
  }
}
