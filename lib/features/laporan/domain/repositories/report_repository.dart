import '../entities/dashboard_summary.dart';
import '../entities/item_sales_summary.dart';
import '../entities/report_period.dart';
import '../entities/sales_report_snapshot.dart';
import '../entities/capital_metrics.dart';
import '../entities/employee_report_summary.dart';

abstract class ReportRepository {
  Future<List<EmployeeReportSummary>> getEmployeeReport({
    required DateTime start,
    required DateTime end,
  });
  Future<double> getRevenueForRange(DateTime start, DateTime end);
  Future<List<ItemSalesSummary>> getItemSalesSummary({
    DateTime? start,
    DateTime? end,
  });
  Future<DashboardSummary> getDashboardSummary({DateTime? reference});
  Future<SalesReportSnapshot> getSalesReportSnapshot({
    required ReportPeriod period,
    DateTime? reference,
    ReportRange? customRange,
  });
  Future<CapitalMetrics> getCapitalMetrics();
}
