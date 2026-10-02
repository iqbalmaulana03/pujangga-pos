import '../../domain/entities/transaksi_item.dart';

class TransaksiItemDbModel {
  const TransaksiItemDbModel({
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

  final int id;
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

  factory TransaksiItemDbModel.fromMap(Map<String, Object?> map) {
    return TransaksiItemDbModel(
      id: (map['id'] as num).toInt(),
      name: map['name'] as String,
      category: (map['category_name'] as String?) ?? 'Umum',
      itemType: map['item_type'] as String,
      sellingPrice:
          (map['sale_price'] as num?)?.toDouble() ??
          (map['selling_price'] as num?)?.toDouble() ??
          0,
      stockQuantity:
          ((map['stock_qty'] as num?) ?? (map['stock_quantity'] as num?))
              ?.toDouble(),
      barcode: map['barcode'] as String?,
      unitLabel: (map['unit'] as String?) ?? map['unit_label'] as String?,
      isActive: (map['is_active'] as num).toInt() == 1,
      wholesalePrice: (map['wholesale_price'] as num?)?.toDouble(),
      wholesaleMinQuantity: (map['wholesale_min_quantity'] as num?)?.toInt(),
    );
  }

  TransaksiItem toEntity() {
    return TransaksiItem(
      id: '$id',
      name: name,
      category: category,
      itemType: itemType == 'service' ? 'jasa' : 'barang',
      sellingPrice: sellingPrice,
      stockQuantity: stockQuantity,
      barcode: barcode,
      unitLabel: unitLabel,
      isActive: isActive,
      wholesalePrice: wholesalePrice,
      wholesaleMinQuantity: wholesaleMinQuantity,
    );
  }
}
