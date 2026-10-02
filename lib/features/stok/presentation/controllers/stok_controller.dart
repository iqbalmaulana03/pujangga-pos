import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/app_startup_service.dart';
import '../../data/datasources/stock_local_data_source.dart';
import '../../data/repositories/stock_repository_impl.dart';
import '../../domain/entities/stock_adjustment_request.dart';
import '../../domain/entities/stock_item.dart';
import '../../domain/entities/stock_movement.dart';
import '../../domain/repositories/stock_repository.dart';
import '../models/stok_state.dart';

final stockLocalDataSourceProvider = Provider<StockLocalDataSource>((ref) {
  return StockLocalDataSource(database: ref.watch(appDatabaseProvider));
});

final stockRepositoryProvider = Provider<StockRepository>((ref) {
  return StockRepositoryImpl(
    localDataSource: ref.watch(stockLocalDataSourceProvider),
  );
});

final stokControllerProvider =
    AsyncNotifierProvider.autoDispose<StokController, StokState>(
      StokController.new,
    );

final stockItemProvider = FutureProvider.autoDispose.family<StockItem?, String>(
  (ref, itemId) {
    return ref.watch(stockRepositoryProvider).getStockItemById(itemId);
  },
);

final stockMovementsProvider = FutureProvider.autoDispose
    .family<List<StockMovement>, String>((ref, itemId) {
      return ref.watch(stockRepositoryProvider).getStockMovements(itemId);
    });

final stockItemDetailProvider = FutureProvider.autoDispose
    .family<StockItem?, String>((ref, itemId) {
      return ref.watch(stockRepositoryProvider).getStockItemById(itemId);
    });

final stockMovementDetailProvider = FutureProvider.autoDispose
    .family<List<StockMovement>, String>((ref, itemId) {
      return ref.watch(stockRepositoryProvider).getStockMovements(itemId);
    });

class StokController extends AsyncNotifier<StokState> {
  @override
  Future<StokState> build() async {
    final items = await ref.read(stockRepositoryProvider).getStockItems();
    return _buildState(const StokState(), allItems: items);
  }

  void updateSearch(String value) {
    final current = _currentState;
    if (current == null) {
      return;
    }

    state = AsyncData(_buildState(current, searchQuery: value));
  }

  void updateCategoryFilter(String value) {
    final current = _currentState;
    if (current == null) {
      return;
    }

    state = AsyncData(_buildState(current, categoryFilter: value));
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final items = await ref.read(stockRepositoryProvider).getStockItems();
      return _buildState(const StokState(), allItems: items);
    });
  }

  Future<void> submitAdjustment(StockAdjustmentRequest request) async {
    await ref.read(stockRepositoryProvider).adjustStock(request);
    await refresh();
    ref.invalidate(stockItemDetailProvider(request.itemId));
    ref.invalidate(stockMovementDetailProvider(request.itemId));
  }

  StokState? get _currentState {
    final current = state;
    return current is AsyncData<StokState> ? current.value : null;
  }

  StokState _buildState(
    StokState current, {
    List<StockItem>? allItems,
    String? searchQuery,
    String? categoryFilter,
  }) {
    final nextState = current.copyWith(
      allItems: allItems,
      searchQuery: searchQuery,
      categoryFilter: categoryFilter,
    );

    final normalizedQuery = nextState.searchQuery.trim().toLowerCase();
    final filteredItems =
        nextState.allItems.where((item) {
          final matchesCategory =
              nextState.categoryFilter == 'semua' ||
              item.category == nextState.categoryFilter;
          final matchesQuery =
              normalizedQuery.isEmpty ||
              item.name.toLowerCase().contains(normalizedQuery) ||
              item.category.toLowerCase().contains(normalizedQuery) ||
              (item.sku?.toLowerCase().contains(normalizedQuery) ?? false) ||
              (item.barcode?.contains(normalizedQuery) ?? false);
          return matchesCategory && matchesQuery;
        }).toList()..sort((a, b) {
          if (a.currentStock != b.currentStock) {
            return a.currentStock.compareTo(b.currentStock);
          }
          return a.name.compareTo(b.name);
        });

    return nextState.copyWith(filteredItems: filteredItems);
  }
}
