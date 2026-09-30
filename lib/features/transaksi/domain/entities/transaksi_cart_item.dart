import 'transaksi_item.dart';

class TransaksiCartItem {
  const TransaksiCartItem({
    required this.item,
    required this.quantity,
    required this.itemDiscountAmount,
  });

  final TransaksiItem item;
  final double quantity;
  final double itemDiscountAmount;

  double get unitPrice {
    if (item.wholesalePrice != null &&
        item.wholesaleMinQuantity != null &&
        quantity >= item.wholesaleMinQuantity!) {
      return item.wholesalePrice!;
    }
    return item.sellingPrice;
  }

  double get lineSubtotal => unitPrice * quantity;
  double get lineTotal => lineSubtotal - itemDiscountAmount;

  TransaksiCartItem copyWith({
    TransaksiItem? item,
    double? quantity,
    double? itemDiscountAmount,
  }) {
    return TransaksiCartItem(
      item: item ?? this.item,
      quantity: quantity ?? this.quantity,
      itemDiscountAmount: itemDiscountAmount ?? this.itemDiscountAmount,
    );
  }
}
