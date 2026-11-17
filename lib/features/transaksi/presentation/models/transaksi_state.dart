import '../../domain/entities/transaksi_cart_item.dart';
import '../../domain/entities/transaksi_item.dart';
import '../../domain/services/transaction_calculator.dart';
import '../../../../core/utils/scaled_arithmetic.dart';

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
    this.currencyCode = 'IDR',
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
  final String currencyCode;

  TransactionCalculation get calculation => TransactionCalculation(
    items: cartItems,
    currencyCode: currencyCode,
    orderDiscount: orderDiscountAmount,
    tax: taxAmount,
    paid: cashPaidAmount,
  );
  double get subtotalAmount => calculation.amount(calculation.subtotal);
  double get itemDiscountAmount => calculation.amount(calculation.itemDiscount);
  double get totalAmount => calculation.amount(calculation.total);
  double get changeAmount {
    if (paymentMethod != 'tunai') {
      return 0;
    }

    return calculation.amount(calculation.change);
  }

  bool get canSubmit {
    if (isSubmitting || cartItems.isEmpty) {
      return false;
    }
    try {
      final value = calculation;
      if (value.total < 0 ||
          value.net < 0 ||
          orderDiscountAmount < 0 ||
          taxAmount < 0 ||
          cartItems.any(
            (line) =>
                !line.quantity.isFinite ||
                line.quantity <= 0 ||
                ScaledArithmetic.inputQuantity(line.quantity) <= 0 ||
                !line.unitPrice.isFinite ||
                line.unitPrice < 0 ||
                !line.itemDiscountAmount.isFinite ||
                line.itemDiscountAmount < 0 ||
                line.totalUnits(currencyCode) < 0,
          )) {
        return false;
      }
      return paymentMethod != 'tunai' || value.paidUnits >= value.total;
    } on FormatException {
      return false;
    }
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
    TaxMode? taxMode,
    double? cashPaidAmount,
    bool resetCashPaidAmount = false,
    bool? isSubmitting,
    bool? catalogRefreshFailed,
    bool? isRefreshingCatalog,
    int? employeeId,
    bool resetEmployeeId = false,
    String? currencyCode,
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
      currencyCode: currencyCode ?? this.currencyCode,
    );
  }
}
