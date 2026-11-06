import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pujangga_pos/core/errors/app_exception.dart';
import 'package:pujangga_pos/features/pengaturan/domain/entities/app_settings.dart';
import 'package:pujangga_pos/features/pengaturan/presentation/controllers/pengaturan_settings_controller.dart';
import 'package:pujangga_pos/features/transaksi/domain/entities/transaksi_item.dart';
import 'package:pujangga_pos/features/transaksi/domain/entities/transaksi_receipt.dart';
import 'package:pujangga_pos/features/transaksi/domain/entities/transaksi_submit_request.dart';
import 'package:pujangga_pos/features/transaksi/domain/repositories/transaction_repository.dart';
import 'package:pujangga_pos/features/transaksi/presentation/controllers/transaksi_controller.dart';

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
  bool failSave = false;
  Completer<void>? saveGate;

  @override
  Future<List<TransaksiItem>> getCatalogItems() async {
    reads++;
    if (reads > 1 && failRefresh) throw StateError('Injected catalog fault');
    return [item];
  }

  @override
  Future<TransaksiReceipt> saveTransaction(
    TransaksiSubmitRequest request,
  ) async {
    requests.add(request);
    await saveGate?.future;
    if (failSave) throw StateError('Injected save fault');
    return TransaksiReceipt(
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
      null;
}

void main() {
  late FaultRepository repository;
  late ProviderContainer container;

  setUp(() async {
    // Repository and settings are fully overridden: no runtime DB or services.
    repository = FaultRepository();
    container = ProviderContainer(
      overrides: [
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
      await expectLater(controller.submit(), throwsA(isA<AppException>()));
      await controller
          .refreshCatalog(); // A second failed refresh is also safe.
      repository.failRefresh = false;
      await controller.refreshCatalog();
      state = container.read(transaksiControllerProvider).requireValue;
      expect(state.catalogItems, [item]);
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
