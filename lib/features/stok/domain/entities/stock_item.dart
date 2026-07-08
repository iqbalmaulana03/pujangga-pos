class StockItem {
  const StockItem({
    required this.id,
    required this.name,
    required this.category,
    required this.sellingPrice,
    required this.currentStock,
    required this.isActive,
    this.sku,
    this.unitLabel,
  });

  final String id;
  final String name;
  final String category;
  final double sellingPrice;
  final int currentStock;
  final bool isActive;
  final String? sku;
  final String? unitLabel;

  bool get isLowStock => currentStock <= 5;
}
