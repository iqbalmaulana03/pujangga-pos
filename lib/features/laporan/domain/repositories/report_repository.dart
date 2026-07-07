import '../entities/item_sales_summary.dart';

abstract class ReportRepository {
  Future<double> getRevenueForRange(DateTime start, DateTime end);
  Future<List<ItemSalesSummary>> getItemSalesSummary({
    DateTime? start,
    DateTime? end,
  });
}
