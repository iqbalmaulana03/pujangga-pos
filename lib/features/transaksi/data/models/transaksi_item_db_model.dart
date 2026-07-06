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
    this.unitLabel,
  });

  final String id;
  final String name;
  final String category;
  final String itemType;
  final double sellingPrice;
  final bool isActive;
  final int? stockQuantity;
  final String? unitLabel;

  factory TransaksiItemDbModel.fromMap(Map<String, Object?> map) {
    return TransaksiItemDbModel(
      id: map['id'] as String,
      name: map['name'] as String,
      category: map['category'] as String,
      itemType: map['item_type'] as String,
      sellingPrice: (map['selling_price'] as num).toDouble(),
      stockQuantity: (map['stock_quantity'] as num?)?.toInt(),
      unitLabel: map['unit_label'] as String?,
      isActive: (map['is_active'] as num).toInt() == 1,
    );
  }

  TransaksiItem toEntity() {
    return TransaksiItem(
      id: id,
      name: name,
      category: category,
      itemType: itemType,
      sellingPrice: sellingPrice,
      stockQuantity: stockQuantity,
      unitLabel: unitLabel,
      isActive: isActive,
    );
  }
}
