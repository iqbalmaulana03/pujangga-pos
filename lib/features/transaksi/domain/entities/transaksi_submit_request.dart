import 'dart:math';

import 'transaksi_cart_item.dart';

class TransaksiSubmitRequest {
  TransaksiSubmitRequest({
    required this.items,
    required this.orderDiscountAmount,
    required this.taxAmount,
    required this.paymentMethod,
    this.employeeId,
    this.cashPaidAmount,
    String? checkoutId,
  }) : checkoutId = checkoutId ?? _newCheckoutId();

  // Independent of invoice generation; retries of this request keep this key.
  static String _newCheckoutId() {
    final random = Random.secure();
    return List.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
  }

  final String checkoutId;

  final List<TransaksiCartItem> items;
  final double orderDiscountAmount;
  final double taxAmount;
  final String paymentMethod;
  final int? employeeId;
  final double? cashPaidAmount;
}
