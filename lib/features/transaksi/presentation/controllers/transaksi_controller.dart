import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/scaled_arithmetic.dart';

import '../../../pengeluaran/data/repositories/expense_repository.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/services/app_startup_service.dart';
import '../../../../core/services/dataset_generation.dart';
import '../../../laporan/presentation/controllers/laporan_controller.dart';
import '../../../stok/presentation/controllers/stok_controller.dart';
import '../../data/datasources/transaction_local_data_source.dart';
import '../../data/repositories/transaction_repository_impl.dart';
import '../../domain/entities/transaksi_cart_item.dart';
import '../../domain/entities/transaksi_item.dart';
import '../../domain/entities/transaksi_receipt.dart';
import '../../domain/entities/transaksi_submit_request.dart';
import '../../domain/entities/transaction_validation.dart';
import '../../domain/repositories/transaction_repository.dart';
import '../../../pengaturan/presentation/controllers/pengaturan_settings_controller.dart';
import '../models/transaksi_state.dart';

final transactionLocalDataSourceProvider = Provider<TransactionLocalDataSource>(
  (ref) {
    return TransactionLocalDataSource(database: ref.watch(appDatabaseProvider));
  },
);

final transactionRepositoryProvider = Provider<TransactionRepository>((ref) {
  return TransactionRepositoryImpl(
    localDataSource: ref.watch(transactionLocalDataSourceProvider),
  );
});

final transaksiControllerProvider =
    AsyncNotifierProvider.autoDispose<TransaksiController, TransaksiState>(
      TransaksiController.new,
    );

final transaksiReceiptProvider = FutureProvider.autoDispose
    .family<TransaksiReceipt?, String>((ref, invoiceNumber) {
      ref.watch(datasetGenerationProvider);
      return ref
          .watch(transactionRepositoryProvider)
          .getReceiptByInvoice(invoiceNumber);
    });

class TransaksiController extends AsyncNotifier<TransaksiState> {
  bool _submitInProgress = false;
  TransaksiSubmitRequest? _pendingRequest;

  @override
  Future<TransaksiState> build() async {
    ref.watch(datasetGenerationProvider);
    final items = await ref
        .watch(transactionRepositoryProvider)
        .getCatalogItems();
    return _buildState(
      const TransaksiState(catalogItems: []),
      catalogItems: items,
    );
  }

  void updateSearch(String value) {
    final current = _currentState;
    if (current == null) {
      return;
    }

    state = AsyncData(_buildState(current, searchQuery: value));
  }

  void updateFilter(String filter) {
    final current = _currentState;
    if (current == null) {
      return;
    }

    state = AsyncData(_buildState(current, typeFilter: filter));
  }

  void addItem(TransaksiItem item) {
    final current = _currentState;
    if (current == null) {
      return;
    }

    final existingIndex = current.cartItems.indexWhere(
      (cartItem) => cartItem.item.id == item.id,
    );

    final updatedCart = <TransaksiCartItem>[...current.cartItems];
    if (existingIndex == -1) {
      updatedCart.add(
        TransaksiCartItem(item: item, quantity: 1.0, itemDiscountAmount: 0),
      );
    } else {
      final existing = updatedCart[existingIndex];
      final quantity = _adjustQuantity(
        existing.quantity,
        _quantityStep(existing.item),
      );
      if (quantity == null) return;
      updatedCart[existingIndex] = _withQuantity(existing, quantity);
    }

    state = AsyncData(_buildState(current, cartItems: updatedCart));
  }

  void decreaseQuantity(String itemId) {
    final current = _currentState;
    if (current == null) {
      return;
    }

    final updatedCart = <TransaksiCartItem>[];
    for (final cartItem in current.cartItems) {
      if (cartItem.item.id != itemId) {
        updatedCart.add(cartItem);
        continue;
      }

      final quantity = _adjustQuantity(
        cartItem.quantity,
        -_quantityStep(cartItem.item),
      );
      if (quantity == null) {
        updatedCart.add(cartItem);
        continue;
      }
      if (quantity > 0) {
        updatedCart.add(_withQuantity(cartItem, quantity));
      }
    }

    state = AsyncData(_buildState(current, cartItems: updatedCart));
  }

