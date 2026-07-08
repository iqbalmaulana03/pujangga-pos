import '../../domain/entities/stock_item.dart';

class StokState {
  const StokState({
    this.allItems = const [],
    this.filteredItems = const [],
    this.searchQuery = '',
    this.categoryFilter = 'semua',
  });

  final List<StockItem> allItems;
  final List<StockItem> filteredItems;
  final String searchQuery;
  final String categoryFilter;

  int get totalItems => allItems.length;
  int get lowStockCount => allItems.where((item) => item.isLowStock).length;
  int get inactiveCount => allItems.where((item) => !item.isActive).length;
  int get totalUnits =>
      allItems.fold(0, (sum, item) => sum + item.currentStock);

  List<String> get categories {
    final values = allItems.map((item) => item.category).toSet().toList()
      ..sort();
    return ['semua', ...values];
  }

  List<StockItem> get lowStockItems =>
      allItems.where((item) => item.isLowStock).toList()
        ..sort((a, b) => a.currentStock.compareTo(b.currentStock));

  StokState copyWith({
    List<StockItem>? allItems,
    List<StockItem>? filteredItems,
    String? searchQuery,
    String? categoryFilter,
  }) {
    return StokState(
      allItems: allItems ?? this.allItems,
      filteredItems: filteredItems ?? this.filteredItems,
      searchQuery: searchQuery ?? this.searchQuery,
      categoryFilter: categoryFilter ?? this.categoryFilter,
    );
  }
}
