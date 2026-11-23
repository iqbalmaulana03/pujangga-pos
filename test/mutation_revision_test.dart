import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:pujangga_pos/core/database/app_database.dart';
import 'package:pujangga_pos/core/services/app_startup_service.dart';
import 'package:pujangga_pos/core/services/mutation_revision.dart';
import 'package:pujangga_pos/features/karyawan/presentation/controllers/employee_controller.dart';
import 'package:pujangga_pos/features/katalog/domain/entities/catalog_item_draft.dart';
import 'package:pujangga_pos/features/katalog/presentation/controllers/katalog_controller.dart';
import 'package:pujangga_pos/features/laporan/domain/entities/report_period.dart';
import 'package:pujangga_pos/features/laporan/presentation/controllers/laporan_controller.dart';
import 'package:pujangga_pos/features/pengeluaran/data/repositories/expense_repository.dart';
import 'package:pujangga_pos/features/pengeluaran/presentation/controllers/tambah_pengeluaran_controller.dart';
import 'package:pujangga_pos/features/riwayat/presentation/controllers/riwayat_controller.dart';
import 'package:pujangga_pos/features/stok/domain/entities/stock_adjustment_request.dart';
import 'package:pujangga_pos/features/stok/presentation/controllers/stok_controller.dart';
import 'package:pujangga_pos/features/transaksi/presentation/controllers/transaksi_controller.dart';
import 'package:pujangga_pos/features/transaksi/presentation/models/transaksi_state.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  test('publishes affected revisions together after success only', () async {
    final container = ProviderContainer.test();
    final changes = <MutationRevisions>[];
    container.listen(mutationRevisionProvider, (_, next) => changes.add(next));
    final revision = container.read(mutationRevisionProvider.notifier);
    final gate = Completer<int>();
    final pending = revision.commit({
      MutationDomain.financial,
      MutationDomain.stock,
    }, () => gate.future);
    expect(changes, isEmpty);
    await expectLater(
      revision.commit<void>({
        MutationDomain.catalog,
      }, () async => throw StateError('write failed')),
      throwsStateError,
    );
    expect(changes, isEmpty);
    gate.complete(42);
    expect(await pending, 42);
    expect(changes, [(financial: 1, stock: 1, catalog: 0)]);
  });

  group('active SQLite queries', () {
    late ProviderContainer container;
    late Directory directory;
    late AppDatabase database;

    setUpAll(() {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });

    setUp(() async {
      directory = await Directory.systemTemp.createTemp('pujangga_revision_');
      await databaseFactory.setDatabasesPath(directory.path);
      database = AppDatabase();
      expect(path.dirname(await database.databasePath()), directory.path);
      expect(path.dirname((await database.database()).path), directory.path);
      container = ProviderContainer(
        overrides: [appDatabaseProvider.overrideWithValue(database)],
      );
    });

    tearDown(() async {
      container.dispose();
      await database.reset();
      await directory.delete(recursive: true);
    });

    Future<TransaksiState> checkoutWhen(
      bool Function(TransaksiState) matches,
    ) async {
      final result = Completer<TransaksiState>();
      final subscription = container.listen(transaksiControllerProvider, (
        _,
        next,
      ) {
        final state = next.asData?.value;
        if (state != null && !result.isCompleted && matches(state)) {
          result.complete(state);
        }
      }, fireImmediately: true);
      try {
        return await result.future.timeout(const Duration(seconds: 10));
      } finally {
        subscription.close();
      }
    }

    test(
      'catalog, checkout, void, and stock update active query families',
      () async {
        final daily = salesReportSnapshotByPeriodProvider(ReportPeriod.harian);
        final weekly = salesReportSnapshotByPeriodProvider(
          ReportPeriod.mingguan,
        );
        container.listen(daily, (_, _) {});
        container.listen(weekly, (_, _) {});
        container.listen(salesReportSnapshotProvider, (_, _) {});
        container.listen(capitalMetricsProvider, (_, _) {});
        container.listen(katalogControllerProvider, (_, _) {});
        container.listen(stokControllerProvider, (_, _) {});
        container.listen(transaksiControllerProvider, (_, _) {});
        expect((await container.read(daily.future)).topMarginItems, isEmpty);
        expect((await container.read(weekly.future)).topMarginItems, isEmpty);
        expect(
          (await container.read(salesReportSnapshotProvider.future))
              .transactionCount,
          0,
        );
        expect(
          (await container.read(capitalMetricsProvider.future))
              .currentStockValue,
          0,
        );
        expect(
          (await container.read(katalogControllerProvider.future)).allItems,
          isEmpty,
        );
        expect(
          (await container.read(stokControllerProvider.future)).allItems,
          isEmpty,
        );
        expect(
          (await container.read(transaksiControllerProvider.future))
              .catalogItems,
          isEmpty,
        );

        final catalog = container.read(katalogControllerProvider.notifier);
        await catalog.saveItem(
          const CatalogItemDraft(
            name: 'Kopi',
            category: 'Minuman',
            itemType: 'barang',
            sellingPrice: 10000,
            isActive: true,
            stockQuantity: 5,
            costPrice: 4000,
          ),
        );
        expect(
          (await container.read(daily.future)).topMarginItems.single.name,
          'Kopi',
        );
        expect(
          (await container.read(weekly.future)).topMarginItems.single.name,
          'Kopi',
        );
        final item = (await container.read(katalogControllerProvider.future))
            .allItems
            .single;
        final detail = stockItemDetailProvider(item.id);
        final movements = stockMovementDetailProvider(item.id);
        final itemDetail = catalogItemProvider(item.id);
        container.listen(detail, (_, _) {});
        container.listen(movements, (_, _) {});
        container.listen(itemDetail, (_, _) {});
        expect((await container.read(detail.future))!.currentStock, 5);
        expect(await container.read(movements.future), hasLength(1));
        expect((await container.read(itemDetail.future))!.name, 'Kopi');

        await catalog.saveItem(
          const CatalogItemDraft(
            name: 'Kopi Susu',
            category: 'Minuman',
            itemType: 'barang',
            sellingPrice: 10000,
            isActive: true,
            preserveStock: true,
            costPrice: 4000,
          ),
          itemId: item.id,
        );
        expect((await container.read(itemDetail.future))!.name, 'Kopi Susu');
        expect(
          (await container.read(weekly.future)).topMarginItems.single.name,
          'Kopi Susu',
        );

        final checkout = container.read(transaksiControllerProvider.notifier);
        final updatedPicker = (await checkoutWhen(
          (state) => state.catalogItems.singleOrNull?.name == 'Kopi Susu',
        )).catalogItems;
        expect(updatedPicker.single.name, 'Kopi Susu');
        checkout.addItem(updatedPicker.single);
        checkout.updatePaymentMethod('qris');
        final sale = await checkout.submit();
        final receipt = transaksiReceiptProvider(sale.invoiceNumber);
        container.listen(receipt, (_, _) {});
        expect((await container.read(receipt.future))!.status, 'completed');
        expect((await container.read(daily.future)).transactionCount, 1);
        expect(
          (await container.read(salesReportSnapshotProvider.future))
              .transactionCount,
          1,
        );
        expect((await container.read(detail.future))!.currentStock, 4);
        expect(await container.read(movements.future), hasLength(2));

        // Start void through the same entry point as the detail route, with no list listener.
        await container
            .read(riwayatControllerProvider.notifier)
            .voidTransaction(sale.invoiceNumber);
        container.listen(riwayatControllerProvider, (_, _) {});
        expect(
          (await container.read(riwayatControllerProvider.future))
              .allTransactions
              .single
              .status,
          'voided',
        );
        expect((await container.read(receipt.future))!.status, 'voided');
        expect((await container.read(daily.future)).transactionCount, 0);
        expect((await container.read(detail.future))!.currentStock, 5);
        expect(await container.read(movements.future), hasLength(3));

        final draftItem = (await checkoutWhen(
          (state) => state.catalogItems.singleOrNull?.stockQuantity == 5,
        )).catalogItems.single;
        checkout.addItem(draftItem);
        checkout.updateItemDiscount(draftItem.id, 1000);
        checkout.updateTaxAmount(500);
        checkout.updateCashPaid(20000);
        container.read(stokControllerProvider.notifier).updateSearch('susu');
        await container
            .read(stokControllerProvider.notifier)
            .submitAdjustment(
              StockAdjustmentRequest(
                itemId: item.id,
                adjustmentType: 'manual_add',
                quantity: 2,
              ),
            );
        expect((await container.read(detail.future))!.currentStock, 7);
        expect((await container.read(itemDetail.future))!.stockQuantity, 7);
        expect(
          (await container.read(capitalMetricsProvider.future))
              .currentStockValue,
          28000,
        );
        expect(
          (await container.read(stokControllerProvider.future)).searchQuery,
          'susu',
        );
        expect(await container.read(movements.future), hasLength(4));
        final draft = await checkoutWhen(
          (state) => state.catalogItems.singleOrNull?.stockQuantity == 7,
        );
        expect(draft.cartItems.single.itemDiscountAmount, 1000);
        expect(draft.taxAmount, 500);
        expect(draft.cashPaidAmount, 20000);

        await catalog.toggleItemStatus(
          (await container.read(itemDetail.future))!,
        );
        expect((await container.read(daily.future)).topMarginItems, isEmpty);
        expect((await container.read(itemDetail.future))!.isActive, isFalse);
        final deactivated = await checkoutWhen(
          (state) => state.catalogItems.isEmpty && !state.isRefreshingCatalog,
        );
        expect(deactivated.catalogItems, isEmpty);
        expect(deactivated.cartItems, isEmpty);
      },
    );

    test(
      'expense and employee saves refresh finance without clearing checkout',
      () async {
        final today = DateTime.now();
        final range = (
          DateTime(today.year, today.month),
          DateTime(today.year, today.month + 1),
        );
        final expenses = expenseEntriesProvider(range);
        final team = employeeReportProvider(range);
        final salary = employeeSalaryForMonthProvider((1, today));
        container.listen(dashboardSummaryProvider, (_, _) {});
        container.listen(expenses, (_, _) {});
        container.listen(team, (_, _) {});
        container.listen(salary, (_, _) {});
        container.listen(employeesProvider, (_, _) {});
        container.listen(activeEmployeesProvider, (_, _) {});
        container.listen(transaksiControllerProvider, (_, _) {});

        await container
            .read(katalogControllerProvider.notifier)
            .saveItem(
              const CatalogItemDraft(
                name: 'Potong',
                category: 'Jasa',
                itemType: 'jasa',
                sellingPrice: 20000,
                isActive: true,
              ),
            );
        final item = (await checkoutWhen(
          (state) => state.catalogItems.singleOrNull?.name == 'Potong',
        )).catalogItems.single;
        final checkout = container.read(transaksiControllerProvider.notifier);
        checkout.addItem(item);
        checkout.updatePaymentMethod('qris');
        expect(await container.read(expenses.future), isEmpty);
        expect(await container.read(team.future), isEmpty);
        expect(await container.read(salary.future), isNull);
        expect(await container.read(employeesProvider.future), isEmpty);
        expect(await container.read(activeEmployeesProvider.future), isEmpty);
        expect(
          (await container.read(dashboardSummaryProvider.future))
              .totalExpensesToday,
          0,
        );

        await container
            .read(tambahPengeluaranControllerProvider.notifier)
            .simpanPengeluaran(
              nominal: 15000,
              kategori: 'Operasional',
              tanggal: today,
            );
        expect((await container.read(expenses.future)).single['amount'], 15000);
        expect(
          (await container.read(dashboardSummaryProvider.future))
              .totalExpensesToday,
          15000,
        );

        await container
            .read(employeeControllerProvider.notifier)
            .save(
              name: 'Ayu',
              isActive: true,
              compensationType: 'monthly_salary',
              monthlySalary: 3000000,
              effectiveFrom: range.$1,
            );
        expect(
          (await container.read(employeesProvider.future)).single.name,
          'Ayu',
        );
        expect(
          (await container.read(activeEmployeesProvider.future)).single.name,
          'Ayu',
        );
        expect((await container.read(team.future)).single.employeeName, 'Ayu');
        expect(await container.read(salary.future), 3000000);
        final draft = container.read(transaksiControllerProvider).requireValue;
        expect(draft.cartItems.single.item.id, item.id);
        expect(draft.paymentMethod, 'qris');

        final revision = container.read(mutationRevisionProvider);
        await container
            .read(tambahPengeluaranControllerProvider.notifier)
            .simpanPengeluaran(
              nominal: 0,
              kategori: 'Operasional',
              tanggal: today,
            );
        expect(
          container.read(tambahPengeluaranControllerProvider).hasError,
          isTrue,
        );
        expect(container.read(mutationRevisionProvider), revision);
      },
    );
  });
}
