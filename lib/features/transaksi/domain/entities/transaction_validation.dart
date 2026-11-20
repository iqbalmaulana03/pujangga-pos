import '../../../../core/errors/app_exception.dart';
import 'transaksi_cart_item.dart';
import '../../../../core/utils/scaled_arithmetic.dart';
import '../services/transaction_calculator.dart';

/// Shared checkout rules, also enforced at the persistence boundary.
class TransactionValidation {
  TransactionValidation._();

  static String? error({
    required List<TransaksiCartItem> items,
    required double orderDiscount,
    required double tax,
    required String paymentMethod,
    String currencyCode = 'IDR',
    double? cashPaid,
  }) {
    bool valid(double value) => value.isFinite && value >= 0;
    if (items.isEmpty) return 'Keranjang transaksi masih kosong.';
    try {
      for (final line in items) {
        if (!valid(line.quantity) ||
            ScaledArithmetic.inputQuantity(line.quantity) <= 0 ||
            !valid(line.unitPrice) ||
            !valid(line.itemDiscountAmount) ||
            line.totalUnits(currencyCode) < 0) {
          return 'Harga, kuantitas, atau diskon item tidak valid.';
        }
      }
      if (!valid(orderDiscount) || !valid(tax)) {
        return 'Subtotal, diskon, atau pajak transaksi tidak valid.';
      }
      final value = TransactionCalculation(
        items: items,
        currencyCode: currencyCode,
        orderDiscount: orderDiscount,
        tax: tax,
        paid: paymentMethod == 'tunai' ? cashPaid : null,
      );
      if (value.net < 0 || value.total < 0) {
        return 'Total transaksi tidak valid.';
      }
      // Validate conversion of all persisted totals to REAL before any writes.
      for (final amount in [
        value.subtotal,
        value.itemDiscount,
        ScaledArithmetic.sum([value.itemDiscount, value.orderDiscountUnits]),
        value.orderDiscountUnits,
        value.taxUnits,
        value.total,
        value.paidUnits,
        value.change,
      ]) {
        value.amount(amount);
      }
      if (paymentMethod == 'tunai' &&
          (cashPaid == null || !valid(cashPaid) || value.change < 0)) {
        return 'Nominal pembayaran harus valid dan mencukupi total.';
      }
      return null;
    } on FormatException {
      return 'Angka tidak valid atau melampaui batas presisi yang aman.';
    }
  }

  static void requireFinite(double? value) {
    if (value != null && !value.isFinite) {
      throw const AppException(
        'validation_error',
        'Nominal harus berupa angka yang valid.',
      );
    }
  }
}
