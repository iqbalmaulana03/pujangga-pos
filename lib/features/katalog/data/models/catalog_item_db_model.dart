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
    this.costPrice,
    this.wholesalePrice,
    this.wholesaleMinQuantity,
  });

  final int id;
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

  factory CatalogItemDbModel.fromMap(Map<String, Object?> map) {
    return CatalogItemDbModel(
      id: (map['id'] as num).toInt(),
      name: map['name'] as String,
      category:
          (map['category_name'] as String?) ??
          (map['category'] as String? ?? 'Umum'),
      itemType: map['item_type'] as String,
      sellingPrice:
          (map['sale_price'] as num?)?.toDouble() ??
          (map['selling_price'] as num).toDouble(),
      isActive: (map['is_active'] as num).toInt() == 1,
      sku: map['sku'] as String?,
      stockQuantity:
          ((map['stock_qty'] as num?) ?? (map['stock_quantity'] as num?))
              ?.toDouble(),
      unitLabel: (map['unit'] as String?) ?? map['unit_label'] as String?,
      costPrice:
          (map['harga_modal'] as num?)?.toDouble() ??
          (map['biaya_dasar'] as num?)?.toDouble(),
      wholesalePrice: (map['wholesale_price'] as num?)?.toDouble(),
      wholesaleMinQuantity: (map['wholesale_min_quantity'] as num?)?.toInt(),
    );
  }

  CatalogItem toEntity() {
    return CatalogItem(
      id: '$id',
      name: name,
      category: category,
      itemType: _mapDbItemTypeToUi(itemType),
      sellingPrice: sellingPrice,
      isActive: isActive,
      sku: sku,
      stockQuantity: stockQuantity,
      unitLabel: unitLabel,
      costPrice: costPrice,
      wholesalePrice: wholesalePrice,
      wholesaleMinQuantity: wholesaleMinQuantity,
    );
  }

  String _mapDbItemTypeToUi(String value) {
    return value == 'service' ? 'jasa' : 'barang';
  }
}
