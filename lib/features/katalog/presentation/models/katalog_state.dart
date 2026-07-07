import '../../domain/entities/catalog_item.dart';

class KatalogState {
  const KatalogState({
    this.allItems = const [],
    this.filteredItems = const [],
    this.searchQuery = '',
    this.typeFilter = 'semua',
    this.statusFilter = 'semua',
  });

  final List<CatalogItem> allItems;
  final List<CatalogItem> filteredItems;
  final String searchQuery;
  final String typeFilter;
  final String statusFilter;

  int get activeCount => allItems.where((item) => item.isActive).length;
  int get barangCount => allItems.where((item) => item.isBarang).length;
  int get jasaCount => allItems.where((item) => item.isJasa).length;

  KatalogState copyWith({
    List<CatalogItem>? allItems,
    List<CatalogItem>? filteredItems,
    String? searchQuery,
    String? typeFilter,
    String? statusFilter,
  }) {
    return KatalogState(
      allItems: allItems ?? this.allItems,
      filteredItems: filteredItems ?? this.filteredItems,
      searchQuery: searchQuery ?? this.searchQuery,
      typeFilter: typeFilter ?? this.typeFilter,
      statusFilter: statusFilter ?? this.statusFilter,
    );
  }
}
