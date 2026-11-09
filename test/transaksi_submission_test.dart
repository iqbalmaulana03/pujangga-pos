import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pujangga_pos/core/errors/app_exception.dart';
import 'package:pujangga_pos/core/services/app_startup_service.dart';
import 'package:pujangga_pos/features/pengaturan/domain/entities/app_settings.dart';
import 'package:pujangga_pos/features/pengaturan/presentation/controllers/pengaturan_settings_controller.dart';
import 'package:pujangga_pos/features/transaksi/domain/entities/transaksi_item.dart';
import 'package:pujangga_pos/features/transaksi/domain/entities/transaksi_receipt.dart';
import 'package:pujangga_pos/features/transaksi/domain/entities/transaksi_submit_request.dart';
import 'package:pujangga_pos/features/transaksi/domain/repositories/transaction_repository.dart';
import 'package:pujangga_pos/features/transaksi/presentation/controllers/transaksi_controller.dart';
import 'package:pujangga_pos/features/transaksi/presentation/models/transaksi_state.dart';

const _item = TransaksiItem(
  id: 'barang-1',
  name: 'Kopi',
  category: 'Minuman',
  itemType: 'barang',
  sellingPrice: 50000,
  stockQuantity: 12,
  isActive: true,
);

// All persistence stays in memory. Save and refresh can be delayed independently.
class _DelayedRepository implements TransactionRepository {
  final requests = <TransaksiSubmitRequest>[];
  Completer<TransaksiReceipt> save = Completer<TransaksiReceipt>();
  Completer<List<TransaksiItem>>? refresh;

  @override
  Future<List<TransaksiItem>> getCatalogItems() async =>
      refresh == null ? [_item] : await refresh!.future;

  @override
  Future<TransaksiReceipt> saveTransaction(TransaksiSubmitRequest request) {
    requests.add(request);
    return save.future;
  }

  @override
  Future<TransaksiReceipt?> getReceiptByInvoice(String invoiceNumber) async =>
      null;

  TransaksiReceipt receipt() {
    final request = requests.last;
    return TransaksiReceipt(
      invoiceNumber: 'INV-${requests.length}',
      createdAt: DateTime(2026, 11, 7),
      paymentMethod: request.paymentMethod,
      subtotalAmount: 50000,
      itemDiscountAmount: 0,
      orderDiscountAmount: request.orderDiscountAmount,
      taxAmount: request.taxAmount,
      totalAmount: 50000,
      cashPaidAmount: request.cashPaidAmount,
      changeAmount: 0,
      items: request.items,
    );
  }
}

void main() {
  late _DelayedRepository repository;
  late ProviderContainer container;
  late TransaksiController controller;

  TransaksiState current() =>
      container.read(transaksiControllerProvider).requireValue;

  setUp(() async {
    repository = _DelayedRepository();
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
        // Fail immediately if a test accidentally reaches real application storage.
        appDatabaseProvider.overrideWith(
          (ref) => throw StateError('No database in this test'),
        ),
      ],
    );
    addTearDown(container.dispose);
    final subscription = container.listen(
      transaksiControllerProvider,
      (_, _) {},
    );
    addTearDown(subscription.close);
    await container.read(appSettingsProvider.future);
    await container.read(transaksiControllerProvider.future);
    controller = container.read(transaksiControllerProvider.notifier);
    controller.addItem(_item);
    controller.updateCashPaid(50000);
    controller.updateEmployee(7);
  });

  test('input and repeated submit cannot open another pending save', () async {
    final pending = controller.submit();
    final submitting = current();
    expect(submitting.isSubmitting, isTrue);
    expect(submitting.canSubmit, isFalse);

    final mutations = <void Function()>[
      () => controller.updateCashPaid(60000),
      () => controller.updateCashPaid(null),
      () => controller.updatePaymentMethod('qris'),
      () => controller.addItem(_item),
      () => controller.increaseQuantity(_item.id),
      () => controller.decreaseQuantity(_item.id),
      () => controller.setQuantity(_item.id, 5),
      () => controller.setQuantity(_item.id, 0),
      () => controller.removeItem(_item.id),
      controller.clearCart,
      () => controller.updateItemDiscount(_item.id, 1000),
      () => controller.updateOrderDiscount(1000),
      () => controller.updateTaxAmount(1000),
      () => controller.updateEmployee(8),
      () => controller.updateEmployee(null),
      () => controller.updateSearch('Kopi'),
      () => controller.updateFilter('jasa'),
    ];
    for (final mutate in mutations) {
      mutate();
      expect(current(), same(submitting));
      await expectLater(
        controller.submit(),
        throwsA(
          isA<AppException>().having(
            (error) => error.code,
            'code',
            'submit_in_progress',
          ),
        ),
      );
      expect(repository.requests, hasLength(1));
    }
    expect(repository.requests.single.cashPaidAmount, 50000);
    expect(repository.requests.single.employeeId, 7);
    final receipt = repository.receipt();
    repository.save.complete(receipt);
    expect(await pending, same(receipt));
    expect(current().isSubmitting, isFalse);
    expect(current().cartItems, isEmpty);

    // A new checkout is allowed after the first operation has finished.
    controller.addItem(_item);
    controller.updatePaymentMethod('qris');
    repository.save = Completer<TransaksiReceipt>();
    final next = controller.submit();
    expect(repository.requests, hasLength(2));
    expect(
      repository.requests.last.checkoutId,
      isNot(repository.requests.first.checkoutId),
    );
    repository.save.complete(repository.receipt());
    await next;
  });

  test('save failure releases lock and preserves checkout for retry', () async {
    final before = current();
    final pending = controller.submit();
    final failure = StateError('Save failed before commit');
    final assertion = expectLater(pending, throwsA(same(failure)));
    controller.clearCart();
    repository.save.completeError(failure);
    await assertion;

    expect(current().isSubmitting, isFalse);
    expect(current().canSubmit, isTrue);
    expect(current().cartItems, same(before.cartItems));
    expect(current().cashPaidAmount, before.cashPaidAmount);
    expect(current().employeeId, before.employeeId);
    repository.save = Completer<TransaksiReceipt>();
    final unchangedRetry = controller.submit();
    expect(repository.requests, hasLength(2));
    expect(repository.requests.last, same(repository.requests.first));
    final retryFailure = expectLater(unchangedRetry, throwsA(same(failure)));
    repository.save.completeError(failure);
    await retryFailure;
    controller.updateCashPaid(60000);
    expect(current().cashPaidAmount, 60000);

    repository.save = Completer<TransaksiReceipt>();
    final retry = controller.submit();
    expect(repository.requests, hasLength(3));
    expect(
      repository.requests.last.checkoutId,
      isNot(repository.requests.first.checkoutId),
    );
    expect(repository.requests.last.cashPaidAmount, 60000);
    repository.save.complete(repository.receipt());
    await retry;
    expect(current().cartItems, isEmpty);
  });

  test('lock remains held during catalog refresh after save', () async {
    final pending = controller.submit();
    repository.refresh = Completer<List<TransaksiItem>>();
    repository.save.complete(repository.receipt());
    await Future<void>.delayed(Duration.zero);

    controller.updateCashPaid(60000);
    expect(current().isSubmitting, isTrue);
    expect(current().canSubmit, isFalse);
    await expectLater(controller.submit(), throwsA(isA<AppException>()));
    expect(repository.requests, hasLength(1));
    repository.refresh!.complete([_item]);
    await pending;
    expect(current().isSubmitting, isFalse);
  });
}
