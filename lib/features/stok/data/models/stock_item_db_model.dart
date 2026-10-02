import '../../domain/entities/stock_item.dart';

class StockItemDbModel {
  const StockItemDbModel({
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
    this.barcode,
    this.unitLabel,
  });

  final int id;
  final String name;
  final String category;
  final double sellingPrice;
  final double currentStock;
  final bool isActive;
  final DateTime createdAt;
  final double? costPrice;
  final DateTime? lastSoldAt;
  final String? sku;
  final String? barcode;
  final String? unitLabel;

  factory StockItemDbModel.fromMap(Map<String, Object?> map) {
    return StockItemDbModel(
      id: (map['id'] as num).toInt(),
      name: map['name'] as String,
      category:
          (map['category_name'] as String?) ??
          (map['category'] as String? ?? 'Umum'),
      sellingPrice: (map['sale_price'] as num).toDouble(),
      currentStock: ((map['stock_qty'] as num?) ?? 0).toDouble(),
      isActive: (map['is_active'] as num).toInt() == 1,
      createdAt: DateTime.parse(map['created_at'] as String),
      costPrice: (map['harga_modal'] as num?)?.toDouble(),
      lastSoldAt: map['last_sold_at'] != null
          ? DateTime.parse(map['last_sold_at'] as String)
          : null,
      sku: map['sku'] as String?,
      barcode: map['barcode'] as String?,
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
      createdAt: createdAt,
      costPrice: costPrice,
      lastSoldAt: lastSoldAt,
      sku: sku,
      barcode: barcode,
      unitLabel: unitLabel,
    );
  }
}
