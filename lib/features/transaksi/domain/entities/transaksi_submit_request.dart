import 'transaksi_cart_item.dart';

class TransaksiSubmitRequest {
  const TransaksiSubmitRequest({
    required this.items,
    required this.orderDiscountAmount,
    required this.taxAmount,
    required this.paymentMethod,
    this.cashPaidAmount,
  });

  final List<TransaksiCartItem> items;
  final double orderDiscountAmount;
  final double taxAmount;
  final String paymentMethod;
  final double? cashPaidAmount;
}
