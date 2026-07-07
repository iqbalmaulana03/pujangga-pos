import '../../domain/entities/catalog_item.dart';

class CatalogItemDbModel {
  const CatalogItemDbModel({
    required this.id,
    required this.name,
    required this.category,
    required this.itemType,
    required this.sellingPrice,
    required this.isActive,
    this.sku,
    this.stockQuantity,
    this.unitLabel,
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

  factory CatalogItemDbModel.fromMap(Map<String, Object?> map) {
    return CatalogItemDbModel(
      id: map['id'] as String,
      name: map['name'] as String,
      category: map['category'] as String,
      itemType: map['item_type'] as String,
      sellingPrice: (map['selling_price'] as num).toDouble(),
      isActive: (map['is_active'] as num).toInt() == 1,
      sku: map['sku'] as String?,
      stockQuantity: (map['stock_quantity'] as num?)?.toInt(),
      unitLabel: map['unit_label'] as String?,
    );
  }

  CatalogItem toEntity() {
    return CatalogItem(
      id: id,
      name: name,
      category: category,
      itemType: itemType,
      sellingPrice: sellingPrice,
      isActive: isActive,
      sku: sku,
      stockQuantity: stockQuantity,
      unitLabel: unitLabel,
    );
  }
}
