import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pujangga_pos/core/services/app_startup_service.dart';
import 'package:pujangga_pos/core/utils/quantity_formatter.dart';
import 'package:pujangga_pos/core/utils/scaled_arithmetic.dart';
import 'package:pujangga_pos/features/pengaturan/domain/entities/app_settings.dart';
import 'package:pujangga_pos/features/pengaturan/presentation/controllers/pengaturan_settings_controller.dart';
import 'package:pujangga_pos/features/transaksi/domain/entities/transaksi_cart_item.dart';
import 'package:pujangga_pos/features/transaksi/domain/entities/transaksi_item.dart';
import 'package:pujangga_pos/features/transaksi/presentation/controllers/transaksi_controller.dart';
import 'package:pujangga_pos/features/transaksi/presentation/models/transaksi_state.dart';

import 'transaksi_controller_test.dart' show MockTransactionRepository;

void main() {
  test('quantity operations eliminate repeated decimal residues', () {
    var quantity = 0.1;
    for (var i = 0; i < 2; i++) {
      quantity = ScaledArithmetic.addQuantity(quantity, 0.1);
    }
    expect(quantity, 0.3);
    quantity = 1;
    for (var i = 0; i < 10; i++) {
      quantity = ScaledArithmetic.addQuantity(quantity, -0.1);
    }
    expect(quantity, 0);
    expect(ScaledArithmetic.quantity(0.30000000000000004), 0.3);
    expect(QuantityFormatter.parse('0,001'), 0.001);
    expect(QuantityFormatter.parse('0.0001'), isNull);
    expect(() => ScaledArithmetic.inputQuantity(0.1234), throwsFormatException);
    expect(ScaledArithmetic.inputQuantity(0.1 + 0.1 + 0.1), 0.3);
    expect(ScaledArithmetic.quantityUnits(1e-3), 1);
    expect(() => ScaledArithmetic.units(1e20, 0), throwsFormatException);
  });

  for (final currency in ['IDR', 'USD', 'SGD']) {
    final digits = ScaledArithmetic.moneyDigits(currency);
    final factor = currency == 'IDR' ? 1 : 100;
    test(
      '$currency rounds positive and negative half units away from zero',
      () {
        for (final sign in [-1, 1]) {
          expect(
            ScaledArithmetic.moneyUnits(sign * 1.5 / factor, currency),
            sign * 2,
          );
          expect(
            ScaledArithmetic.moneyUnits(sign * 1.49999 / factor, currency),
            sign,
          );
          expect(
            ScaledArithmetic.moneyUnits(sign * 1.50001 / factor, currency),
            sign * 2,
          );
          expect(ScaledArithmetic.percentage(sign * 145, 10), sign * 15);
        }
        expect(ScaledArithmetic.valueOf(3, digits), 3 / factor);
      },
    );
    test('$currency rounds each fractional line before summing', () {
      final item = TransaksiItem(
        id: '1',
        name: 'Test',
        category: '',
        itemType: 'jasa',
        sellingPrice: 1 / factor,
        isActive: true,
      );
      final state = TransaksiState(
        currencyCode: currency,
        cartItems: [
          TransaksiCartItem(
            item: item,
            quantity: 0.5,
            itemDiscountAmount: 0,
            currencyCode: currency,
          ),
          TransaksiCartItem(
            item: item,
            quantity: 0.5,
            itemDiscountAmount: 0,
            currencyCode: currency,
          ),
        ],
        cashPaidAmount: 2 / factor,
      );
      expect(state.subtotalAmount, 2 / factor);
      expect(state.canSubmit, isTrue);
      expect(state.changeAmount, 0);
      expect(state.copyWith(cashPaidAmount: 1 / factor).canSubmit, isFalse);
    });
  }

  test('invalid or unsafe numeric values cannot enable checkout', () {
    for (final value in [
      double.nan,
      double.infinity,
      -double.infinity,
      1e100,
    ]) {
      expect(
        () => ScaledArithmetic.quantityUnits(value),
        throwsFormatException,
      );
      const item = TransaksiItem(
        id: '1',
        name: '',
        category: '',
        itemType: 'jasa',
        sellingPrice: 1,
        isActive: true,
      );
      expect(
        TransaksiState(
          cartItems: const [
            TransaksiCartItem(item: item, quantity: 1, itemDiscountAmount: 0),
          ],
          cashPaidAmount: value,
        ).canSubmit,
        isFalse,
      );
    }
    expect(
      () => ScaledArithmetic.sum([ScaledArithmetic.maxUnits, 1]),
      throwsFormatException,
    );
  });

  test('wholesale threshold uses normalized quantity and price multiplies before rounding', () {
    const item = TransaksiItem(
      id: '1',
      name: '',
      category: '',
      itemType: 'barang',
      sellingPrice: 1.45,
      wholesalePrice: 0.1,
      wholesaleMinQuantity: 1,
      isActive: true,
    );
    const below = TransaksiCartItem(
      item: item,
      quantity: 0.999,
      itemDiscountAmount: 0,
      currencyCode: 'USD',
    );
    const at = TransaksiCartItem(
      item: item,
      quantity: 0.9999999999999999,
      itemDiscountAmount: 0,
      currencyCode: 'USD',
    );
    expect(below.unitPrice, 1.45);
    expect(below.lineSubtotal, 1.45);
    expect(at.unitPrice, 0.1);
    expect(at.lineSubtotal, 0.1);
    expect(ScaledArithmetic.lineSubtotal(1.45, 0.5, 'IDR'), 1);
  });

  test(
    'controller removes the tenth decrement and accepts exact USD payment',
    () async {
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWith(
            (ref) => throw StateError('Real database forbidden'),
          ),
          transactionRepositoryProvider.overrideWithValue(
            MockTransactionRepository(),
          ),
          appSettingsProvider.overrideWith(
            (ref) async => const AppSettings(
              currencyCode: 'USD',
              currencySymbol: r'$',
              defaultTaxPercent: 0,
              stockAllowNegative: false,
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      final sub = container.listen(transaksiControllerProvider, (_, _) {});
      addTearDown(sub.close);
      await container.read(appSettingsProvider.future);
      await container.read(transaksiControllerProvider.future);
      final controller = container.read(transaksiControllerProvider.notifier);
      const item = TransaksiItem(
        id: '1',
        name: '',
        category: '',
        itemType: 'barang',
        sellingPrice: 0.1,
        unitLabel: 'kg',
        stockQuantity: 0.3,
        isActive: true,
      );
      controller.addItem(item);
      for (var i = 0; i < 10; i++) {
        controller.decreaseQuantity(item.id);
      }
      expect(
        container.read(transaksiControllerProvider).requireValue.cartItems,
        isEmpty,
      );
      controller.addItem(item);
      controller.setQuantity(item.id, 0.1);
      controller.increaseQuantity(item.id);
      controller.addItem(item);
      expect(
        container
            .read(transaksiControllerProvider)
            .requireValue
            .cartItems
            .single
            .quantity,
        0.3,
      );
      controller.setQuantity(item.id, 3);
      controller.updateCashPaid(0.3);
      final state = container.read(transaksiControllerProvider).requireValue;
      expect(state.totalAmount, 0.3);
      expect(state.changeAmount, 0);
      expect(state.canSubmit, isTrue);
    },
  );
}
