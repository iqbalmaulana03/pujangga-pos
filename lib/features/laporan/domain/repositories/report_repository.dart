import '../entities/dashboard_summary.dart';
import '../entities/item_sales_summary.dart';
import '../entities/report_period.dart';
import '../entities/sales_report_snapshot.dart';

abstract class ReportRepository {
  Future<double> getRevenueForRange(DateTime start, DateTime end);
  Future<List<ItemSalesSummary>> getItemSalesSummary({
    DateTime? start,
    DateTime? end,
  });
  Future<DashboardSummary> getDashboardSummary({DateTime? reference});
  Future<SalesReportSnapshot> getSalesReportSnapshot({
    required ReportPeriod period,
    DateTime? reference,
  });
}
