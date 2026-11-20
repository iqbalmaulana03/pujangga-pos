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
    try {
      if (item.wholesalePrice != null &&
          item.wholesaleMinQuantity != null &&
          ScaledArithmetic.quantityUnits(quantity) >=
              ScaledArithmetic.quantityUnits(item.wholesaleMinQuantity!)) {
        return item.wholesalePrice!;
      }
    } on FormatException {
      // Validation rejects this draft; its UI must remain renderable.
    }
    return item.sellingPrice;
  }

  int subtotalUnits(String currency) =>
      ScaledArithmetic.lineSubtotal(unitPrice, quantity, currency);
  int totalUnits(String currency) => ScaledArithmetic.sum([
    subtotalUnits(currency),
    -ScaledArithmetic.moneyUnits(itemDiscountAmount, currency),
  ]);
  double _amount(int Function() calculate) {
    try {
      return ScaledArithmetic.valueOf(
        calculate(),
        ScaledArithmetic.moneyDigits(currencyCode),
      );
    } on FormatException {
      return double.nan;
    }
  }

  double get lineSubtotal =>
      savedLineSubtotal ?? _amount(() => subtotalUnits(currencyCode));
  double get lineTotal =>
      savedLineTotal ?? _amount(() => totalUnits(currencyCode));

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
