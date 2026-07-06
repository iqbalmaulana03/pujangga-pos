import '../../domain/entities/transaksi_cart_item.dart';
import '../../domain/entities/transaksi_item.dart';

class TransaksiState {
  const TransaksiState({
    this.catalogItems = const [],
    this.filteredItems = const [],
    this.cartItems = const [],
    this.searchQuery = '',
    this.typeFilter = 'semua',
    this.paymentMethod = 'tunai',
    this.orderDiscountAmount = 0,
    this.taxAmount = 0,
    this.cashPaidAmount,
    this.isSubmitting = false,
  });

  final List<TransaksiItem> catalogItems;
  final List<TransaksiItem> filteredItems;
  final List<TransaksiCartItem> cartItems;
  final String searchQuery;
  final String typeFilter;
  final String paymentMethod;
  final double orderDiscountAmount;
  final double taxAmount;
  final double? cashPaidAmount;
  final bool isSubmitting;

  double get subtotalAmount =>
      cartItems.fold(0, (total, item) => total + item.lineSubtotal);
  double get itemDiscountAmount =>
      cartItems.fold(0, (total, item) => total + item.itemDiscountAmount);
  double get totalAmount =>
      subtotalAmount - itemDiscountAmount - orderDiscountAmount + taxAmount;
  double get changeAmount {
    if (paymentMethod != 'tunai') {
      return 0;
    }

    final paid = cashPaidAmount ?? 0;
    return paid - totalAmount;
  }

  bool get canSubmit {
    if (cartItems.isEmpty || totalAmount < 0) {
      return false;
    }

    if (paymentMethod == 'tunai') {
      return (cashPaidAmount ?? 0) >= totalAmount;
    }

    return true;
  }

  TransaksiState copyWith({
    List<TransaksiItem>? catalogItems,
    List<TransaksiItem>? filteredItems,
    List<TransaksiCartItem>? cartItems,
    String? searchQuery,
    String? typeFilter,
    String? paymentMethod,
    double? orderDiscountAmount,
    double? taxAmount,
    double? cashPaidAmount,
    bool resetCashPaidAmount = false,
    bool? isSubmitting,
  }) {
    return TransaksiState(
      catalogItems: catalogItems ?? this.catalogItems,
      filteredItems: filteredItems ?? this.filteredItems,
      cartItems: cartItems ?? this.cartItems,
      searchQuery: searchQuery ?? this.searchQuery,
      typeFilter: typeFilter ?? this.typeFilter,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      orderDiscountAmount: orderDiscountAmount ?? this.orderDiscountAmount,
      taxAmount: taxAmount ?? this.taxAmount,
      cashPaidAmount: resetCashPaidAmount
          ? null
          : cashPaidAmount ?? this.cashPaidAmount,
      isSubmitting: isSubmitting ?? this.isSubmitting,
    );
  }
}
