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
    this.wholesalePrice,
    this.wholesaleMinQuantity,
  });

  final String id;
  final String name;
  final String category;
  final String itemType;
  final double sellingPrice;
  final bool isActive;
  final String? sku;
  final double? stockQuantity;
  final String? unitLabel;
  final double? costPrice;
  final double? wholesalePrice;
  final int? wholesaleMinQuantity;

  bool get isBarang => itemType == 'barang';
  bool get isJasa => itemType == 'jasa';
}