  void increaseQuantity(String itemId) {
    final current = _currentState;
    if (current == null) {
      return;
    }

    final updatedCart = current.cartItems.map((cartItem) {
      if (cartItem.item.id != itemId) {
        return cartItem;
      }

      final quantity = _adjustQuantity(
        cartItem.quantity,
        _quantityStep(cartItem.item),
      );
      if (quantity == null) return cartItem;
      return _withQuantity(cartItem, quantity);
    }).toList();

    state = AsyncData(_buildState(current, cartItems: updatedCart));
  }

  void removeItem(String itemId) {
    final current = _currentState;
    if (current == null) {
      return;
    }

    state = AsyncData(
      _buildState(
        current,
        cartItems: current.cartItems
            .where((cartItem) => cartItem.item.id != itemId)
            .toList(),
      ),
    );
  }

  void setQuantity(String itemId, double quantity) {
    TransactionValidation.requireFinite(quantity);
    final current = _currentState;
    if (current == null) {
      return;
    }

    try {
      quantity = ScaledArithmetic.inputQuantity(quantity);
    } on FormatException {
      // Keep finite overflow visible as invalid input, as required by #70.
      if (quantity.abs() <= ScaledArithmetic.maxUnits / 1000) {
        throw const AppException(
          'validation_error',
          'Kuantitas maksimal tiga angka desimal.',
        );
      }
    }
    if (quantity <= 0) {
      removeItem(itemId);
      return;
    }

    final updatedCart = current.cartItems.map((cartItem) {
      if (cartItem.item.id != itemId) {
        return cartItem;
      }

      return _withQuantity(cartItem, quantity);
    }).toList();

    state = AsyncData(_buildState(current, cartItems: updatedCart));
  }

  void clearCart() {
    final current = _currentState;
    if (current == null) {
      return;
    }

    state = AsyncData(
      _buildState(
        current,
        cartItems: [],
        orderDiscountAmount: 0,
        taxMode: TaxMode.automatic,
        resetCashPaidAmount: true,
      ),
    );
  }

  void updateItemDiscount(String itemId, double value) {
    TransactionValidation.requireFinite(value);
    final current = _currentState;
    if (current == null) {
      return;
    }

    final updatedCart = current.cartItems.map((cartItem) {
      if (cartItem.item.id != itemId) {
        return cartItem;
      }

      final cappedValue = value.clamp(0, cartItem.lineSubtotal).toDouble();
      return cartItem.copyWith(itemDiscountAmount: cappedValue);
    }).toList();

    state = AsyncData(_buildState(current, cartItems: updatedCart));
  }

  void updateOrderDiscount(double value) {
    TransactionValidation.requireFinite(value);
    final current = _currentState;
    if (current == null) {
      return;
    }

    state = AsyncData(
      _buildState(current, orderDiscountAmount: value < 0 ? 0 : value),
    );
  }

  void updateTaxAmount(double value) {
    TransactionValidation.requireFinite(value);
    final current = _currentState;
    if (current == null) {
      return;
    }

    state = AsyncData(
      _buildState(
        current,
        taxAmount: value < 0 ? 0 : value,
        taxMode: TaxMode.manual,
      ),
    );
  }

  void useAutomaticTax() {
    final current = _currentState;
    if (current == null) return;
    state = AsyncData(_buildState(current, taxMode: TaxMode.automatic));
  }

  void updatePaymentMethod(String paymentMethod) {
    final current = _currentState;
    if (current == null) {
      return;
    }

    state = AsyncData(
      _buildState(
        current,
        paymentMethod: paymentMethod,
        resetCashPaidAmount: paymentMethod != 'tunai',
      ),
    );
  }

  void updateEmployee(int? employeeId) {
    final current = _currentState;
    if (current == null) return;
    state = AsyncData(
      current.copyWith(
        employeeId: employeeId,
        resetEmployeeId: employeeId == null,
      ),
    );
  }

  void updateCashPaid(double? value) {
    final current = _currentState;
    if (current == null) {
      return;
    }

    final valid = value != null && value.isFinite && value >= 0;
    state = AsyncData(
      _buildState(
        current,
        cashPaidAmount: valid ? value : null,
        resetCashPaidAmount: !valid,
      ),
    );
  }

