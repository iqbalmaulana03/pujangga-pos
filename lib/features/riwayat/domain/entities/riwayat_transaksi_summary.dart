class RiwayatTransaksiSummary {
  const RiwayatTransaksiSummary({
    required this.invoiceNumber,
    required this.createdAt,
    required this.totalAmount,
    required this.paymentMethod,
    required this.itemCount,
    required this.itemNames,
  });

  final String invoiceNumber;
  final DateTime createdAt;
  final double totalAmount;
  final String paymentMethod;
  final int itemCount;
  final List<String> itemNames;

  String get itemSummary {
    if (itemNames.isEmpty) {
      return 'Tanpa item';
    }
    if (itemNames.length == 1) {
      return itemNames.first;
    }
    return '${itemNames.first} +${itemNames.length - 1} item';
  }
}
