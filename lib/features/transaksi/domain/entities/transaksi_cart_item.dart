import '../../../../core/utils/scaled_arithmetic.dart';
import 'transaksi_item.dart';

class TransaksiCartItem {
  const TransaksiCartItem({
    required this.item,
    required this.quantity,
    required this.itemDiscountAmount,
    this.currencyCode = 'IDR',
    this.savedLineSubtotal,
    this.savedLineTotal,
  });

  final TransaksiItem item;
  final double quantity;
  final double itemDiscountAmount;
  final String currencyCode;
  // Historical receipts use stored snapshots, independent of current settings.
  final double? savedLineSubtotal;
  final double? savedLineTotal;

  double get unitPrice {
    if (item.wholesalePrice != null &&
        item.wholesaleMinQuantity != null &&
        ScaledArithmetic.quantityUnits(quantity) >=
            ScaledArithmetic.quantityUnits(item.wholesaleMinQuantity!)) {
      return item.wholesalePrice!;
    }
    return item.sellingPrice;
  }

  int subtotalUnits(String currency) =>
      ScaledArithmetic.lineSubtotal(unitPrice, quantity, currency);
  int totalUnits(String currency) => ScaledArithmetic.sum([
    subtotalUnits(currency),
    -ScaledArithmetic.moneyUnits(itemDiscountAmount, currency),
  ]);
  double get lineSubtotal =>
      savedLineSubtotal ??
      ScaledArithmetic.valueOf(
        subtotalUnits(currencyCode),
        ScaledArithmetic.moneyDigits(currencyCode),
      );
  double get lineTotal =>
      savedLineTotal ??
      ScaledArithmetic.valueOf(
        totalUnits(currencyCode),
        ScaledArithmetic.moneyDigits(currencyCode),
      );

  TransaksiCartItem copyWith({
    TransaksiItem? item,
    double? quantity,
    double? itemDiscountAmount,
    String? currencyCode,
  }) {
    return TransaksiCartItem(
      item: item ?? this.item,
      quantity: quantity ?? this.quantity,
      itemDiscountAmount: itemDiscountAmount ?? this.itemDiscountAmount,
      currencyCode: currencyCode ?? this.currencyCode,
    );
  }
}