  Future<TransaksiReceipt> submit() async {
    if (_submitInProgress) {
      throw const AppException(
        'submit_in_progress',
        'Transaksi sedang disimpan.',
      );
    }
    final current = _currentState;
    if (current == null) {
      throw const AppException(
        'validation_error',
        'Data transaksi belum siap diproses.',
      );
    }

    if (current.cartItems.isEmpty) {
      throw const AppException(
        'validation_error',
        'Keranjang transaksi masih kosong.',
      );
    }

    if (!current.canSubmit) {
      throw AppException(
        'validation_error',
        current.validationError ?? 'Transaksi sedang disimpan.',
      );
    }

    final previous = _pendingRequest;
    final request =
        previous != null &&
            identical(previous.items, current.cartItems) &&
            previous.orderDiscountAmount == current.orderDiscountAmount &&
            previous.taxAmount == current.taxAmount &&
            previous.paymentMethod == current.paymentMethod &&
            previous.cashPaidAmount ==
                (current.paymentMethod == 'tunai'
                    ? current.cashPaidAmount
                    : null) &&
            previous.currencyCode == current.currencyCode &&
            previous.employeeId == current.employeeId
        ? previous
        : TransaksiSubmitRequest(
            items: current.cartItems,
            currencyCode: current.currencyCode,
            orderDiscountAmount: current.orderDiscountAmount,
            taxAmount: current.taxAmount,
            paymentMethod: current.paymentMethod,
            cashPaidAmount: current.paymentMethod == 'tunai'
                ? current.cashPaidAmount
                : null,
            employeeId: current.employeeId,
          );
    _pendingRequest = request;
    _submitInProgress = true;
    state = AsyncData(current.copyWith(isSubmitting: true));

    final TransaksiReceipt receipt;
    try {
      receipt = await ref
          .read(transactionRepositoryProvider)
          .saveTransaction(request);
    } catch (_) {
      if (ref.mounted) {
        state = AsyncData(current.copyWith(isSubmitting: false));
      }
      _submitInProgress = false;
      rethrow;
    }

    // The sale is committed. No subsequent read may restore this checkout.
    _pendingRequest = null;
    if (!ref.mounted) {
      _submitInProgress = false;
      return receipt;
    }
    state = AsyncData(
      TransaksiState(isSubmitting: true, currencyCode: current.currencyCode),
    );
    try {
      ref.invalidate(transaksiReceiptProvider(receipt.invoiceNumber));
      ref.invalidate(stokControllerProvider);
      ref.invalidate(dashboardSummaryProvider);
      ref.invalidate(salesReportSnapshotProvider);
      ref.invalidate(salesReportSnapshotByPeriodProvider);
      ref.invalidate(employeeReportProvider);
      ref.invalidate(expenseEntriesProvider);
      ref.invalidate(capitalMetricsProvider);
      await refreshCatalog();
    } finally {
      _submitInProgress = false;
      if (ref.mounted) {
        final latest = state.asData?.value;
        if (latest != null) {
          state = AsyncData(latest.copyWith(isSubmitting: false));
        }
      }
    }
    return receipt;
  }

  /// Retrying a catalog read never resubmits a committed sale.
  Future<void> refreshCatalog() async {
    final before = state.asData?.value;
    if (before == null || before.isRefreshingCatalog) return;
    state = AsyncData(before.copyWith(isRefreshingCatalog: true));
    try {
      final items = await ref
          .read(transactionRepositoryProvider)
          .getCatalogItems();
      if (!ref.mounted) return;
      final current = state.asData?.value ?? const TransaksiState();
      state = AsyncData(
        _buildState(
          current,
          catalogItems: items,
        ).copyWith(catalogRefreshFailed: false, isRefreshingCatalog: false),
      );
    } catch (_) {
      if (!ref.mounted) return;
      final current = state.asData?.value ?? const TransaksiState();
      state = AsyncData(
        current.copyWith(
          catalogItems: [],
          filteredItems: [],
          catalogRefreshFailed: true,
          isRefreshingCatalog: false,
        ),
      );
    }
  }

  TransaksiCartItem _withQuantity(TransaksiCartItem line, double quantity) {
    try {
      quantity = ScaledArithmetic.quantity(quantity);
    } on FormatException {
      // Preserve overflowing drafts so validation can block checkout.
    }
    final currency =
        ref.read(appSettingsProvider).asData?.value.currencyCode ??
        line.currencyCode;
    final updated = line.copyWith(quantity: quantity, currencyCode: currency);
    final subtotal = updated.lineSubtotal;
    if (!subtotal.isFinite || subtotal < 0) return updated;
    return updated.copyWith(
      itemDiscountAmount: line.itemDiscountAmount.clamp(0, subtotal).toDouble(),
    );
  }

