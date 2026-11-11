import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pujangga_pos/core/database/app_database.dart';
import 'package:pujangga_pos/core/services/app_startup_service.dart';
import 'package:pujangga_pos/features/katalog/presentation/pages/item_form_page.dart';
import 'package:pujangga_pos/features/karyawan/data/repositories/employee_repository.dart';
import 'package:pujangga_pos/features/laporan/data/datasources/report_local_data_source.dart';
import 'package:pujangga_pos/features/laporan/data/repositories/report_repository_impl.dart';
import 'package:pujangga_pos/features/laporan/domain/entities/report_period.dart';
import 'package:pujangga_pos/features/laporan/presentation/controllers/laporan_controller.dart';
import 'package:pujangga_pos/features/pengeluaran/data/repositories/expense_repository.dart';
import 'package:pujangga_pos/features/pengeluaran/data/services/employee_expense_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Directory temporary;
  late AppDatabase database;
  late DateTime clock;
  late ReportLocalDataSource source;
  late ReportRepositoryImpl reports;
  late EmployeeExpenseService salaries;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });
  setUp(() async {
    temporary = await Directory.systemTemp.createTemp('pujangga_salary_reads_');
    await databaseFactory.setDatabasesPath(temporary.path);
    database = AppDatabase();
    // AppDatabase resolves the FFI factory's path, with no production service.
    expect(File(await database.databasePath()).parent.path, temporary.path);
    clock = DateTime(2026, 5, 12, 10);
    source = ReportLocalDataSource(database: database);
    reports = ReportRepositoryImpl(localDataSource: source, now: () => clock);
    salaries = EmployeeExpenseService(database: database, now: () => clock);
    final db = await database.database();
    await db.insert('capital_history', {
      'amount': 10000,
      'created_at': DateTime(2026).toIso8601String(),
    });
    // Legacy/restore data: compensation history and salary expenses are absent.
    await db.insert('employees', {
      'name': 'Sintetis',
      'is_active': 1,
      'compensation_type': 'monthly_salary',
      'monthly_salary': 1000,
      'effective_from': DateTime(2026, 1, 15).toIso8601String(),
      'created_at': DateTime(2026, 1, 15).toIso8601String(),
      'updated_at': DateTime(2026, 1, 15).toIso8601String(),
    });
  });
  tearDown(() async {
    await database.reset();
    await temporary.delete(recursive: true);
  });

  for (final first in [
    'capital',
    'annual',
    'dashboard',
    'employee',
    'expenses',
  ]) {
    test(
      '$first first yields the same capital and stock affordability',
      () async {
        final db = await database.database();
        expect(await db.query('expenses'), isEmpty);
        switch (first) {
          case 'capital':
            await reports.getCapitalMetrics();
          case 'annual':
            await reports.getSalesReportSnapshot(
              period: ReportPeriod.tahunan,
              reference: clock,
            );
          case 'dashboard':
            await reports.getDashboardSummary(reference: clock);
          case 'employee':
            final employees = await reports.getEmployeeReport(
              start: DateTime(2026),
              end: DateTime(2027),
            );
            expect(employees.single.expense, 5000);
          case 'expenses':
            final expenses = await ExpenseRepository(
              database: database,
              now: () => clock,
            ).getExpenses(DateTime(2026, 1), DateTime(2026, 2));
            expect(expenses.single['amount'], 1000);
        }
        final before = await reports.getCapitalMetrics();
        expect(before.currentCash, 5000);
        final rows = await db.query('expenses', orderBy: 'period_key');
        expect(rows.map((r) => r['period_key']), [
          '2026-01',
          '2026-02',
          '2026-03',
          '2026-04',
          '2026-05',
        ]);
        expect(
          rows.first['expense_date'],
          DateTime(2026, 1, 15).toIso8601String(),
        );
        final annual = await reports.getSalesReportSnapshot(
          period: ReportPeriod.tahunan,
          reference: clock,
        );
        expect(annual.totalExpenses, 5000);
        await reports.getSalesReportSnapshot(
          period: ReportPeriod.bulanan,
          reference: DateTime(2026, 1),
        );
        await reports.getDashboardSummary(reference: clock);
        await Future.wait(List.generate(3, (_) => salaries.reconcile()));
        final after = await reports.getCapitalMetrics();
        expect(after.currentCash, before.currentCash);
        expect(await db.query('expenses', orderBy: 'period_key'), rows);
      },
    );
  }

  testWidgets(
    'stock form rejects unaffordable stock before and after old report reads',
    (tester) async {
      tester.view.physicalSize = const Size(600, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      Future<void> attemptStockSave() async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appDatabaseProvider.overrideWithValue(database),
              reportRepositoryProvider.overrideWithValue(reports),
            ],
            child: const MaterialApp(home: ItemFormPage()),
          ),
        );
        await tester.pumpAndSettle();
        Finder field(String hint) => find.byWidgetPredicate(
          (w) => w is TextField && w.decoration?.hintText == hint,
        );
        await tester.enterText(field('e.g. Kopi Susu Aren'), 'Stok sintetis');
        await tester.enterText(field('Pilih atau ketik kategori'), 'Uji');
        final prices = field('0');
        await tester.ensureVisible(prices.at(0));
        await tester.enterText(prices.at(0), '8000');
        await tester.ensureVisible(prices.at(1));
        await tester.enterText(prices.at(1), '6000');
        final stock = find.byWidgetPredicate(
          (w) => w is TextField && w.textAlign == TextAlign.center,
        );
        await tester.ensureVisible(stock);
        await tester.enterText(stock, '1');
        await tester.tap(find.text('Simpan Barang'));
        for (
          var i = 0;
          i < 100 &&
              find.textContaining('Stok gagal disimpan.').evaluate().isEmpty;
          i++
        ) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)),
          );
          await tester.pump();
        }
        expect(find.textContaining('Stok gagal disimpan.'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.runAsync(() async {
          expect(await (await database.database()).query('items'), isEmpty);
        });
      }

      await attemptStockSave();
      await tester.runAsync(
        () => reports.getSalesReportSnapshot(
          period: ReportPeriod.bulanan,
          reference: DateTime(2026, 1),
        ),
      );
      await attemptStockSave();
    },
  );

  test('data source reads never materialize salaries', () async {
    await source.getDashboardSummary(reference: clock);
    await source.getSalesReportSnapshot(
      period: ReportPeriod.tahunan,
      reference: clock,
    );
    await source.getEmployeeReport(start: DateTime(2026), end: DateTime(2027));
    await source.getCapitalMetrics();
    expect(await (await database.database()).query('expenses'), isEmpty);
  });

  test(
    'future reports cannot accrue future or not-yet-effective salaries',
    () async {
      final db = await database.database();
      final stamp = DateTime(2026, 5, 20).toIso8601String();
      await db.insert('employees', {
        'name': 'Belum efektif',
        'is_active': 1,
        'compensation_type': 'monthly_salary',
        'monthly_salary': 2000,
        'effective_from': stamp,
        'created_at': stamp,
        'updated_at': stamp,
      });
      await reports.getSalesReportSnapshot(
        period: ReportPeriod.tahunan,
        reference: DateTime(2027),
      );
      expect(await db.query('expenses'), hasLength(5));
      clock = DateTime(2026, 5, 20);
      expect((await reports.getCapitalMetrics()).currentCash, 3000);
      expect(await db.query('expenses'), hasLength(6));
      clock = DateTime(2026, 6);
      expect((await reports.getCapitalMetrics()).currentCash, 0);
      expect(await db.query('expenses'), hasLength(8));
    },
  );

  test(
    'historical liabilities survive salary edits and deactivation',
    () async {
      final employee = (await EmployeeRepository(
        database: database,
      ).getEmployees()).single;
      final employees = EmployeeRepository(
        database: database,
        now: () => clock,
      );
      clock = DateTime(2026, 2, 10);
      await employees.save(
        id: employee.id,
        name: employee.name,
        isActive: true,
        compensationType: 'monthly_salary',
        monthlySalary: 2000,
        effectiveFrom: employee.effectiveFrom,
      );
      clock = DateTime(2026, 3, 5);
      await employees.save(
        id: employee.id,
        name: employee.name,
        isActive: false,
        compensationType: 'monthly_salary',
        monthlySalary: 2000,
        effectiveFrom: employee.effectiveFrom,
      );
      clock = DateTime(2026, 5, 12);
      expect((await reports.getCapitalMetrics()).currentCash, 6000);
      final rows = await (await database.database()).query(
        'expenses',
        orderBy: 'period_key',
      );
      expect(rows.map((r) => r['amount']), [1000, 1000, 2000]);
    },
  );

  test(
    'reconciliation rolls back all months and history if an accrual fails',
    () async {
      final db = await database.database();
      await db.execute('''
      CREATE TRIGGER fail_salary BEFORE INSERT ON expenses
      WHEN NEW.period_key = '2026-03'
      BEGIN SELECT RAISE(ABORT, 'synthetic failure'); END
    ''');
      await expectLater(
        reports.getCapitalMetrics(),
        throwsA(isA<DatabaseException>()),
      );
      expect(await db.query('expenses'), isEmpty);
      expect(await db.query('employee_compensation_periods'), isEmpty);
      await db.execute('DROP TRIGGER fail_salary');
      expect((await reports.getCapitalMetrics()).currentCash, 5000);
    },
  );
}
