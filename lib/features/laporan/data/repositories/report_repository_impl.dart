import '../../domain/entities/dashboard_summary.dart';
import '../../domain/entities/item_sales_summary.dart';
import '../../domain/entities/report_period.dart';
import '../../domain/entities/sales_report_snapshot.dart';
import '../../domain/entities/capital_metrics.dart';
import '../../domain/repositories/report_repository.dart';
import '../datasources/report_local_data_source.dart';
import '../../../pengeluaran/data/services/employee_expense_service.dart';
import '../../domain/entities/employee_report_summary.dart';

class ReportRepositoryImpl implements ReportRepository {
  const ReportRepositoryImpl({
    required this.localDataSource,
    this.now = DateTime.now,
  });

  final ReportLocalDataSource localDataSource;
  final DateTime Function() now;

  Future<void> _prepareFinancialRead() => EmployeeExpenseService(
    database: localDataSource.database,
    now: now,
  ).reconcile();

  @override
  Future<List<EmployeeReportSummary>> getEmployeeReport({
    required DateTime start,
    required DateTime end,
  }) async {
    await _prepareFinancialRead();
    return localDataSource.getEmployeeReport(start: start, end: end);
  }

  @override
  Future<double> getRevenueForRange(DateTime start, DateTime end) async {
    await _prepareFinancialRead();
    return localDataSource.getRevenueForRange(start, end);
  }

  @override
  Future<List<ItemSalesSummary>> getItemSalesSummary({
    DateTime? start,
    DateTime? end,
  }) async {
    await _prepareFinancialRead();
    return localDataSource.getItemSalesSummary(start: start, end: end);
  }

  @override
  Future<DashboardSummary> getDashboardSummary({DateTime? reference}) async {
    await _prepareFinancialRead();
    return localDataSource.getDashboardSummary(reference: reference);
  }

  @override
  Future<SalesReportSnapshot> getSalesReportSnapshot({
    required ReportPeriod period,
    DateTime? reference,
    ReportRange? customRange,
  }) async {
    await _prepareFinancialRead();
    return localDataSource.getSalesReportSnapshot(
      period: period,
      reference: reference,
      customRange: customRange,
    );
  }

  @override
  Future<CapitalMetrics> getCapitalMetrics() async {
    await _prepareFinancialRead();
    return localDataSource.getCapitalMetrics();
  }
}
