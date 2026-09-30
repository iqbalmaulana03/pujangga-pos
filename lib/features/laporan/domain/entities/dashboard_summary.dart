class DashboardSummary {
  const DashboardSummary({
    required this.revenueToday,
    required this.transactionCountToday,
    required this.topItemName,
    required this.topItemQuantity,
    required this.topPaymentMethod,
    required this.marginToday,
    required this.marginTodayIsComplete,
    this.totalExpensesToday = 0.0,
    this.revenuePreviousDay,
  });

  final double revenueToday;
  final int transactionCountToday;
  final String? topItemName;
  final double topItemQuantity;
  final String? topPaymentMethod;
  final double marginToday;
  final bool marginTodayIsComplete;
  final double totalExpensesToday;
  final double? revenuePreviousDay;

  bool get hasTransactions => transactionCountToday > 0;
  double get netProfitToday => marginToday - totalExpensesToday;
}
