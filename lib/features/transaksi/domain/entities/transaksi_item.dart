class TransaksiItem {
  const TransaksiItem({
    required this.id,
    required this.name,
    required this.category,
    required this.itemType,
    required this.sellingPrice,
    required this.isActive,
    this.stockQuantity,
    this.barcode,
    this.unitLabel,
    this.wholesalePrice,
    this.wholesaleMinQuantity,
  });

  final String id;
  final String name;
  final String category;
  final String itemType;
  final double sellingPrice;
  final bool isActive;
  final double? stockQuantity;
  final String? barcode;
  final String? unitLabel;
  final double? wholesalePrice;
  final int? wholesaleMinQuantity;

  bool get isBarang => itemType == 'barang';
  bool get isJasa => itemType == 'jasa';
}
