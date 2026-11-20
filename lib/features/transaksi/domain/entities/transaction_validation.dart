import '../../../../core/errors/app_exception.dart';
import 'transaksi_cart_item.dart';

/// Shared checkout rules, also enforced at the persistence boundary.
class TransactionValidation {
  TransactionValidation._();

  static String? error({
    required List<TransaksiCartItem> items,
    required double orderDiscount,
    required double tax,
    required String paymentMethod,
    double? cashPaid,
  }) {
    bool valid(double value) => value.isFinite && value >= 0;
    if (items.isEmpty) return 'Keranjang transaksi masih kosong.';
    double subtotal = 0;
    double discounts = 0;
    for (final line in items) {
      if (!valid(line.quantity) ||
          line.quantity == 0 ||
          !valid(line.unitPrice) ||
          !valid(line.lineSubtotal) ||
          !valid(line.itemDiscountAmount) ||
          line.itemDiscountAmount > line.lineSubtotal ||
          !valid(line.lineTotal)) {
        return 'Harga, kuantitas, atau diskon item tidak valid.';
      }
      subtotal += line.lineSubtotal;
      discounts += line.itemDiscountAmount;
    }
    if (!valid(subtotal) ||
        !valid(discounts) ||
        !valid(orderDiscount) ||
        orderDiscount > subtotal - discounts ||
        !valid(tax) ||
        !valid(discounts + orderDiscount)) {
      return 'Subtotal, diskon, atau pajak transaksi tidak valid.';
    }
    final total = subtotal - discounts - orderDiscount + tax;
    if (!valid(total)) return 'Total transaksi tidak valid.';
    if (paymentMethod == 'tunai' &&
        (cashPaid == null ||
            !valid(cashPaid) ||
            cashPaid < total ||
            !valid(cashPaid - total))) {
      return 'Nominal pembayaran harus valid dan mencukupi total.';
    }
    return null;
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
