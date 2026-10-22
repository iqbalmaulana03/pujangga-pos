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
    this.status = 'completed',
    this.cashPaidAmount,
    this.employeeName,
    this.compensationType,
    this.commissionPercent,
    this.commissionScope = 'all',
    this.commissionAmount = 0,
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
  final String status;
  final double? cashPaidAmount;
  final List<TransaksiCartItem> items;
  final String? employeeName;
  final String? compensationType;
  final double? commissionPercent;
  final String commissionScope;
  String get commissionScopeLabel => switch (commissionScope) {
    'service' => 'Jasa saja',
    'product' => 'Barang saja',
    _ => 'Barang dan jasa',
  };
  final double commissionAmount;
}
