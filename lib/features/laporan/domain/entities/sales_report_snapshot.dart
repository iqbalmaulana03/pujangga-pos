import 'item_sales_summary.dart';
import 'report_period.dart';

class SalesReportSnapshot {
  const SalesReportSnapshot({
    required this.period,
    required this.start,
    required this.endExclusive,
    required this.revenue,
    required this.transactionCount,
    required this.topPaymentMethod,
    required this.itemSummaries,
  });

  final ReportPeriod period;
  final DateTime start;
  final DateTime endExclusive;
  final double revenue;
  final int transactionCount;
  final String? topPaymentMethod;
  final List<ItemSalesSummary> itemSummaries;

  bool get hasTransactions => transactionCount > 0;

  double get averageTransactionValue {
    if (transactionCount == 0) {
      return 0;
    }

    return revenue / transactionCount;
  }

  ItemSalesSummary? get topItem {
    if (itemSummaries.isEmpty) {
      return null;
    }

    return itemSummaries.first;
  }
}
