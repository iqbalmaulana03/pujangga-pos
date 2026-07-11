import '../../../../core/database/app_database.dart';
import '../../domain/entities/dashboard_summary.dart';
import '../../domain/entities/item_sales_summary.dart';
import '../../domain/entities/report_period.dart';
import '../../domain/entities/sales_report_snapshot.dart';

class ReportLocalDataSource {
  const ReportLocalDataSource({required this.database});

  final AppDatabase database;

  Future<double> getRevenueForRange(DateTime start, DateTime end) async {
    final db = await database.database();
    final rows = await db.rawQuery(
      '''
      SELECT COALESCE(SUM(total_amount), 0) AS revenue
      FROM sales_transactions
      WHERE transaction_date >= ? AND transaction_date < ?
      ''',
      [start.toIso8601String(), end.toIso8601String()],
    );

    return (rows.first['revenue'] as num?)?.toDouble() ?? 0;
  }

  Future<int> getTransactionCountForRange(DateTime start, DateTime end) async {
    final db = await database.database();
    final rows = await db.rawQuery(
      '''
      SELECT COUNT(*) AS transaction_count
      FROM sales_transactions
      WHERE transaction_date >= ? AND transaction_date < ?
      ''',
      [start.toIso8601String(), end.toIso8601String()],
    );

    return (rows.first['transaction_count'] as num?)?.toInt() ?? 0;
  }

  Future<List<ItemSalesSummary>> getItemSalesSummary({
    DateTime? start,
    DateTime? end,
    int? limit,
  }) async {
    final db = await database.database();
    final whereClauses = <String>[];
    final whereArgs = <Object?>[];

    if (start != null) {
      whereClauses.add('st.transaction_date >= ?');
      whereArgs.add(start.toIso8601String());
    }

    if (end != null) {
      whereClauses.add('st.transaction_date < ?');
      whereArgs.add(end.toIso8601String());
    }

    final whereSql = whereClauses.isEmpty
        ? ''
        : 'WHERE ${whereClauses.join(' AND ')}';
    final limitSql = limit == null ? '' : 'LIMIT $limit';

    final rows = await db.rawQuery(
      '''
      SELECT
        sti.item_id,
        sti.item_name_snapshot,
        sti.item_type_snapshot,
        SUM(sti.qty) AS total_qty,
        SUM(sti.line_total) AS total_sales
      FROM sales_transaction_items sti
      INNER JOIN sales_transactions st ON st.id = sti.transaction_id
      $whereSql
      GROUP BY sti.item_id, sti.item_name_snapshot, sti.item_type_snapshot
      ORDER BY total_sales DESC, sti.item_name_snapshot ASC
      $limitSql
      ''',
      whereArgs,
    );

    return rows
        .map(
          (row) => ItemSalesSummary(
            itemId: '${row['item_id']}',
            itemName: row['item_name_snapshot'] as String,
            itemType: (row['item_type_snapshot'] as String) == 'service'
                ? 'jasa'
                : 'barang',
            quantitySold: (row['total_qty'] as num).toDouble(),
            totalSales: (row['total_sales'] as num).toDouble(),
          ),
        )
        .toList();
  }

  Future<DashboardSummary> getDashboardSummary({DateTime? reference}) async {
    final range = ReportPeriod.harian.resolveRange(reference);
    final revenue = await getRevenueForRange(range.start, range.endExclusive);
    final transactionCount = await getTransactionCountForRange(
      range.start,
      range.endExclusive,
    );
    final topItemRows = await getItemSalesSummary(
      start: range.start,
      end: range.endExclusive,
      limit: 1,
    );
    final topPaymentMethod = await _getTopPaymentMethodForRange(
      range.start,
      range.endExclusive,
    );

    return DashboardSummary(
      revenueToday: revenue,
      transactionCountToday: transactionCount,
      topItemName: topItemRows.isEmpty ? null : topItemRows.first.itemName,
      topItemQuantity: topItemRows.isEmpty ? 0 : topItemRows.first.quantitySold,
      topPaymentMethod: topPaymentMethod,
    );
  }

