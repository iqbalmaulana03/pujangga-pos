class MarginItemSummary {
  const MarginItemSummary({
    required this.name,
    required this.itemType,
    required this.marginPercent,
    required this.sellingPrice,
    this.unitLabel,
  });

  final String name;
  final String itemType;
  final double marginPercent;
  final double sellingPrice;
  final String? unitLabel;
}
