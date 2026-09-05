import 'item_sales_summary.dart';
import 'report_period.dart';
import 'margin_item_summary.dart';

class SalesTrendPoint {
  const SalesTrendPoint({required this.label, required this.value});

  final String label;
  final double value;
}

class SalesReportSnapshot {
  const SalesReportSnapshot({
    required this.period,
    required this.start,
    required this.endExclusive,
    required this.revenue,
    required this.transactionCount,
    required this.topPaymentMethod,
    required this.itemSummaries,
    required this.paymentMethodBreakdown,
    required this.salesTrend,
    required this.margin,
    required this.marginIsComplete,
    required this.catalogMarginIsComplete,
    required this.topMarginItems,
    this.totalExpenses = 0.0,
  });

  final ReportPeriod period;
  final DateTime start;
  final DateTime endExclusive;
  final double revenue;
  final int transactionCount;
  final String? topPaymentMethod;
  final List<ItemSalesSummary> itemSummaries;
  final Map<String, double> paymentMethodBreakdown;
  final List<SalesTrendPoint> salesTrend;
  final double margin;
  final bool marginIsComplete;
  final bool catalogMarginIsComplete;
  final List<MarginItemSummary> topMarginItems;
  final double totalExpenses;

  bool get hasTransactions => transactionCount > 0;
  double get netProfit => margin - totalExpenses;

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
