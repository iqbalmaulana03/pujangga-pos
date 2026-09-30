class StockItem {
  const StockItem({
    required this.id,
    required this.name,
    required this.category,
    required this.sellingPrice,
    required this.currentStock,
    required this.isActive,
    required this.createdAt,
    this.costPrice,
    this.lastSoldAt,
    this.sku,
    this.unitLabel,
  });

  final String id;
  final String name;
  final String category;
  final double sellingPrice;
  final double currentStock;
  final bool isActive;
  final DateTime createdAt;
  final double? costPrice;
  final DateTime? lastSoldAt;
  final String? sku;
  final String? unitLabel;

  bool get isLowStock => currentStock <= 5;

  double get totalAssetValue => currentStock * (costPrice ?? 0.0);

  bool get isDeadStock {
    if (currentStock <= 0) return false;
    final now = DateTime.now();
    final referenceDate = lastSoldAt ?? createdAt;
    return now.difference(referenceDate).inDays > 30;
  }
}
