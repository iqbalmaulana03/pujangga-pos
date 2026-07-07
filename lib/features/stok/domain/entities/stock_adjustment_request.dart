class StockAdjustmentRequest {
  const StockAdjustmentRequest({
    required this.itemId,
    required this.adjustmentType,
    required this.quantity,
    this.notes,
  });

  final String itemId;
  final String adjustmentType;
  final double quantity;
  final String? notes;
}
