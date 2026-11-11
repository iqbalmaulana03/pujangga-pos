import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:pujangga_pos/app/router/app_router.dart';
import 'package:pujangga_pos/app/theme/app_theme.dart';
import 'package:pujangga_pos/core/database/app_database.dart';
import 'package:pujangga_pos/core/services/app_startup_service.dart';
import 'package:pujangga_pos/core/utils/app_date_formatting.dart';
import 'package:pujangga_pos/core/utils/currency_formatter.dart';
import 'package:pujangga_pos/features/katalog/presentation/pages/item_form_page.dart';
import 'package:pujangga_pos/features/laporan/data/datasources/report_local_data_source.dart';
import 'package:pujangga_pos/features/laporan/data/repositories/report_repository_impl.dart';
import 'package:pujangga_pos/features/laporan/domain/entities/report_period.dart';
import 'package:pujangga_pos/features/laporan/presentation/controllers/laporan_controller.dart';
import 'package:pujangga_pos/features/laporan/presentation/pages/laporan_page.dart';
import 'package:pujangga_pos/features/transaksi/presentation/pages/transaksi_berhasil_page.dart';

class _DisposableDatabase extends AppDatabase {
  _DisposableDatabase(this.file);
  final String file;
  @override
  Future<String> databasePath() async => file;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  for (final first in ['capital', 'annual', 'dashboard']) {
    testWidgets('$first first: salary liabilities, stock, sale and reopen', (
      tester,
    ) async {
      initializeAppDateFormatting();
      CurrencyFormatter.configure(currencyCode: 'IDR', currencySymbol: 'Rp');
      final reference = DateTime.now();
      final oldest = DateTime(reference.year, reference.month - 3, 15);
      final temporary = await getTemporaryDirectory();
      expect(
        temporary.path,
        contains('/com.pujanggapos.pujangga_pos.pr66e2e/'),
      );
      final directory = await Directory(
        path.join(
          temporary.path,
          'salary-$first-${reference.microsecondsSinceEpoch}',
        ),
      ).create();
      var database = _DisposableDatabase(
        path.join(directory.path, 'isolated.db'),
      );
      expect(
        path.isWithin(temporary.path, await database.databasePath()),
        isTrue,
      );
      var db = await database.database();
      expect(
        (await db.rawQuery('PRAGMA database_list')).single['file'],
        database.file,
      );
      final stamp = reference.toIso8601String();
      await db.insert('business_profile', {
        'business_name': 'PR66 Sintetis $first',
        'business_type': 'retail',
        'modal_awal_usaha': 10000000,
        'created_at': stamp,
        'updated_at': stamp,
      });
      await db.insert('employees', {
        'name': 'PR66 Gaji',
        'is_active': 1,
        'compensation_type': 'monthly_salary',
        'monthly_salary': 1000000,
        'effective_from': oldest.toIso8601String(),
        'created_at': stamp,
        'updated_at': stamp,
      });
      await db.insert('employees', {
        'name': 'PR66 Masa Depan',
        'is_active': 1,
        'compensation_type': 'monthly_salary',
        'monthly_salary': 2000000,
        'effective_from': DateTime(
          reference.year,
          reference.month + 1,
        ).toIso8601String(),
        'created_at': stamp,
        'updated_at': stamp,
      });
      await db.insert('items', {
        'name': 'PR66 Awal',
        'item_type': 'product',
        'unit': 'Pcs',
        'sale_price': 750000,
        'harga_modal': 500000,
        'stock_qty': 2,
        'created_at': stamp,
        'updated_at': stamp,
      });
      expect(await db.query('expenses'), isEmpty);
      expect(await db.query('employee_compensation_periods'), isEmpty);
      debugPrint(
        'E2E_PASS: $first isolated Android SQLite, 4 overdue months, zero accruals before UI',
      );

      late ProviderContainer container;
      late GoRouter router;
      ReportRepositoryImpl reports() => ReportRepositoryImpl(
        localDataSource: ReportLocalDataSource(database: database),
        now: () => reference,
      );
      void configure(String route) {
        container = ProviderContainer(
          overrides: [
            appDatabaseProvider.overrideWithValue(database),
            reportRepositoryProvider.overrideWithValue(reports()),
          ],
        );
        if (route == AppRoutes.reports) {
          container
              .read(selectedReportPeriodProvider.notifier)
              .select(ReportPeriod.tahunan);
        }
        router = buildAppRouter(hasBusinessProfile: true)..go(route);
      }

      configure(switch (first) {
        'capital' => AppRoutes.catalog,
        'annual' => AppRoutes.reports,
        _ => AppRoutes.home,
      });
      addTearDown(() async {
        router.dispose();
        container.dispose();
        await database.reset();
        await directory.delete(recursive: true);
        debugPrint('E2E_CLEANUP: $first test database removed');
      });
      Future<void> mount() async {
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp.router(
              theme: AppTheme.light(),
              routerConfig: router,
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      Future<void> clearNotice() async {
        for (
          var i = 0;
          i < 70 && find.byType(SnackBar).evaluate().isNotEmpty;
          i++
        ) {
          await tester.pump(const Duration(milliseconds: 100));
          await Future<void>.delayed(const Duration(milliseconds: 100));
        }
      }

      Future<void> tapFinder(Finder finder) async {
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pumpAndSettle();
        await clearNotice();
        await tester.ensureVisible(finder);
        await tester.tap(finder);
        await tester.pumpAndSettle();
      }

      Future<void> tap(String text) => tapFinder(find.text(text).last);
      Future<void> tab(String text) => tapFinder(
        find
            .descendant(
              of: find.byType(NavigationBar),
              matching: find.text(text),
            )
            .last,
      );
      Future<void> screenshot(String label) async {
        debugPrint('E2E_SCREENSHOT: $first-$label');
        await Future<void>.delayed(const Duration(seconds: 2));
      }

      Future<void> enter(Finder finder, String value) async {
        await tester.ensureVisible(finder);
        await tester.enterText(finder, value);
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pumpAndSettle();
      }

      Future<void> fillStock(
        String name,
        String price,
        String cost,
        String quantity,
      ) async {
        await tester.tap(find.byType(FloatingActionButton));
        await tester.pumpAndSettle();
        expect(find.byType(ItemFormPage), findsOneWidget);
        Finder hint(String value) => find.byWidgetPredicate(
          (w) => w is TextField && w.decoration?.hintText == value,
        );
        await enter(hint('e.g. Kopi Susu Aren'), name);
        await enter(hint('Pilih atau ketik kategori'), 'Uji PR66');
        await enter(hint('0').at(0), price);
        await enter(hint('0').at(1), cost);
        await enter(
          find.byWidgetPredicate(
            (w) => w is TextField && w.textAlign == TextAlign.center,
          ),
          quantity,
        );
        await tap('Simpan Barang');
      }

      Future<void> rejectStock(String phase) async {
        await fillStock('PR66 Ditolak', '7000000', '6000000', '1');
        expect(find.textContaining('Stok gagal disimpan.'), findsOneWidget);
        expect(
          find.textContaining(CurrencyFormatter.format(5000000)),
          findsWidgets,
        );
        expect(
          await db.query(
            'items',
            where: 'name = ?',
            whereArgs: ['PR66 Ditolak'],
          ),
          isEmpty,
        );
        await screenshot('rejected-$phase');
        await tapFinder(find.byIcon(Icons.arrow_back).first);
      }

      Future<void> checkLiabilities() async {
        final rows = await db.query('expenses', orderBy: 'period_key');
        expect(rows, hasLength(4));
        expect(rows.map((r) => r['amount']), everyElement(1000000));
        expect(rows.first['expense_date'], oldest.toIso8601String());
        expect(
          rows.map((r) => r['period_key']),
          List.generate(
            4,
            (i) =>
                DateFormat('yyyy-MM')
                    .format(DateTime(reference.year, reference.month - 3 + i)),
          ),
        );
      }

      await mount();
      if (first == 'capital') {
        // Proves the entry route did not mount dashboard or financial reports.
        expect(await db.query('expenses'), isEmpty);
      } else {
        await checkLiabilities();
        await tab('Katalog');
      }
      await rejectStock('before-old-report');
      await checkLiabilities();
      final before = await container.read(capitalMetricsProvider.future);
      expect(before.currentCash, 5000000);
      expect(before.currentStockValue, 1000000);
      expect(before.netCapitalValue, 6000000);
      final accrued = await db.query('expenses', orderBy: 'period_key');

      await tab('Laporan');
      await tap('Tahunan');
      final annual = await container.read(salesReportSnapshotProvider.future);
      expect(
        annual.totalExpenses,
        (reference.month < 4 ? reference.month : 4) * 1000000,
      );
      expect(find.text('PR66 Gaji'), findsOneWidget);
      await screenshot('annual');
      // Use the actual production date-range dialog and its text input mode.
      await tapFinder(find.byIcon(Icons.calendar_month_outlined));
      await tapFinder(find.byTooltip('Switch to input'));
      final dateInputs = find.byType(TextField);
      await enter(
        dateInputs.at(0),
        DateFormat('MM/dd/yyyy').format(DateTime(oldest.year, oldest.month)),
      );
      await enter(
        dateInputs.at(1),
        DateFormat('MM/dd/yyyy')
            .format(DateTime(oldest.year, oldest.month + 1, 0)),
      );
      await tap('OK');
      expect(container.read(selectedReportPeriodProvider), ReportPeriod.kustom);
      final historical = await container.read(
        salesReportSnapshotProvider.future,
      );
      expect(historical.totalExpenses, 1000000);
      expect(historical.start, DateTime(oldest.year, oldest.month));
      await screenshot('historical');
      expect(await db.query('expenses', orderBy: 'period_key'), accrued);
      expect(
        (await reports().getCapitalMetrics()).currentCash,
        before.currentCash,
      );
      await tab('Beranda');
      await tab('Katalog');
      await rejectStock('after-old-report');
      await checkLiabilities();
      debugPrint(
        'E2E_PASS: $first salary=4000000 capital=6000000 cash=5000000; annual/custom/dashboard reads unchanged; 6000000 stock rejected twice',
      );

      await fillStock('PR66 Layak', '1500000', '1000000', '2');
      expect(find.byType(ItemFormPage), findsNothing);
      final saved = (await db.query(
        'items',
        where: 'name = ?',
        whereArgs: ['PR66 Layak'],
      )).single;
      expect(saved['stock_qty'], 2);
      expect((await reports().getCapitalMetrics()).currentCash, 3000000);
      await tab('Transaksi');
      await tap('PR66 Layak');
      await tap('Keranjang');
      await tap('QRIS');
      await tap('Proses Pembayaran');
      expect(find.byType(TransaksiBerhasilPage), findsOneWidget);
      final sales = await db.query('sales_transactions');
      expect(sales, hasLength(1));
      expect(sales.single['total_amount'], 1500000);
      expect(
        (await db.query(
          'items',
          where: 'id = ?',
          whereArgs: [saved['id']],
        )).single['stock_qty'],
        1,
      );
      final afterSale = await reports().getCapitalMetrics();
      expect(afterSale.currentCash, 4500000);
      expect(afterSale.currentStockValue, 2000000);
      expect(afterSale.netCapitalValue, 6500000);
      await screenshot('receipt');
      await checkLiabilities();
      debugPrint(
        'E2E_PASS: $first affordable stock saved; QRIS sale=1500000; stock=1; cash=4500000; capital=6500000',
      );

      final persistedTables = <String, List<Map<String, Object?>>>{};
      for (final table in [
        'expenses',
        'items',
        'sales_transactions',
        'sales_transaction_items',
        'stock_movements',
        'employee_compensation_periods',
      ]) {
        persistedTables[table] = await db.query(table, orderBy: 'id');
      }
      await tester.pumpWidget(const SizedBox.shrink());
      router.dispose();
      container.dispose();
      await db.close();
      database = _DisposableDatabase(database.file);
      db = await database.database();
      configure(AppRoutes.reports);
      await mount();
      expect((await reports().getCapitalMetrics()).currentCash, 4500000);
      for (final entry in persistedTables.entries) {
        expect(await db.query(entry.key, orderBy: 'id'), entry.value);
      }
      expect(
        (await db.rawQuery('PRAGMA integrity_check')).single.values.single,
        'ok',
      );
      expect(await db.rawQuery('PRAGMA foreign_key_check'), isEmpty);
      final report = await container.read(salesReportSnapshotProvider.future);
      expect(report.revenue, 1500000);
      await screenshot('reopened-report');
      debugPrint(
        'E2E_PASS: $first SQLite reopened, six tables identical; income=1500000; no duplicate salary; integrity=ok; foreign_keys=ok',
      );
      expect(find.byType(LaporanPage), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
