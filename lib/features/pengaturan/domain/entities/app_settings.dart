class AppSettings {
  const AppSettings({
    required this.currencyCode,
    required this.currencySymbol,
    required this.defaultTaxPercent,
    required this.stockAllowNegative,
    this.autoPrintReceipt = true,
    this.receiptHeader,
    this.receiptFooter,
  });

  final String currencyCode;
  final String currencySymbol;
  final double defaultTaxPercent;
  final bool stockAllowNegative;
  final bool autoPrintReceipt;
  final String? receiptHeader;
  final String? receiptFooter;
}
