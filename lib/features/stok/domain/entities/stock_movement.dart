class StockMovement {
  const StockMovement({
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
  final String itemId;
  final String itemName;
  final String movementType;
  final double quantityChange;
  final double quantityBefore;
  final double quantityAfter;
  final String referenceType;
  final DateTime createdAt;
  final int? referenceId;
  final String? notes;
}
