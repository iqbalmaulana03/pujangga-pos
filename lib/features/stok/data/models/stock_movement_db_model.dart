import '../../domain/entities/stock_movement.dart';

class StockMovementDbModel {
  const StockMovementDbModel({
    required this.id,
    required this.itemId,
    required this.itemName,
    required this.movementType,
    required this.quantityChange,
    required this.quantityBefore,
    required this.quantityAfter,
    required this.referenceType,
    required this.createdAt,
    this.referenceId,
    this.notes,
  });

  final int id;
  final int itemId;
  final String itemName;
  final String movementType;
  final double quantityChange;
  final double quantityBefore;
  final double quantityAfter;
  final String referenceType;
  final DateTime createdAt;
  final int? referenceId;
  final String? notes;

  factory StockMovementDbModel.fromMap(Map<String, Object?> map) {
    return StockMovementDbModel(
      id: (map['id'] as num).toInt(),
      itemId: (map['item_id'] as num).toInt(),
      itemName: map['item_name'] as String,
      movementType: map['movement_type'] as String,
      quantityChange: (map['qty_change'] as num).toDouble(),
      quantityBefore: (map['qty_before'] as num).toDouble(),
      quantityAfter: (map['qty_after'] as num).toDouble(),
      referenceType: map['reference_type'] as String,
      referenceId: (map['reference_id'] as num?)?.toInt(),
      notes: map['notes'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  StockMovement toEntity() {
    return StockMovement(
      id: id,
      itemId: '$itemId',
      itemName: itemName,
      movementType: movementType,
      quantityChange: quantityChange,
      quantityBefore: quantityBefore,
      quantityAfter: quantityAfter,
      referenceType: referenceType,
      referenceId: referenceId,
      notes: notes,
      createdAt: createdAt,
    );
  }
}
