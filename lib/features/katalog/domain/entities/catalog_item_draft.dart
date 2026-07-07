class CatalogItemDraft {
  const CatalogItemDraft({
    required this.name,
    required this.category,
    required this.itemType,
    required this.sellingPrice,
    required this.isActive,
    this.sku,
    this.stockQuantity,
    this.unitLabel,
  });

  final String name;
  final String category;
  final String itemType;
  final double sellingPrice;
  final bool isActive;
  final String? sku;
  final int? stockQuantity;
  final String? unitLabel;

  bool get isBarang => itemType == 'barang';
}
