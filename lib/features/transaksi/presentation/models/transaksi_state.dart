import '../../domain/entities/transaksi_cart_item.dart';
import '../../domain/entities/transaksi_item.dart';
import '../../domain/entities/transaction_validation.dart';

enum TaxMode { automatic, manual }

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
    this.taxMode = TaxMode.automatic,
    this.cashPaidAmount,
    this.isSubmitting = false,
    this.catalogRefreshFailed = false,
    this.isRefreshingCatalog = false,
    this.employeeId,
  });

  final List<TransaksiItem> catalogItems;
  final List<TransaksiItem> filteredItems;
  final List<TransaksiCartItem> cartItems;
  final String searchQuery;
  final String typeFilter;
  final String paymentMethod;
  final double orderDiscountAmount;
  final double taxAmount;
  final TaxMode taxMode;
  final double? cashPaidAmount;
  final bool isSubmitting;
  final bool catalogRefreshFailed;
  final bool isRefreshingCatalog;
  final int? employeeId;

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

    final change = (cashPaidAmount ?? 0) - totalAmount;
    return change.isFinite ? change : 0;
  }

  String? get validationError => TransactionValidation.error(
    items: cartItems,
    orderDiscount: orderDiscountAmount,
    tax: taxAmount,
    paymentMethod: paymentMethod,
    cashPaid: cashPaidAmount,
  );

  bool get canSubmit => !isSubmitting && validationError == null;

  TransaksiState copyWith({
    List<TransaksiItem>? catalogItems,
    List<TransaksiItem>? filteredItems,
    List<TransaksiCartItem>? cartItems,
    String? searchQuery,
    String? typeFilter,
    String? paymentMethod,
    double? orderDiscountAmount,
    double? taxAmount,
    TaxMode? taxMode,
    double? cashPaidAmount,
    bool resetCashPaidAmount = false,
    bool? isSubmitting,
    bool? catalogRefreshFailed,
    bool? isRefreshingCatalog,
    int? employeeId,
    bool resetEmployeeId = false,
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
      taxMode: taxMode ?? this.taxMode,
      cashPaidAmount: resetCashPaidAmount
          ? null
          : cashPaidAmount ?? this.cashPaidAmount,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      catalogRefreshFailed: catalogRefreshFailed ?? this.catalogRefreshFailed,
      isRefreshingCatalog: isRefreshingCatalog ?? this.isRefreshingCatalog,
      employeeId: resetEmployeeId ? null : employeeId ?? this.employeeId,
    );
  }
}
