import '../../../../core/utils/scaled_arithmetic.dart';
import '../entities/transaksi_cart_item.dart';

/// Shared checkout calculation for preview and the atomic persistence path.
class TransactionCalculation {
  TransactionCalculation({
    required List<TransaksiCartItem> items,
    required this.currencyCode,
    required double orderDiscount,
    required double tax,
    double? paid,
  }) {
    subtotal = ScaledArithmetic.sum(
      items.map((item) => item.subtotalUnits(currencyCode)),
    );
    itemDiscount = ScaledArithmetic.sum(
      items.map(
        (item) =>
            ScaledArithmetic.moneyUnits(item.itemDiscountAmount, currencyCode),
      ),
    );
    orderDiscountUnits = ScaledArithmetic.moneyUnits(
      orderDiscount,
      currencyCode,
    );
    taxUnits = ScaledArithmetic.moneyUnits(tax, currencyCode);
    paidUnits = ScaledArithmetic.moneyUnits(paid ?? 0, currencyCode);
    net = ScaledArithmetic.sum([subtotal, -itemDiscount, -orderDiscountUnits]);
    total = ScaledArithmetic.sum([net, taxUnits]);
    change = ScaledArithmetic.sum([paidUnits, -total]);
  }

  final String currencyCode;
  late final int subtotal,
      itemDiscount,
      orderDiscountUnits,
      taxUnits,
      paidUnits,
      net,
      total,
      change;
  double amount(int units) => ScaledArithmetic.valueOf(
    units,
    ScaledArithmetic.moneyDigits(currencyCode),
  );
}
