import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pujangga_pos/core/services/app_startup_service.dart';
import 'package:pujangga_pos/features/pengaturan/domain/entities/app_settings.dart';
import 'package:pujangga_pos/features/pengaturan/presentation/controllers/pengaturan_settings_controller.dart';
import 'package:pujangga_pos/features/transaksi/domain/entities/transaksi_item.dart';
import 'package:pujangga_pos/features/transaksi/domain/entities/transaksi_receipt.dart';
import 'package:pujangga_pos/features/transaksi/domain/entities/transaksi_submit_request.dart';
import 'package:pujangga_pos/features/transaksi/presentation/controllers/transaksi_controller.dart';
import 'package:pujangga_pos/features/transaksi/presentation/models/transaksi_state.dart';

import 'transaksi_controller_test.dart' show MockTransactionRepository;

// No device storage: repository writes are captured in memory, and opening the
// application's database is explicitly forbidden by the provider override.
class _Repository extends MockTransactionRepository {
  TransaksiSubmitRequest? saved;

  @override
  Future<TransaksiReceipt> saveTransaction(
    TransaksiSubmitRequest request,
  ) async {
    saved = request;
    final subtotal = request.items.fold<double>(
      0,
      (t, i) => t + i.lineSubtotal,
    );
    final discounts = request.items.fold<double>(
      0,
      (t, i) => t + i.itemDiscountAmount,
    );
    return TransaksiReceipt(
      invoiceNumber: 'TAX-TEST',
      createdAt: DateTime(2026),
      paymentMethod: request.paymentMethod,
      subtotalAmount: subtotal,
      itemDiscountAmount: discounts,
      orderDiscountAmount: request.orderDiscountAmount,
      taxAmount: request.taxAmount,
      totalAmount:
          subtotal -
          discounts -
          request.orderDiscountAmount +
          request.taxAmount,
      cashPaidAmount: request.cashPaidAmount,
      changeAmount: 0,
      items: request.items,
    );
  }
}

