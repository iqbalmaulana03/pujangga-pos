import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pujangga_pos/core/services/app_startup_service.dart';
import 'package:logging/logging.dart';
import 'package:pujangga_pos/core/database/app_database.dart';
import 'package:pujangga_pos/features/karyawan/data/repositories/employee_repository.dart';
import 'package:pujangga_pos/features/laporan/data/datasources/report_local_data_source.dart';
import 'package:pujangga_pos/features/laporan/domain/entities/report_period.dart';
import 'package:pujangga_pos/features/pengaturan/data/services/app_backup_payload_builder.dart';
import 'package:pujangga_pos/features/pengaturan/data/services/app_backup_service.dart';
import 'package:pujangga_pos/features/pengaturan/data/services/app_restore_service.dart';
import 'package:pujangga_pos/features/pengeluaran/data/repositories/expense_repository.dart';
import 'package:pujangga_pos/features/pengeluaran/data/services/employee_expense_service.dart';
import 'package:pujangga_pos/features/pengeluaran/presentation/pages/tambah_pengeluaran_page.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Directory temporary;
  late AppDatabase database;
  late DateTime clock;
  late EmployeeRepository employees;
  late EmployeeExpenseService salaries;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });
  setUp(() async {
    temporary = await Directory.systemTemp.createTemp(
      'pujangga_salary_lifecycle_',
    );
    await databaseFactory.setDatabasesPath(temporary.path);
    database = AppDatabase();
    expect(await database.databasePath(), startsWith(temporary.path));
    clock = DateTime(2026, 1, 1, 9);
    employees = EmployeeRepository(database: database, now: () => clock);
    salaries = EmployeeExpenseService(database: database, now: () => clock);
  });
  tearDown(() async {
    await database.reset();
    await temporary.delete(recursive: true);
  });

  Future<List<Map<String, Object?>>> runLifecycle(bool readBeforeEdit) async {
    int? id;
    for (final (date, active, type, amount) in [
      (DateTime(2026, 1, 1, 9), true, 'monthly_salary', 3000000.0),
      (DateTime(2026, 2, 5, 9), true, 'monthly_salary', 4000000.0),
      (DateTime(2026, 3, 8, 9), false, 'monthly_salary', 4000000.0),
      (DateTime(2026, 5, 3, 9), true, 'monthly_salary', 4000000.0),
      (DateTime(2026, 6, 5, 9), true, 'commission', 0.0),
      (DateTime(2026, 8, 2, 9), true, 'monthly_salary', 5000000.0),
    ]) {
      clock = date;
      if (readBeforeEdit && id != null) {
        await salaries.ensureMonthlySalaries(DateTime(2026), clock);
      }
      await employees.save(
        id: id,
        name: 'Karyawan sintetis',
        isActive: active,
        compensationType: type,
        monthlySalary: type == 'monthly_salary' ? amount : null,
        commissionPercent: type == 'commission' ? 10 : null,
        effectiveFrom: DateTime(2026, 1, 1, 9),
      );
      id ??= (await employees.getEmployees()).single.id;
    }
    clock = DateTime(2026, 9, 30, 23);
    await salaries.ensureMonthlySalaries(DateTime(2026), DateTime(2026, 10));
    return (await database.database()).query(
      'expenses',
      columns: ['period_key', 'amount', 'expense_date'],
      orderBy: 'period_key',
    );
  }

  for (final readBeforeEdit in [false, true]) {
    test(
      'salary lifecycle remains stable with early report reads: $readBeforeEdit',
      () async {
        final rows = await runLifecycle(readBeforeEdit);
        expect(
          {for (final row in rows) row['period_key']: row['amount']},
          {
            '2026-01': 3000000.0,
            '2026-02': 3000000.0,
            '2026-03': 4000000.0,
            '2026-05': 4000000.0,
            '2026-06': 4000000.0,
            '2026-08': 5000000.0,
            '2026-09': 5000000.0,
          },
        );
        final before = await (await database.database()).query(
          'expenses',
          orderBy: 'period_key',
        );
        await salaries.ensureMonthlySalaries(
          DateTime(2026),
          DateTime(2026, 10),
        );
        expect(
          await (await database.database()).query(
            'expenses',
            orderBy: 'period_key',
          ),
          before,
        );
        for (final month in [1, 2, 3, 4, 5, 6, 7, 8, 9]) {
          final report = await ReportLocalDataSource(database: database)
              .getSalesReportSnapshot(
                period: ReportPeriod.bulanan,
                reference: DateTime(2026, month, 15),
              );
          final expected =
              {
                1: 3000000,
                2: 3000000,
                3: 4000000,
                5: 4000000,
                6: 4000000,
                8: 5000000,
                9: 5000000,
              }[month] ??
              0;
          expect(report.totalExpenses, expected);
          expect(report.netProfit, -expected);
        }
      },
    );
  }

  test(
    'backup restore and reopen preserve compensation periods and future accruals',
    () async {
      await runLifecycle(false);
      final db = await database.database();
      final history = await db.query(
        'employee_compensation_periods',
        orderBy: 'id',
      );
      final tables = <String, List<Map<String, Object?>>>{};
      for (final table in AppBackupService.backupTables) {
        tables[table] = (await db.query(
          table,
        )).map((r) => Map<String, Object?>.from(r)).toList();
      }
      final file = File('${temporary.path}/backup.json');
      await file.writeAsString(
        jsonEncode(
          const AppBackupPayloadBuilder().build(
            generatedAt: clock,
            tables: tables,
          ),
        ),
      );
      final restore = AppRestoreService(
        database: database,
        logger: Logger('isolated'),
      );
      final candidate = await restore.inspectBackupFile(file.path);
      await restore.restoreBackup(candidate);
      expect(
        await db.query('employee_compensation_periods', orderBy: 'id'),
        history,
      );
      await db.close();
      database = AppDatabase();
      expect(await database.databasePath(), startsWith(temporary.path));
      salaries = EmployeeExpenseService(
        database: database,
        now: () => DateTime(2026, 10, 2),
      );
      await salaries.ensureMonthlySalaries(
        DateTime(2026, 10),
        DateTime(2026, 11),
      );
      final october = await (await database.database()).query(
        'expenses',
        where: 'period_key = ?',
        whereArgs: ['2026-10'],
      );
      expect(october.single['amount'], 5000000);
      expect(
        await (await database.database()).rawQuery('PRAGMA foreign_key_check'),
        isEmpty,
      );
    },
  );

  test(
    'manual salary uses the historical amount and accrual date once',
    () async {
      await employees.save(
        name: 'Gaji',
        isActive: true,
        compensationType: 'monthly_salary',
        monthlySalary: 3000000,
        effectiveFrom: clock,
      );
      final employee = (await employees.getEmployees()).single;
      clock = DateTime(2026, 2, 5, 9);
      await employees.save(
        id: employee.id,
        name: employee.name,
        isActive: true,
        compensationType: 'monthly_salary',
        monthlySalary: 4000000,
        effectiveFrom: employee.effectiveFrom,
      );
      final expenses = ExpenseRepository(database: database);
      expect(
        await expenses.salaryForMonth(employee.id, DateTime(2026, 2, 10)),
        3000000,
      );
      await expenses.addExpense(
        amount: 4000000,
        category: 'Gaji Karyawan',
        date: DateTime(2026, 2, 10),
        employeeId: employee.id,
      );
      clock = DateTime(2026, 2, 20);
      await salaries.ensureMonthlySalaries(
        DateTime(2026, 2),
        DateTime(2026, 3),
      );
      final rows = await (await database.database()).query('expenses');
      expect(rows, hasLength(1));
      expect(rows.single['amount'], 3000000);
      expect(rows.single['expense_date'], DateTime(2026, 2).toIso8601String());
      await expectLater(
        expenses.addExpense(
          amount: 1,
          category: 'Gaji Karyawan',
          date: DateTime(2026, 2, 20),
          employeeId: employee.id,
        ),
        throwsStateError,
      );
    },
  );

  testWidgets(
    'salary form loads actual period amount from isolated SQLite after master edit',
    (tester) async {
      final current = DateTime.now();
      clock = DateTime(current.year, current.month);
      await tester.runAsync(() async {
        await employees.save(
          name: 'Gaji UI',
          isActive: true,
          compensationType: 'monthly_salary',
          monthlySalary: 30000,
          effectiveFrom: clock,
        );
        final employee = (await employees.getEmployees()).single;
        clock = current;
        await employees.save(
          id: employee.id,
          name: employee.name,
          isActive: true,
          compensationType: 'monthly_salary',
          monthlySalary: 40000,
          effectiveFrom: employee.effectiveFrom,
        );
      });
      tester.view.physicalSize = const Size(600, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [appDatabaseProvider.overrideWithValue(database)],
          child: const MaterialApp(home: TambahPengeluaranPage()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Operasional'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Gaji Karyawan').last);
      await tester.pump();
      for (
        var i = 0;
        i < 100 && find.byType(DropdownButtonFormField<int>).evaluate().isEmpty;
        i++
      ) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump();
      }
      await tester.tap(find.byType(DropdownButtonFormField<int>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Gaji UI').last);
      await tester.pump();
      String amount() => tester
          .widgetList<TextField>(find.byType(TextField))
          .singleWhere((f) => f.readOnly)
          .controller!
          .text;
      for (var i = 0; i < 100 && amount().isEmpty; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump();
      }
      expect(amount(), '30000');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
