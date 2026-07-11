import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/services/app_startup_service.dart';
import '../../data/datasources/transaction_local_data_source.dart';
import '../../data/repositories/transaction_repository_impl.dart';
import '../../domain/entities/transaksi_cart_item.dart';
import '../../domain/entities/transaksi_item.dart';
import '../../domain/entities/transaksi_receipt.dart';
import '../../domain/entities/transaksi_submit_request.dart';
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
    AsyncNotifierProvider<TransaksiController, TransaksiState>(
      TransaksiController.new,
    );

final transaksiReceiptProvider =
    FutureProvider.family<TransaksiReceipt?, String>((ref, invoiceNumber) {
      return ref
          .watch(transactionRepositoryProvider)
          .getReceiptByInvoice(invoiceNumber);
    });

class TransaksiController extends AsyncNotifier<TransaksiState> {
  @override
  Future<TransaksiState> build() async {
    final items = await ref
        .read(transactionRepositoryProvider)
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
        TransaksiCartItem(item: item, quantity: 1, itemDiscountAmount: 0),
      );
    } else {
      final existing = updatedCart[existingIndex];
      updatedCart[existingIndex] = existing.copyWith(
        quantity: existing.quantity + 1,
      );
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

      if (cartItem.quantity > 1) {
        updatedCart.add(cartItem.copyWith(quantity: cartItem.quantity - 1));
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

      return cartItem.copyWith(quantity: cartItem.quantity + 1);
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
        taxAmount: 0,
        cashPaidAmount: 0,
      ),
    );
  }

  void updateItemDiscount(String itemId, double value) {
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
    final current = _currentState;
    if (current == null) {
      return;
    }

    state = AsyncData(
      _buildState(current, orderDiscountAmount: value < 0 ? 0 : value),
    );
  }

  void updateTaxAmount(double value) {
    final current = _currentState;
    if (current == null) {
      return;
    }

    state = AsyncData(_buildState(current, taxAmount: value < 0 ? 0 : value));
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

  void updateCashPaid(double? value) {
    final current = _currentState;
    if (current == null) {
      return;
    }

    state = AsyncData(_buildState(current, cashPaidAmount: value ?? 0));
  }

  Future<TransaksiReceipt> submit() async {
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
      throw const AppException(
        'validation_error',
        'Lengkapi pembayaran terlebih dahulu sebelum menyimpan transaksi.',
      );
    }

    state = AsyncData(current.copyWith(isSubmitting: true));

    try {
      final receipt = await ref
          .read(transactionRepositoryProvider)
          .saveTransaction(
            TransaksiSubmitRequest(
              items: current.cartItems,
              orderDiscountAmount: current.orderDiscountAmount,
              taxAmount: current.taxAmount,
              paymentMethod: current.paymentMethod,
              cashPaidAmount: current.paymentMethod == 'tunai'
                  ? current.cashPaidAmount
                  : null,
            ),
          );

      final refreshedItems = await ref
          .read(transactionRepositoryProvider)
          .getCatalogItems();
      state = AsyncData(
        _buildState(const TransaksiState(), catalogItems: refreshedItems),
      );
      ref.invalidate(transaksiReceiptProvider(receipt.invoiceNumber));
      return receipt;
    } catch (_) {
      state = AsyncData(current.copyWith(isSubmitting: false));
      rethrow;
    }
  }

  TransaksiState? get _currentState {
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
    String? paymentMethod,
    double? cashPaidAmount,
    bool resetCashPaidAmount = false,
  }) {
    double? calculatedTax = taxAmount;
    if (calculatedTax == null && cartItems != null) {
      final subtotal = cartItems.fold<double>(0, (t, i) => t + i.lineSubtotal);
      final discount = cartItems.fold<double>(0, (t, i) => t + i.itemDiscountAmount);
      final settings = ref.read(appSettingsProvider).asData?.value;
      final taxRatePercent = settings?.defaultTaxPercent ?? 0.0;
      calculatedTax = ((subtotal - discount) * (taxRatePercent / 100.0)).roundToDouble();
    }

    final nextState = current.copyWith(
      catalogItems: catalogItems,
      cartItems: cartItems,
      searchQuery: searchQuery,
      typeFilter: typeFilter,
      orderDiscountAmount: orderDiscountAmount,
      taxAmount: calculatedTax ?? current.taxAmount,
      paymentMethod: paymentMethod,
      cashPaidAmount: cashPaidAmount,
      resetCashPaidAmount: resetCashPaidAmount,
      isSubmitting: false,
    );

    final normalizedQuery = nextState.searchQuery.trim().toLowerCase();
    final filteredItems = nextState.catalogItems.where((item) {
      final matchesFilter =
          nextState.typeFilter == 'semua' ||
          item.itemType == nextState.typeFilter;
      final matchesSearch =
          normalizedQuery.isEmpty ||
          item.name.toLowerCase().contains(normalizedQuery) ||
          item.category.toLowerCase().contains(normalizedQuery);
      return matchesFilter && matchesSearch;
    }).toList();

    return nextState.copyWith(filteredItems: filteredItems);
  }
}