void main() {
  for (final currency in ['IDR', 'USD', 'SGD']) {
    group(currency, () {
      late ProviderContainer container;
      late TransaksiController controller;
      late _Repository repository;
      final scale = currency == 'IDR' ? 1000.0 : 1.0;
      final item = TransaksiItem(
        id: 'tax-item',
        name: 'Jasa',
        category: 'Jasa',
        itemType: 'jasa',
        sellingPrice: 100 * scale,
        isActive: true,
      );
      TransaksiState current() =>
          container.read(transaksiControllerProvider).requireValue;

      setUp(() async {
        repository = _Repository();
        container = ProviderContainer(
          overrides: [
            appDatabaseProvider.overrideWith(
              (ref) => throw StateError('No database in tax tests'),
            ),
            transactionRepositoryProvider.overrideWithValue(repository),
            appSettingsProvider.overrideWith(
              (ref) async => AppSettings(
                currencyCode: currency,
                currencySymbol: currency == 'IDR' ? 'Rp' : r'$',
                defaultTaxPercent: 10,
                stockAllowNegative: false,
              ),
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
        controller.addItem(item);
      });

      test(
        'item and order discounts have identical tax and payable totals',
        () {
          expect(current().taxAmount, 10 * scale);
          controller.updateItemDiscount(item.id, 20 * scale);
          expect(current().taxAmount, 8 * scale);
          expect(current().totalAmount, 88 * scale);
          controller.updateItemDiscount(item.id, 0);
          expect(current().taxAmount, 10 * scale);
          controller.updateOrderDiscount(20 * scale);
          expect(current().taxAmount, 8 * scale);
          expect(current().totalAmount, 88 * scale);
          controller.updateOrderDiscount(0);
          expect(current().taxAmount, 10 * scale);
        },
      );

      test(
        'combined discounts, quantity edits and removal recalculate the base',
        () {
          controller.updateItemDiscount(item.id, 10 * scale);
          controller.updateOrderDiscount(20 * scale);
          expect(current().taxAmount, 7 * scale);
          controller.increaseQuantity(item.id);
          expect(current().taxAmount, 17 * scale);
          controller.decreaseQuantity(item.id);
          expect(current().taxAmount, 7 * scale);
          controller.setQuantity(item.id, 3);
          expect(current().taxAmount, 27 * scale);
          controller.addItem(item);
          expect(current().taxAmount, 37 * scale);
          controller.removeItem(item.id);
          expect(current().taxAmount, 0);
        },
      );

      test(
        'full and excessive discounts never produce negative automatic tax',
        () {
          controller.updateOrderDiscount(100 * scale);
          expect(current().taxAmount, 0);
          expect(current().totalAmount, 0);
          controller.updateOrderDiscount(110 * scale);
          expect(current().taxAmount, 0);
          expect(current().canSubmit, isFalse);
          controller.updateOrderDiscount(0);
          controller.updateItemDiscount(item.id, 100 * scale);
          expect(current().taxAmount, 0);
          expect(current().totalAmount, 0);
          controller.updateItemDiscount(item.id, 0);
          expect(current().taxAmount, 10 * scale);
        },
      );

      for (final manualTax in [0.0, 7.0]) {
        test('manual tax $manualTax survives all base changes until reset', () {
          controller.updateTaxAmount(manualTax);
          expect(current().taxMode, TaxMode.manual);
          final mutations = <void Function()>[
            () => controller.updateOrderDiscount(20 * scale),
            () => controller.updateItemDiscount(item.id, 10 * scale),
            () => controller.increaseQuantity(item.id),
            () => controller.decreaseQuantity(item.id),
            () => controller.setQuantity(item.id, 3),
            () => controller.removeItem(item.id),
            () => controller.addItem(item),
          ];
          for (final mutate in mutations) {
            mutate();
            expect(current().taxAmount, manualTax);
            expect(current().taxMode, TaxMode.manual);
          }
          controller.useAutomaticTax();
          expect(current().taxMode, TaxMode.automatic);
          expect(current().taxAmount, 8 * scale);
          controller.updateTaxAmount(manualTax);
          controller.clearCart();
          expect(current().taxMode, TaxMode.automatic);
          expect(current().taxAmount, 0);
          controller.addItem(item);
          expect(current().taxAmount, 10 * scale);
        });
      }

      test('discounted tax rounds half units using currency precision', () {
        controller.clearCart();
        final halfUnitItem = TransaksiItem(
          id: 'half',
          name: 'Half',
          category: 'Jasa',
          itemType: 'jasa',
          sellingPrice: currency == 'IDR' ? 200 : 2,
          isActive: true,
        );
        controller.addItem(halfUnitItem);
        controller.updateOrderDiscount(currency == 'IDR' ? 55 : 0.55);
        expect(current().taxAmount, currency == 'IDR' ? 15 : 0.15);
        controller.updateOrderDiscount(0);
        controller.updateItemDiscount(
          halfUnitItem.id,
          currency == 'IDR' ? 55 : 0.55,
        );
        expect(current().taxAmount, currency == 'IDR' ? 15 : 0.15);
      });

      test(
        'submit forwards final automatic and manual tax and resets the next sale',
        () async {
          controller.updateOrderDiscount(20 * scale);
          controller.updatePaymentMethod('qris');
          final receipt = await controller.submit();
          expect(repository.saved!.taxAmount, 8 * scale);
          expect(receipt.totalAmount, 88 * scale);
          controller.addItem(item);
          controller.updateTaxAmount(7);
          controller.updateOrderDiscount(20 * scale);
          controller.updatePaymentMethod('qris');
          await controller.submit();
          expect(repository.saved!.taxAmount, 7);
          expect(current().taxMode, TaxMode.automatic);
          controller.addItem(item);
          expect(current().taxAmount, 10 * scale);
        },
      );
    });
  }
}
