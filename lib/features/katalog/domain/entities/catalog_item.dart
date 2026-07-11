class CatalogItem {
  const CatalogItem({
    required this.id,
    required this.name,
    required this.category,
    required this.itemType,
    required this.sellingPrice,
    required this.isActive,
    this.sku,
    this.stockQuantity,
    this.unitLabel,
    this.costPrice,
  });

  final String id;
  final String name;
  final String category;
  final String itemType;
  final double sellingPrice;
  final bool isActive;
  final String? sku;
  final int? stockQuantity;
  final String? unitLabel;
  final double? costPrice;

  bool get isBarang => itemType == 'barang';
  bool get isJasa => itemType == 'jasa';
}
