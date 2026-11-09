import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:pujangga_pos/app/app.dart';
import 'package:pujangga_pos/core/database/app_database.dart';
import 'package:pujangga_pos/core/errors/app_exception.dart';
import 'package:pujangga_pos/core/services/app_startup_service.dart';
import 'package:pujangga_pos/core/utils/app_date_formatting.dart';
import 'package:pujangga_pos/features/karyawan/data/repositories/employee_repository.dart';
import 'package:pujangga_pos/features/transaksi/data/datasources/transaction_local_data_source.dart';
import 'package:pujangga_pos/features/transaksi/data/repositories/transaction_repository_impl.dart';
import 'package:pujangga_pos/features/transaksi/domain/entities/transaksi_item.dart';
import 'package:pujangga_pos/features/transaksi/domain/entities/transaksi_receipt.dart';
import 'package:pujangga_pos/features/transaksi/domain/entities/transaksi_submit_request.dart';
import 'package:pujangga_pos/features/transaksi/domain/repositories/transaction_repository.dart';
import 'package:pujangga_pos/features/transaksi/presentation/controllers/transaksi_controller.dart';
import 'package:pujangga_pos/features/transaksi/presentation/pages/transaksi_berhasil_page.dart';

class _DisposableDatabase extends AppDatabase {
  _DisposableDatabase(this.filePath);
  final String filePath;

  @override
  Future<String> databasePath() async => filePath;
}

// Only the catalog fault is synthetic. Saves, receipts, stock, commissions,
// reports, app startup, navigation and all other providers use Android SQLite.
class _CatalogFaultRepository implements TransactionRepository {
  _CatalogFaultRepository(this.delegate);
  final TransactionRepository delegate;
  bool failCatalog = false;
  bool failAfterCommit = true;
  int saves = 0;
  int reads = 0;
  TransaksiSubmitRequest? lastRequest;
  final attempts = <TransaksiSubmitRequest>[];
  Completer<void>? saveGate;
  Completer<void>? refreshGate;
  bool failNextSave = false;

  @override
  Future<List<TransaksiItem>> getCatalogItems() async {
    reads++;
    await refreshGate?.future;
    if (failCatalog) throw StateError('E2E injected catalog read failure');
    return delegate.getCatalogItems();
  }

  @override
  Future<TransaksiReceipt> saveTransaction(
    TransaksiSubmitRequest request,
  ) async {
    attempts.add(request);
    lastRequest = request;
    await saveGate?.future;
    if (failNextSave) {
      failNextSave = false;
      throw StateError('E2E injected failure before persistence');
    }
    saves++;
    final receipt = await delegate.saveTransaction(request);
    failCatalog = failAfterCommit;
    return receipt;
  }

