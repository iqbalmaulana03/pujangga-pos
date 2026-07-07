class ItemSalesSummary {
  const ItemSalesSummary({
    required this.itemId,
    required this.itemName,
    required this.itemType,
    required this.quantitySold,
    required this.totalSales,
  });

  final String itemId;
  final String itemName;
  final String itemType;
  final double quantitySold;
  final double totalSales;
}
