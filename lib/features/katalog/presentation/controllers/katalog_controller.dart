import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/app_startup_service.dart';
import '../../../transaksi/presentation/controllers/transaksi_controller.dart';
import '../../data/datasources/catalog_local_data_source.dart';
import '../../data/repositories/catalog_repository_impl.dart';
import '../../domain/entities/catalog_item.dart';
import '../../domain/repositories/catalog_repository.dart';
import '../models/katalog_state.dart';

final catalogLocalDataSourceProvider = Provider<CatalogLocalDataSource>((ref) {
  return CatalogLocalDataSource(database: ref.watch(appDatabaseProvider));
});

final catalogRepositoryProvider = Provider<CatalogRepository>((ref) {
  return CatalogRepositoryImpl(
    localDataSource: ref.watch(catalogLocalDataSourceProvider),
  );
});

final katalogControllerProvider =
    AsyncNotifierProvider<KatalogController, KatalogState>(
      KatalogController.new,
    );

final catalogItemProvider = FutureProvider.family<CatalogItem?, String>((
  ref,
  itemId,
) {
  return ref.watch(catalogRepositoryProvider).getItemById(itemId);
});

class KatalogController extends AsyncNotifier<KatalogState> {
  @override
  Future<KatalogState> build() async {
    final items = await ref.read(catalogRepositoryProvider).getItems();
    return _buildState(const KatalogState(), allItems: items);
  }

  void updateSearch(String value) {
    final current = _currentState;
    if (current == null) {
      return;
    }

    state = AsyncData(_buildState(current, searchQuery: value));
  }

  void updateTypeFilter(String value) {
    final current = _currentState;
    if (current == null) {
      return;
    }

    state = AsyncData(_buildState(current, typeFilter: value));
  }

  void updateStatusFilter(String value) {
    final current = _currentState;
    if (current == null) {
      return;
    }

    state = AsyncData(_buildState(current, statusFilter: value));
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final items = await ref.read(catalogRepositoryProvider).getItems();
      return _buildState(const KatalogState(), allItems: items);
    });
  }

  Future<void> toggleItemStatus(CatalogItem item) async {
    await ref
        .read(catalogRepositoryProvider)
        .updateItemStatus(itemId: item.id, isActive: !item.isActive);

    ref.invalidate(transaksiControllerProvider);
    await refresh();
  }

  KatalogState? get _currentState {
    final current = state;
    return current is AsyncData<KatalogState> ? current.value : null;
  }

  KatalogState _buildState(
    KatalogState current, {
    List<CatalogItem>? allItems,
    String? searchQuery,
    String? typeFilter,
    String? statusFilter,
  }) {
    final nextState = current.copyWith(
      allItems: allItems,
      searchQuery: searchQuery,
      typeFilter: typeFilter,
      statusFilter: statusFilter,
    );

    final normalizedQuery = nextState.searchQuery.trim().toLowerCase();
    final filteredItems = nextState.allItems.where((item) {
      final matchesType =
          nextState.typeFilter == 'semua' ||
          item.itemType == nextState.typeFilter;
      final matchesStatus =
          nextState.statusFilter == 'semua' ||
          (nextState.statusFilter == 'aktif' && item.isActive) ||
          (nextState.statusFilter == 'nonaktif' && !item.isActive);
      final matchesQuery =
          normalizedQuery.isEmpty ||
          item.name.toLowerCase().contains(normalizedQuery) ||
          item.category.toLowerCase().contains(normalizedQuery) ||
          (item.sku?.toLowerCase().contains(normalizedQuery) ?? false);
      return matchesType && matchesStatus && matchesQuery;
    }).toList();

    return nextState.copyWith(filteredItems: filteredItems);
  }
}
