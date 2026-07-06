import 'transaksi_item.dart';

class TransaksiCartItem {
  const TransaksiCartItem({
    required this.item,
    required this.quantity,
    required this.itemDiscountAmount,
  });

  final TransaksiItem item;
  final int quantity;
  final double itemDiscountAmount;

  double get lineSubtotal => item.sellingPrice * quantity;
  double get lineTotal => lineSubtotal - itemDiscountAmount;

  TransaksiCartItem copyWith({
    TransaksiItem? item,
    int? quantity,
    double? itemDiscountAmount,
  }) {
    return TransaksiCartItem(
      item: item ?? this.item,
      quantity: quantity ?? this.quantity,
      itemDiscountAmount: itemDiscountAmount ?? this.itemDiscountAmount,
    );
  }
}
