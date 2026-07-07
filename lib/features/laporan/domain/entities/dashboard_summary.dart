class DashboardSummary {
  const DashboardSummary({
    required this.revenueToday,
    required this.transactionCountToday,
    required this.topItemName,
    required this.topItemQuantity,
    required this.topPaymentMethod,
  });

  final double revenueToday;
  final int transactionCountToday;
  final String? topItemName;
  final double topItemQuantity;
  final String? topPaymentMethod;

  bool get hasTransactions => transactionCountToday > 0;
}