  Future<SalesReportSnapshot> getSalesReportSnapshot({
    required ReportPeriod period,
    DateTime? reference,
  }) async {
    final range = period.resolveRange(reference);
    final revenue = await getRevenueForRange(range.start, range.endExclusive);
    final transactionCount = await getTransactionCountForRange(
      range.start,
      range.endExclusive,
    );
    final topPaymentMethod = await _getTopPaymentMethodForRange(
      range.start,
      range.endExclusive,
    );
    final items = await getItemSalesSummary(
      start: range.start,
      end: range.endExclusive,
    );

    // Calculate actual payment methods breakdown percentages
    final db = await database.database();
    final paymentRows = await db.rawQuery(
      '''
      SELECT payment_method, COALESCE(SUM(total_amount), 0) AS total_revenue
      FROM sales_transactions
      WHERE transaction_date >= ? AND transaction_date < ?
      GROUP BY payment_method
      ''',
      [range.start.toIso8601String(), range.endExclusive.toIso8601String()],
    );

    double cashTotal = 0;
    double qrisTotal = 0;
    double transferTotal = 0;
    double otherTotal = 0;

    for (final row in paymentRows) {
      final method = row['payment_method'] as String? ?? 'cash';
      final rev = (row['total_revenue'] as num?)?.toDouble() ?? 0;
      switch (method.toLowerCase()) {
        case 'cash':
        case 'tunai':
          cashTotal += rev;
          break;
        case 'qris':
          qrisTotal += rev;
          break;
        case 'transfer':
          transferTotal += rev;
          break;
        default:
          otherTotal += rev;
          break;
      }
    }

    final totalPaymentRev = cashTotal + qrisTotal + transferTotal + otherTotal;
    final Map<String, double> paymentBreakdown = {};
    if (totalPaymentRev > 0) {
      paymentBreakdown['Tunai'] = cashTotal / totalPaymentRev;
      paymentBreakdown['QRIS'] = qrisTotal / totalPaymentRev;
      paymentBreakdown['Transfer'] = transferTotal / totalPaymentRev;
      paymentBreakdown['Lainnya'] = otherTotal / totalPaymentRev;
    } else {
      paymentBreakdown['Tunai'] = 0.0;
      paymentBreakdown['QRIS'] = 0.0;
      paymentBreakdown['Transfer'] = 0.0;
      paymentBreakdown['Lainnya'] = 0.0;
    }

    // Calculate actual sales trend data points (exactly 7 intervals)
    final duration = range.endExclusive.difference(range.start);
    final intervalMs = duration.inMilliseconds / 7;
    final List<SalesTrendPoint> trend = [];

    for (int i = 0; i < 7; i++) {
      final intervalStart = range.start.add(Duration(milliseconds: (i * intervalMs).round()));
      final intervalEnd = range.start.add(Duration(milliseconds: ((i + 1) * intervalMs).round()));
      final val = await getRevenueForRange(intervalStart, intervalEnd);

      String label = '';
      if (period == ReportPeriod.harian) {
        final hour = intervalEnd.hour.toString().padLeft(2, '0');
        label = '$hour:00';
      } else if (period == ReportPeriod.mingguan) {
        const days = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
        label = days[intervalStart.weekday - 1];
      } else {
        label = 'Tgl ${intervalStart.day}';
      }

      trend.add(SalesTrendPoint(label: label, value: val));
    }

    return SalesReportSnapshot(
      period: period,
      start: range.start,
      endExclusive: range.endExclusive,
      revenue: revenue,
      transactionCount: transactionCount,
      topPaymentMethod: topPaymentMethod,
      itemSummaries: items,
      paymentMethodBreakdown: paymentBreakdown,
      salesTrend: trend,
    );
  }

  Future<String?> _getTopPaymentMethodForRange(
    DateTime start,
    DateTime end,
  ) async {
    final db = await database.database();
    final rows = await db.rawQuery(
      '''
      SELECT
        payment_method,
        COUNT(*) AS transaction_count,
        SUM(total_amount) AS total_revenue
      FROM sales_transactions
      WHERE transaction_date >= ? AND transaction_date < ?
      GROUP BY payment_method
      ORDER BY transaction_count DESC, total_revenue DESC, payment_method ASC
      LIMIT 1
      ''',
      [start.toIso8601String(), end.toIso8601String()],
    );

    if (rows.isEmpty) {
      return null;
    }

    return _mapDbPaymentMethodToUi(rows.first['payment_method'] as String);
  }

  String _mapDbPaymentMethodToUi(String value) {
    switch (value) {
      case 'cash':
        return 'Tunai';
      case 'transfer':
        return 'Transfer';
      case 'qris':
        return 'QRIS';
      case 'ewallet':
        return 'E-Wallet';
      case 'card':
        return 'Kartu';
      default:
        return 'Tunai';
    }
  }
}
