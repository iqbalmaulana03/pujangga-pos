import 'transaksi_cart_item.dart';

class TransaksiReceipt {
  const TransaksiReceipt({
    required this.invoiceNumber,
    required this.createdAt,
    required this.paymentMethod,
    required this.subtotalAmount,
    required this.itemDiscountAmount,
    required this.orderDiscountAmount,
    required this.taxAmount,
    required this.totalAmount,
    required this.changeAmount,
    required this.items,
    this.cashPaidAmount,
  });

  final String invoiceNumber;
  final DateTime createdAt;
  final String paymentMethod;
  final double subtotalAmount;
  final double itemDiscountAmount;
  final double orderDiscountAmount;
  final double taxAmount;
  final double totalAmount;
  final double changeAmount;
  final double? cashPaidAmount;
  final List<TransaksiCartItem> items;
}
