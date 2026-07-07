import '../../domain/entities/item_sales_summary.dart';
import '../../domain/repositories/report_repository.dart';
import '../datasources/report_local_data_source.dart';

class ReportRepositoryImpl implements ReportRepository {
  const ReportRepositoryImpl({required this.localDataSource});

  final ReportLocalDataSource localDataSource;

  @override
  Future<double> getRevenueForRange(DateTime start, DateTime end) {
    return localDataSource.getRevenueForRange(start, end);
  }

  @override
  Future<List<ItemSalesSummary>> getItemSalesSummary({
    DateTime? start,
    DateTime? end,
  }) {
    return localDataSource.getItemSalesSummary(start: start, end: end);
  }
}
