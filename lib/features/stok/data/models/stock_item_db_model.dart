import '../../domain/entities/stock_item.dart';

class StockItemDbModel {
  const StockItemDbModel({
    required this.id,
    required this.name,
    required this.category,
    required this.sellingPrice,
    required this.currentStock,
    required this.isActive,
    this.sku,
    this.unitLabel,
  });

  final int id;
  final String name;
  final String category;
  final double sellingPrice;
  final int currentStock;
  final bool isActive;
  final String? sku;
  final String? unitLabel;

  factory StockItemDbModel.fromMap(Map<String, Object?> map) {
    return StockItemDbModel(
      id: (map['id'] as num).toInt(),
      name: map['name'] as String,
      category:
          (map['category_name'] as String?) ??
          (map['category'] as String? ?? 'Umum'),
      sellingPrice: (map['sale_price'] as num).toDouble(),
      currentStock: ((map['stock_qty'] as num?) ?? 0).toInt(),
      isActive: (map['is_active'] as num).toInt() == 1,
      sku: map['sku'] as String?,
      unitLabel: map['unit'] as String?,
    );
  }

  StockItem toEntity() {
    return StockItem(
      id: '$id',
      name: name,
      category: category,
      sellingPrice: sellingPrice,
      currentStock: currentStock,
      isActive: isActive,
      sku: sku,
      unitLabel: unitLabel,
    );
  }
}