  double? _adjustQuantity(double quantity, double step) {
    try {
      return ScaledArithmetic.addQuantity(quantity, step);
    } on FormatException {
      // Keep an unrepresentable draft editable; validation disables checkout.
      return null;
    }
  }

  double _quantityStep(TransaksiItem item) {
    const fractionalUnits = {'kg', 'g', 'l', 'liter', 'ml', 'm', 'meter'};
    final unit = item.unitLabel?.trim().toLowerCase();
    return fractionalUnits.contains(unit) ? 0.1 : 1.0;
  }

  TransaksiState? get _currentState {
    if (_submitInProgress) return null;
    final current = state;
    return current is AsyncData<TransaksiState> ? current.value : null;
  }

  TransaksiState _buildState(
    TransaksiState current, {
    List<TransaksiItem>? catalogItems,
    List<TransaksiCartItem>? cartItems,
    String? searchQuery,
    String? typeFilter,
    double? orderDiscountAmount,
    double? taxAmount,
    TaxMode? taxMode,
    String? paymentMethod,
    double? cashPaidAmount,
    bool resetCashPaidAmount = false,
  }) {
    final settings = ref.read(appSettingsProvider).asData?.value;
    final currency = settings?.currencyCode ?? current.currencyCode;
    double money(double value) {
      try {
        return ScaledArithmetic.money(value, currency);
      } on FormatException {
        return value;
      }
    }

    double quantity(double value) {
      try {
        return ScaledArithmetic.quantity(value);
      } on FormatException {
        return value;
      }
    }

    // Search/payment-only changes must preserve cart identity for checkout retry.
    final normalizedCart = cartItems != null || currency != current.currencyCode
        ? (cartItems ?? current.cartItems)
              .map(
                (line) => line.copyWith(
                  currencyCode: currency,
                  quantity: quantity(line.quantity),
                  itemDiscountAmount: money(line.itemDiscountAmount),
                ),
              )
              .toList()
        : current.cartItems;
    var nextState = current.copyWith(
      currencyCode: currency,
      catalogItems: catalogItems,
      cartItems: normalizedCart,
      searchQuery: searchQuery,
      typeFilter: typeFilter,
      orderDiscountAmount: money(
        orderDiscountAmount ?? current.orderDiscountAmount,
      ),
      taxAmount: money(taxAmount ?? current.taxAmount),
      taxMode: taxMode,
      paymentMethod: paymentMethod,
      cashPaidAmount: cashPaidAmount == null && current.cashPaidAmount == null
          ? null
          : money(cashPaidAmount ?? current.cashPaidAmount!),
      resetCashPaidAmount: resetCashPaidAmount,
      isSubmitting: current.isSubmitting,
    );

    if (nextState.taxMode == TaxMode.automatic &&
        (cartItems != null ||
            orderDiscountAmount != null ||
            taxMode != null ||
            currency != current.currencyCode)) {
      try {
        // Ignore the previous tax/payment while recovering an invalid draft.
        final calculation = nextState
            .copyWith(taxAmount: 0, resetCashPaidAmount: true)
            .calculation;
        final taxable = calculation.net;
        nextState = nextState.copyWith(
          taxAmount: calculation.amount(
            ScaledArithmetic.percentage(
              taxable < 0 ? 0 : taxable,
              settings?.defaultTaxPercent ?? 0,
            ),
          ),
        );
      } on FormatException {
        nextState = nextState.copyWith(taxAmount: double.nan);
      }
    }

    final normalizedQuery = nextState.searchQuery.trim().toLowerCase();
    final filteredItems = nextState.catalogItems.where((item) {
      final matchesFilter =
          nextState.typeFilter == 'semua' ||
          item.itemType == nextState.typeFilter;
      final matchesSearch =
          normalizedQuery.isEmpty ||
          item.name.toLowerCase().contains(normalizedQuery) ||
          item.category.toLowerCase().contains(normalizedQuery) ||
          (item.barcode?.contains(normalizedQuery) ?? false);
      return matchesFilter && matchesSearch;
    }).toList();

    return nextState.copyWith(filteredItems: filteredItems);
  }
}
