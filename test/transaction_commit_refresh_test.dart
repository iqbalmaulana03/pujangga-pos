import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:pujangga_pos/core/errors/app_exception.dart';
import 'package:pujangga_pos/core/services/app_startup_service.dart';
import 'package:pujangga_pos/features/karyawan/presentation/controllers/employee_controller.dart';
import 'package:pujangga_pos/features/pengaturan/domain/entities/app_settings.dart';
import 'package:pujangga_pos/features/pengaturan/presentation/controllers/pengaturan_settings_controller.dart';
import 'package:pujangga_pos/features/transaksi/domain/entities/transaksi_item.dart';
import 'package:pujangga_pos/features/transaksi/domain/entities/transaksi_receipt.dart';
import 'package:pujangga_pos/features/transaksi/domain/entities/transaksi_submit_request.dart';
import 'package:pujangga_pos/features/transaksi/domain/repositories/transaction_repository.dart';
import 'package:pujangga_pos/features/transaksi/presentation/controllers/transaksi_controller.dart';
import 'package:pujangga_pos/features/transaksi/presentation/pages/transaksi_page.dart';
import 'package:pujangga_pos/features/transaksi/presentation/pages/transaksi_berhasil_page.dart';

const item = TransaksiItem(
  id: '1',
  name: 'Kopi',
  category: '',
  itemType: 'barang',
  sellingPrice: 10000,
  stockQuantity: 10,
  isActive: true,
);

class FaultRepository implements TransactionRepository {
  int reads = 0;
  final requests = <TransaksiSubmitRequest>[];
  bool failRefresh = true;
  bool emptyCatalog = false;
  bool failSave = false;
  Completer<void>? saveGate;
  Completer<void>? refreshGate;
  TransaksiReceipt? savedReceipt;

  @override
  Future<List<TransaksiItem>> getCatalogItems() async {
    reads++;
    if (reads > 1) await refreshGate?.future;
    if (reads > 1 && failRefresh) throw StateError('Injected catalog fault');
    return emptyCatalog ? [] : [item];
  }

  @override
  Future<TransaksiReceipt> saveTransaction(
    TransaksiSubmitRequest request,
  ) async {
    requests.add(request);
    await saveGate?.future;
    if (failSave) throw StateError('Injected save fault');
    return savedReceipt = TransaksiReceipt(
      invoiceNumber: 'INV-${requests.length}',
      createdAt: DateTime(2026),
      paymentMethod: request.paymentMethod,
      subtotalAmount: 10000,
      itemDiscountAmount: 0,
      orderDiscountAmount: 0,
      taxAmount: 0,
      totalAmount: 10000,
      changeAmount: 0,
      items: request.items,
    );
  }

