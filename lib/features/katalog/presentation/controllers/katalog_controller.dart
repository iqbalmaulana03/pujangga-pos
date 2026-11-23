import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/app_startup_service.dart';
import '../../../../core/services/dataset_generation.dart';
import '../../../../core/services/mutation_revision.dart';
import '../../data/datasources/catalog_local_data_source.dart';
import '../../data/repositories/catalog_repository_impl.dart';
import '../../domain/entities/catalog_item.dart';
import '../../domain/entities/catalog_item_draft.dart';
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
    AsyncNotifierProvider.autoDispose<KatalogController, KatalogState>(
      KatalogController.new,
    );

final catalogItemProvider = FutureProvider.autoDispose
    .family<CatalogItem?, String>((ref, itemId) {
      ref.watch(datasetGenerationProvider);
      ref.watch(mutationRevisionProvider.select((r) => (r.catalog, r.stock)));
      return ref.watch(catalogRepositoryProvider).getItemById(itemId);
    });

class KatalogController extends AsyncNotifier<KatalogState> {
  int? _datasetGeneration;

  @override
  Future<KatalogState> build() async {
    final buildRef = ref;
    final generation = buildRef.watch(datasetGenerationProvider);
    ref.watch(mutationRevisionProvider.select((r) => (r.catalog, r.stock)));
    final previous = _datasetGeneration == generation
        ? state.value ?? const KatalogState()
        : const KatalogState();
    final items = await ref.watch(catalogRepositoryProvider).getItems();
    if (buildRef.mounted) _datasetGeneration = generation;
    return _buildState(previous, allItems: items);
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

  Future<void> refresh() => ref
      .refresh(katalogControllerProvider.future)
      .then<void>((_) {}, onError: (Object _, StackTrace _) {});

  Future<void> saveItem(CatalogItemDraft draft, {String? itemId}) {
    final repository = ref.read(catalogRepositoryProvider);
    return ref.read(mutationRevisionProvider.notifier).commit(
      {MutationDomain.catalog},
      () => itemId == null
          ? repository.createItem(draft)
          : repository.updateItem(itemId, draft),
    );
  }

  Future<void> toggleItemStatus(CatalogItem item) async {
    final repository = ref.read(catalogRepositoryProvider);
    await ref.read(mutationRevisionProvider.notifier).commit(
      {MutationDomain.catalog},
      () => repository.updateItemStatus(
        itemId: item.id,
        isActive: !item.isActive,
      ),
    );
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
          (item.sku?.toLowerCase().contains(normalizedQuery) ?? false) ||
          (item.barcode?.contains(normalizedQuery) ?? false);
      return matchesType && matchesStatus && matchesQuery;
    }).toList();

    return nextState.copyWith(filteredItems: filteredItems);
  }
}