  @override
  Future<TransaksiReceipt?> getReceiptByInvoice(String invoiceNumber) =>
      delegate.getReceiptByInvoice(invoiceNumber);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('committed checkout survives catalog faults and Android back', (
    tester,
  ) async {
    initializeAppDateFormatting();
    final temporaryRoot = await getTemporaryDirectory();
    // Refuse any production/release package BEFORE opening or mutating a DB.
    expect(
      temporaryRoot.path,
      contains('/com.pujanggapos.pujangga_pos.debug/'),
    );
    final directory = await Directory(
      path.join(
        temporaryRoot.path,
        'checkout-e2e-${DateTime.now().microsecondsSinceEpoch}',
      ),
    ).create();
    final database = _DisposableDatabase(
      path.join(directory.path, 'isolated.db'),
    );
    expect(
      path.isWithin(temporaryRoot.path, await database.databasePath()),
      isTrue,
    );
    final db = await database.database();
    final stamp = DateTime.now().toIso8601String();
    await db.insert('business_profile', {
      'business_name': 'E2E Disposable POS',
      'business_type': 'retail',
      'created_at': stamp,
      'updated_at': stamp,
    });
    await db.insert('items', {
      'name': 'E2E Kopi',
      'item_type': 'product',
      'sale_price': 10000,
      'harga_modal': 4000,
      'stock_qty': 10,
      'unit': 'Pcs',
      'created_at': stamp,
      'updated_at': stamp,
    });
    await EmployeeRepository(database: database).save(
      name: 'E2E Komisi',
      isActive: true,
      compensationType: 'commission',
      commissionPercent: 10,
      effectiveFrom: DateTime.now(),
    );
    final repository = _CatalogFaultRepository(
      TransactionRepositoryImpl(
        localDataSource: TransactionLocalDataSource(database: database),
      ),
    );
    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        transactionRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await database.reset();
      await directory.delete(recursive: true);
    });
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const PujanggaPosApp(),
      ),
    );
    await tester.pumpAndSettle();
    debugPrint('E2E_STEP: startup settled');
    await tester.tap(find.text('Transaksi').last);
    await tester.pumpAndSettle();
    debugPrint('E2E_STEP: transaction tab');

    Future<void> checkout({bool exerciseLock = false}) async {
      await tester.tap(find.text('E2E Kopi').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Keranjang'));
      await tester.pumpAndSettle();
      debugPrint('E2E_STEP: cart opened');
      final employees = find.byType(DropdownButtonFormField<int?>);
      await tester.ensureVisible(employees);
      await tester.tap(employees);
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('E2E Komisi').last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('QRIS'));
      await tester.tap(find.text('QRIS'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Proses Pembayaran'));
      if (exerciseLock) {
        repository.saveGate = Completer<void>();
        repository.failNextSave = true;
      }
      await tester.tap(find.text('Proses Pembayaran'));
      debugPrint('E2E_STEP: payment tapped');
      if (exerciseLock) {
        // Real UI starts submit; pause only the repository boundary so input
        // and repeated submissions race against a deterministic pending save.
        await tester.pump();
        final controller = container.read(transaksiControllerProvider.notifier);
        final pending = container
            .read(transaksiControllerProvider)
            .requireValue;
        expect(pending.isSubmitting, isTrue);
        expect(pending.canSubmit, isFalse);
        expect(
          tester
              .widget<FilledButton>(
                find.ancestor(
                  of: find.text('Memproses...'),
                  matching: find.byType(FilledButton),
                ),
              )
              .onPressed,
          isNull,
        );
        await tester.tap(find.text('Tunai'));
        await tester.pump();
        controller.updateCashPaid(20000);
        controller.clearCart();
        controller.updateEmployee(null);
        controller.updateSearch('changed while saving');
        controller.updateFilter('jasa');
        expect(
          container.read(transaksiControllerProvider).requireValue,
          same(pending),
        );
        await expectLater(controller.submit(), throwsA(isA<AppException>()));
        expect(repository.attempts, hasLength(1));
        expect(await db.query('sales_transactions'), isEmpty);
        repository.saveGate!.complete();
        await tester.pumpAndSettle();
        debugPrint('E2E_STEP: failed save settled');
        final failed = container.read(transaksiControllerProvider).requireValue;
        expect(failed.isSubmitting, isFalse);
        expect(failed.canSubmit, isTrue);
        expect(failed.cartItems, same(pending.cartItems));
        expect(failed.employeeId, pending.employeeId);
        expect(failed.paymentMethod, 'qris');
        expect(await db.query('sales_transactions'), isEmpty);
        expect(await db.query('stock_movements'), isEmpty);
        expect(
          await db.query('expenses', where: "source_type = 'commission'"),
          isEmpty,
        );
        expect((await db.query('items')).single['stock_qty'], 10);
        expect(
          find.text('Transaksi gagal disimpan. Coba lagi.'),
          findsOneWidget,
        );
        // Keep rendering while the expected error toast expires, just as on
        // device. A single long pump can stall navigator/overlay transitions.
        final toastDeadline = DateTime.now().add(const Duration(seconds: 10));
        while (find
                .text('Transaksi gagal disimpan. Coba lagi.')
                .evaluate()
                .isNotEmpty &&
            DateTime.now().isBefore(toastDeadline)) {
          await tester.pump(const Duration(milliseconds: 100));
          await Future<void>.delayed(const Duration(milliseconds: 50));
        }
        expect(find.text('Transaksi gagal disimpan. Coba lagi.'), findsNothing);
        debugPrint(
          'E2E_STEP: failure preserved cart and ledger; retry after toast',
        );

        repository.saveGate = Completer<void>();
        repository.refreshGate = Completer<void>();
        await tester.tap(find.text('Proses Pembayaran'));
        await tester.pump();
        expect(repository.attempts, hasLength(2));
        expect(repository.attempts.last, same(repository.attempts.first));
        repository.saveGate!.complete();
        final deadline = DateTime.now().add(const Duration(seconds: 20));
        while (!container
                .read(transaksiControllerProvider)
                .requireValue
                .isRefreshingCatalog &&
            DateTime.now().isBefore(deadline)) {
          await tester.pump(const Duration(milliseconds: 100));
          await Future<void>.delayed(const Duration(milliseconds: 50));
        }
        final refreshing = container
            .read(transaksiControllerProvider)
            .requireValue;
        expect(refreshing.isRefreshingCatalog, isTrue);
        expect(refreshing.isSubmitting, isTrue);
        expect(refreshing.canSubmit, isFalse);
        expect(refreshing.cartItems, isEmpty);
        controller.addItem(
          (await repository.delegate.getCatalogItems()).single,
        );
        controller.updatePaymentMethod('tunai');
        expect(
          container.read(transaksiControllerProvider).requireValue,
          same(refreshing),
        );
        await expectLater(controller.submit(), throwsA(isA<AppException>()));
        expect(repository.attempts, hasLength(2));
        expect(await db.query('sales_transactions'), hasLength(1));
        debugPrint(
          'E2E_STEP: same-key retry committed once; refresh still locked',
        );
        repository.refreshGate!.complete();
        repository.refreshGate = null;
        repository.saveGate = null;
      }
      // A completed gate resumes async SQLite/provider work before navigation
      // schedules its next frame. pumpAndSettle alone can return in that gap.
      final receiptDeadline = DateTime.now().add(const Duration(seconds: 20));
      while (find.byType(TransaksiBerhasilPage).evaluate().isEmpty &&
          DateTime.now().isBefore(receiptDeadline)) {
        await tester.pump(const Duration(milliseconds: 100));
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
      await tester.pumpAndSettle();
      expect(find.byType(TransaksiBerhasilPage), findsOneWidget);
      expect(find.text('Transaksi gagal disimpan. Coba lagi.'), findsNothing);
    }

    Future<void> verifyLedger(int count) async {
      final sales = await db.query('sales_transactions');
      expect(sales, hasLength(count));
      expect(sales.map((row) => row['checkout_id']).toSet(), hasLength(count));
      expect(sales.every((row) => row['commission_amount'] == 1000), isTrue);
      expect(await db.query('sales_transaction_items'), hasLength(count));
      expect(await db.query('stock_movements'), hasLength(count));
      expect(
        await db.query('expenses', where: "source_type = 'commission'"),
        hasLength(count),
      );
      expect((await db.query('items')).single['stock_qty'], 10 - count);
      expect(
        container.read(transaksiControllerProvider).requireValue.cartItems,
        isEmpty,
      );
    }

    try {
      await checkout(exerciseLock: true);
    } catch (error, stack) {
      debugPrint('E2E_CHECKOUT_FAILURE: $error\n$stack');
      rethrow;
    }
    await verifyLedger(1);
    expect(repository.saves, 1);
    final firstRequest = repository.lastRequest!;
    final readsBeforeBack = repository.reads;
    // The host sends an actual adb KEYCODE_BACK at this checkpoint.
    // This exercises Android -> Flutter -> GoRouter, not handlePopRoute().
    debugPrint('E2E_WAIT_ANDROID_BACK');
    final deadline = DateTime.now().add(const Duration(seconds: 90));
    while (find.byType(TransaksiBerhasilPage).evaluate().isNotEmpty &&
        DateTime.now().isBefore(deadline)) {
      await tester.pump(const Duration(milliseconds: 200));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    expect(
      find.byType(TransaksiBerhasilPage),
      findsNothing,
      reason: 'Send adb shell input keyevent 4 at E2E_WAIT_ANDROID_BACK',
    );
    await tester.pumpAndSettle();
    expect(repository.reads, greaterThan(readsBeforeBack));
    expect(find.text('Gagal memuat katalog.'), findsOneWidget);
    expect(find.text('Katalog kosong atau tidak ditemukan.'), findsNothing);
    await verifyLedger(1);
    await tester.tap(find.text('Muat Ulang'));
    await tester.pumpAndSettle();
    expect(find.text('Gagal memuat katalog.'), findsOneWidget);
    await verifyLedger(1);
    repository.failCatalog = false;
    await tester.tap(find.text('Muat Ulang'));
    await tester.pumpAndSettle();
    expect(find.text('E2E Kopi'), findsOneWidget);
    expect(find.text('Muat Ulang'), findsNothing);
    expect(repository.saves, 1);

    // Replay at the real repository boundary to verify durable idempotency.
    final replay = await repository.delegate.saveTransaction(firstRequest);
    final original = (await db.query('sales_transactions')).single;
    expect(replay.invoiceNumber, original['invoice_no']);
    await verifyLedger(1);
    repository.failAfterCommit = false;
    await checkout();
    await verifyLedger(2);
    expect(repository.saves, 2);
    await tester.tap(find.text('Transaksi Baru'));
    await tester.pumpAndSettle();
    expect(find.text('E2E Kopi'), findsOneWidget);
    await verifyLedger(2);

    // Unmount every provider before closing and reopening the same real DB.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    container.dispose();
    await db.close();
    final reopened = _DisposableDatabase(await database.databasePath());
    final persisted = await reopened.database();
    expect(await persisted.query('sales_transactions'), hasLength(2));
    expect((await persisted.query('items')).single['stock_qty'], 8);
    expect(
      await persisted.query('expenses', where: "source_type = 'commission'"),
      hasLength(2),
    );
    await persisted.close();
    debugPrint(
      'E2E_PASS: 2 sales; stock=8; 2 commissions; '
      'native-back + failed/recovered refresh + idempotency + reopen verified',
    );
  }, timeout: const Timeout(Duration(minutes: 6)));
}