  @override
  Future<TransaksiReceipt?> getReceiptByInvoice(String invoiceNumber) async =>
      savedReceipt;
}

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));
  late FaultRepository repository;
  late ProviderContainer container;

  setUp(() async {
    // Repository and settings are fully overridden: no runtime DB or services.
    repository = FaultRepository();
    container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWith(
          (ref) => throw StateError('No runtime database in checkout tests'),
        ),
        businessProfileProvider.overrideWith((ref) async => null),
        activeEmployeesProvider.overrideWith((ref) async => []),
        transactionRepositoryProvider.overrideWithValue(repository),
        appSettingsProvider.overrideWith(
          (ref) async => const AppSettings(
            currencyCode: 'IDR',
            currencySymbol: 'Rp',
            defaultTaxPercent: 0,
            stockAllowNegative: false,
          ),
        ),
      ],
    );
    container.listen(transaksiControllerProvider, (_, _) {});
    await container.read(transaksiControllerProvider.future);
  });
  tearDown(() => container.dispose());

  TransaksiController checkout() {
    final controller = container.read(transaksiControllerProvider.notifier);
    controller.addItem(item);
    controller.updatePaymentMethod('qris');
    return controller;
  }

  test('a genuinely empty catalog is not a refresh failure', () async {
    repository.failRefresh = false;
    repository.emptyCatalog = true;
    await container.read(transaksiControllerProvider.notifier).refreshCatalog();
    final state = container.read(transaksiControllerProvider).requireValue;
    expect(state.catalogItems, isEmpty);
    expect(state.catalogRefreshFailed, isFalse);
    expect(state.isRefreshingCatalog, isFalse);
    expect(repository.requests, isEmpty);
  });

  testWidgets('mobile checkout closes its cart route only once during refresh', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(480, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final router = GoRouter(
      initialLocation: '/transaction',
      routes: [
        GoRoute(
          path: '/transaction',
          builder: (_, _) => const Scaffold(body: TransaksiPage()),
        ),
        GoRoute(
          path: '/transaction/success/:invoiceNumber',
          builder: (_, state) => TransaksiBerhasilPage(
            invoiceNumber: state.pathParameters['invoiceNumber']!,
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    checkout();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Keranjang'));
    await tester.pumpAndSettle();
    repository.refreshGate = Completer<void>();
    await tester.ensureVisible(find.text('Proses Pembayaran'));
    await tester.tap(find.text('Proses Pembayaran'));
    // Commit clears the cart and starts dismissing the sheet while the catalog
    // read is still pending. Complete that read during the dismissal animation.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(
      container
          .read(transaksiControllerProvider)
          .requireValue
          .isRefreshingCatalog,
      isTrue,
    );
    repository.refreshGate!.complete();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(TransaksiBerhasilPage), findsOneWidget);
    expect(repository.requests, hasLength(1));
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(TransaksiPage), findsOneWidget);
    expect(find.byType(TransaksiBerhasilPage), findsNothing);
    expect(repository.requests, hasLength(1));
  });

  for (final wide in [false, true]) {
    for (final failOnBack in [false, true]) {
      testWidgets(
        'system back reloads catalog; failed retry recovers without resaving '
        '(wide=$wide, failOnBack=$failOnBack)',
        (tester) async {
          // All data providers use fakes; no runtime database is opened.
          // 480 stays below the 720 breakpoint and accommodates receipt text
          // rendered with Flutter's wider Ahem test font.
          tester.view.physicalSize = Size(wide ? 1400 : 480, 1200);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final router = GoRouter(
            initialLocation: '/transaction',
            routes: [
              GoRoute(
                path: '/transaction',
                builder: (_, _) => const Scaffold(body: TransaksiPage()),
              ),
              GoRoute(
                path: '/transaction/success/:invoiceNumber',
                builder: (_, state) => TransaksiBerhasilPage(
                  invoiceNumber: state.pathParameters['invoiceNumber']!,
                ),
              ),
            ],
          );
          addTearDown(router.dispose);
          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: MaterialApp.router(routerConfig: router),
            ),
          );
          await tester.pumpAndSettle();
          checkout();
          await tester.pumpAndSettle();
          if (!wide) {
            await tester.tap(find.text('Keranjang'));
            await tester.pumpAndSettle();
          }
          await tester.ensureVisible(find.text('Proses Pembayaran'));
          await tester.tap(find.text('Proses Pembayaran'));
          await tester.pumpAndSettle();
          expect(find.byType(TransaksiBerhasilPage), findsOneWidget);
          expect(repository.requests, hasLength(1));
          expect(
            container
                .read(transaksiControllerProvider)
                .requireValue
                .catalogRefreshFailed,
            isTrue,
          );
          final readsBeforeBack = repository.reads;
          repository.failRefresh = failOnBack;
          await tester.binding.handlePopRoute();
          await tester.pumpAndSettle();
          expect(find.byType(TransaksiBerhasilPage), findsNothing);
          expect(repository.reads, readsBeforeBack + 1);
          if (failOnBack) {
            expect(find.text('Gagal memuat katalog.'), findsOneWidget);
            expect(
              find.text('Katalog kosong atau tidak ditemukan.'),
              findsNothing,
            );
            await tester.tap(find.text('Muat Ulang'));
            await tester.pumpAndSettle();
            expect(find.text('Gagal memuat katalog.'), findsOneWidget);
            repository.failRefresh = false;
            repository.refreshGate = Completer<void>();
            await tester.tap(find.text('Muat Ulang'));
            await tester.pump();
            expect(find.byType(CircularProgressIndicator), findsOneWidget);
            repository.refreshGate!.complete();
            await tester.pumpAndSettle();
          }
          expect(find.text('Kopi'), findsOneWidget);
          expect(find.text('Muat Ulang'), findsNothing);
          final state = container
              .read(transaksiControllerProvider)
              .requireValue;
          expect(state.cartItems, isEmpty);
          expect(state.catalogRefreshFailed, isFalse);
          expect(repository.requests, hasLength(1));
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  test(
    'post-commit catalog failure returns receipt and retry only reads',
    () async {
      final controller = checkout();
      final receipt = await controller.submit();
      expect(receipt.invoiceNumber, 'INV-1');
      var state = container.read(transaksiControllerProvider).requireValue;
      expect(state.cartItems, isEmpty);
      expect(state.catalogItems, isEmpty);
      expect(state.isSubmitting, isFalse);
      expect(state.catalogRefreshFailed, isTrue);
      await expectLater(controller.submit(), throwsA(isA<AppException>()));
      await controller
          .refreshCatalog(); // A second failed refresh is also safe.
      repository.failRefresh = false;
      await controller.refreshCatalog();
      state = container.read(transaksiControllerProvider).requireValue;
      expect(state.catalogItems, [item]);
      expect(state.catalogRefreshFailed, isFalse);
      expect(state.cartItems, isEmpty);
      expect(repository.requests, hasLength(1));
      checkout();
      await controller.submit();
      expect(repository.requests, hasLength(2));
      expect(
        repository.requests[1].checkoutId,
        isNot(repository.requests[0].checkoutId),
      );
    },
  );

  test(
    'save failure retains checkout and its key for an unchanged retry',
    () async {
      final controller = checkout();
      repository.failSave = true;
      await expectLater(controller.submit(), throwsStateError);
      expect(
        container.read(transaksiControllerProvider).requireValue.cartItems,
        hasLength(1),
      );
      repository.failSave = false;
      await controller.submit();
      expect(
        repository.requests[1].checkoutId,
        repository.requests[0].checkoutId,
      );
    },
  );

  test(
    'overlapping submit and edits cannot create a second in-flight sale',
    () async {
      final controller = checkout();
      repository.saveGate = Completer<void>();
      final saving = controller.submit();
      controller.clearCart();
      controller.updatePaymentMethod('transfer');
      controller.updateCashPaid(20000);
      expect(
        container.read(transaksiControllerProvider).requireValue.isSubmitting,
        isTrue,
      );
      await expectLater(controller.submit(), throwsA(isA<AppException>()));
      expect(repository.requests, hasLength(1));
      repository.saveGate!.complete();
      await saving;
      expect(
        container.read(transaksiControllerProvider).requireValue.cartItems,
        isEmpty,
      );
    },
  );
}
