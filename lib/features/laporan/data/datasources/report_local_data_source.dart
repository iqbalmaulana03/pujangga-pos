import '../../../../core/database/app_database.dart';
import '../../domain/entities/dashboard_summary.dart';
import '../../domain/entities/item_sales_summary.dart';
import '../../domain/entities/report_period.dart';
import '../../domain/entities/sales_report_snapshot.dart';
import '../../domain/entities/margin_item_summary.dart';
import '../../domain/entities/capital_metrics.dart';

class ReportLocalDataSource {
  const ReportLocalDataSource({required this.database});

  final AppDatabase database;

  Future<double> getRevenueForRange(DateTime start, DateTime end) async {
    final db = await database.database();
    final rows = await db.rawQuery(
      '''
      SELECT COALESCE(SUM(total_amount), 0) AS revenue
      FROM sales_transactions
      WHERE transaction_date >= ? AND transaction_date < ? AND status = 'completed'
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
      WHERE transaction_date >= ? AND transaction_date < ? AND status = 'completed'
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

    whereClauses.add('st.status = \'completed\'');
    final whereSql = 'WHERE ${whereClauses.join(' AND ')}';
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

    final db = await database.database();
    
    // Calculate total margin and completeness flag for today
    final revRows = await db.rawQuery(
      '''
      SELECT COALESCE(SUM(subtotal_amount - discount_amount), 0) AS net_revenue
      FROM sales_transactions
      WHERE transaction_date >= ? AND transaction_date < ? AND status = 'completed'
      ''',
      [range.start.toIso8601String(), range.endExclusive.toIso8601String()],
    );
    final cogsRows = await db.rawQuery(
      '''
      SELECT 
        COALESCE(SUM(sti.qty * COALESCE(sti.cost_price_snapshot, 0)), 0) AS total_cogs,
        COUNT(CASE WHEN sti.cost_price_snapshot IS NULL THEN 1 END) AS missing_cost_count
      FROM sales_transaction_items sti
      INNER JOIN sales_transactions st ON st.id = sti.transaction_id
      WHERE st.transaction_date >= ? AND st.transaction_date < ? AND st.status = 'completed'
      ''',
      [range.start.toIso8601String(), range.endExclusive.toIso8601String()],
    );

    final netRevenueToday = (revRows.first['net_revenue'] as num?)?.toDouble() ?? 0;
    final totalCogsToday = (cogsRows.first['total_cogs'] as num?)?.toDouble() ?? 0;
    final marginToday = netRevenueToday - totalCogsToday;
    final missingCostCount = (cogsRows.first['missing_cost_count'] as num?)?.toInt() ?? 0;
    final marginTodayIsComplete = missingCostCount == 0;

    final expenseRows = await db.rawQuery(
      '''
      SELECT COALESCE(SUM(amount), 0) AS total_expenses
      FROM expenses
      WHERE expense_date >= ? AND expense_date < ?
      ''',
      [range.start.toIso8601String(), range.endExclusive.toIso8601String()],
    );
    final totalExpensesToday = (expenseRows.first['total_expenses'] as num?)?.toDouble() ?? 0;

    return DashboardSummary(
      revenueToday: revenue,
      transactionCountToday: transactionCount,
      topItemName: topItemRows.isEmpty ? null : topItemRows.first.itemName,
      topItemQuantity: topItemRows.isEmpty ? 0 : topItemRows.first.quantitySold,
      topPaymentMethod: topPaymentMethod,
      marginToday: marginToday,
      marginTodayIsComplete: marginTodayIsComplete,
      totalExpensesToday: totalExpensesToday,
    );
  }

  Future<SalesReportSnapshot> getSalesReportSnapshot({
    required ReportPeriod period,
    DateTime? reference,
    ReportRange? customRange,
  }) async {
    final range = customRange ?? period.resolveRange(reference);
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
      WHERE transaction_date >= ? AND transaction_date < ? AND status = 'completed'
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

    // Calculate actual sales trend data points
    final duration = range.endExclusive.difference(range.start);
    final int intervalCount = period == ReportPeriod.harian ? 24 : 7;
    final intervalMs = duration.inMilliseconds / intervalCount;
    final List<SalesTrendPoint> trend = [];

    for (int i = 0; i < intervalCount; i++) {
      final intervalStart = range.start.add(Duration(milliseconds: (i * intervalMs).round()));
      final intervalEnd = range.start.add(Duration(milliseconds: ((i + 1) * intervalMs).round()));
      final val = await getRevenueForRange(intervalStart, intervalEnd);

      String label = '';
      if (period == ReportPeriod.harian) {
        final hour = intervalStart.hour.toString().padLeft(2, '0');
        label = '$hour:00';
      } else if (period == ReportPeriod.mingguan) {
        const days = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
        label = days[intervalStart.weekday - 1];
      } else if (period == ReportPeriod.bulanan) {
        label = 'Tgl ${intervalStart.day}';
      } else if (period == ReportPeriod.tahunan || duration.inDays > 60) {
        const months = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Ags', 'Sep', 'Okt', 'Nov', 'Des'];
        label = months[intervalStart.month - 1];
      } else {
        label = '${intervalStart.day}/${intervalStart.month}';
      }

      trend.add(SalesTrendPoint(label: label, value: val));
    }

    // Calculate total margin and completeness flag for period
    final revRows = await db.rawQuery(
      '''
      SELECT COALESCE(SUM(subtotal_amount - discount_amount), 0) AS net_revenue
      FROM sales_transactions
      WHERE transaction_date >= ? AND transaction_date < ? AND status = 'completed'
      ''',
      [range.start.toIso8601String(), range.endExclusive.toIso8601String()],
    );
    final cogsRows = await db.rawQuery(
      '''
      SELECT 
        COALESCE(SUM(sti.qty * COALESCE(sti.cost_price_snapshot, 0)), 0) AS total_cogs,
        COUNT(CASE WHEN sti.cost_price_snapshot IS NULL THEN 1 END) AS missing_cost_count
      FROM sales_transaction_items sti
      INNER JOIN sales_transactions st ON st.id = sti.transaction_id
      WHERE st.transaction_date >= ? AND st.transaction_date < ? AND st.status = 'completed'
      ''',
      [range.start.toIso8601String(), range.endExclusive.toIso8601String()],
    );

    final netRevenue = (revRows.first['net_revenue'] as num?)?.toDouble() ?? 0;
    final totalCogs = (cogsRows.first['total_cogs'] as num?)?.toDouble() ?? 0;
    final margin = netRevenue - totalCogs;
    final missingCostCount = (cogsRows.first['missing_cost_count'] as num?)?.toInt() ?? 0;
    final marginIsComplete = missingCostCount == 0;

    // Check if any active item in the catalog is missing cost data
    final missingCatalogCostRows = await db.rawQuery(
      '''
      SELECT COUNT(*) AS missing_count
      FROM items
      WHERE is_active = 1 AND (
        (item_type = 'product' AND harga_modal IS NULL) OR
        (item_type = 'service' AND biaya_dasar IS NULL)
      )
      '''
    );
    final hasMissingCatalogCost = (missingCatalogCostRows.first['missing_count'] as num?)?.toInt() ?? 0;
    final catalogMarginIsComplete = hasMissingCatalogCost == 0;

    // Query top 5 margin items from active catalog items that have cost data
    final topMarginRows = await db.rawQuery(
      '''
      SELECT 
        name,
        item_type,
        sale_price,
        unit,
        COALESCE(harga_modal, biaya_dasar) AS cost_val,
        ((sale_price - COALESCE(harga_modal, biaya_dasar)) / sale_price * 100) AS margin_pct
      FROM items
      WHERE is_active = 1 AND sale_price > 0 AND COALESCE(harga_modal, biaya_dasar) IS NOT NULL
      ORDER BY margin_pct DESC
      LIMIT 5
      '''
    );

    final List<MarginItemSummary> topMarginItems = topMarginRows.map((row) {
      return MarginItemSummary(
        name: row['name'] as String,
        itemType: row['item_type'] as String == 'service' ? 'jasa' : 'barang',
        marginPercent: (row['margin_pct'] as num).toDouble(),
        sellingPrice: (row['sale_price'] as num).toDouble(),
        unitLabel: row['unit'] as String?,
      );
    }).toList();

    final expenseRows = await db.rawQuery(
      '''
      SELECT COALESCE(SUM(amount), 0) AS total_expenses
      FROM expenses
      WHERE expense_date >= ? AND expense_date < ?
      ''',
      [range.start.toIso8601String(), range.endExclusive.toIso8601String()],
    );
    final totalExpenses = (expenseRows.first['total_expenses'] as num?)?.toDouble() ?? 0;

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
      margin: margin,
      marginIsComplete: marginIsComplete,
      catalogMarginIsComplete: catalogMarginIsComplete,
      topMarginItems: topMarginItems,
      totalExpenses: totalExpenses,
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
      WHERE transaction_date >= ? AND transaction_date < ? AND status = 'completed'
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

  Future<CapitalMetrics> getCapitalMetrics() async {
    final db = await database.database();

    final historyRows = await db.query(
      'capital_history',
      orderBy: 'created_at ASC',
    );
    
    double latestCapital = 0.0;
    List<double> historicalCapitals = [];
    
    if (historyRows.isNotEmpty) {
      for (final row in historyRows) {
        historicalCapitals.add((row['amount'] as num).toDouble());
      }
      latestCapital = historicalCapitals.last;
    } else {
      final profileRows = await db.query(
        'business_profile',
        columns: ['modal_awal_usaha'],
        limit: 1,
      );
      latestCapital = (profileRows.isNotEmpty ? profileRows.first['modal_awal_usaha'] as num? : 0)?.toDouble() ?? 0.0;
      if (latestCapital > 0) {
         historicalCapitals.add(latestCapital);
      }
    }

    double totalMargin = 0.0;
    double totalExpenses = 0.0;

    final revRows = await db.rawQuery(
      'SELECT COALESCE(SUM(subtotal_amount - discount_amount), 0) AS net_revenue FROM sales_transactions WHERE status = \'completed\'',
    );
    final cogsRows = await db.rawQuery(
      'SELECT COALESCE(SUM(i.qty * COALESCE(i.cost_price_snapshot, 0)), 0) AS total_cogs FROM sales_transaction_items i JOIN sales_transactions t ON i.transaction_id = t.id WHERE t.status = \'completed\'',
    );
    final netRev = (revRows.first['net_revenue'] as num?)?.toDouble() ?? 0.0;
    final cogs = (cogsRows.first['total_cogs'] as num?)?.toDouble() ?? 0.0;
    totalMargin = netRev - cogs;

    final expensesRows = await db.rawQuery(
      'SELECT COALESCE(SUM(amount), 0) AS total_expenses FROM expenses',
    );
    totalExpenses = (expensesRows.first['total_expenses'] as num?)?.toDouble() ?? 0.0;

    final stockRows = await db.rawQuery('''
      SELECT COALESCE(SUM(stock_qty * harga_modal), 0) AS total_stock_value
      FROM items
      WHERE item_type = 'product' AND harga_modal IS NOT NULL AND stock_qty > 0
    ''');
    final currentStockValue = (stockRows.first['total_stock_value'] as num?)?.toDouble() ?? 0.0;

    final netCapitalValue = latestCapital + totalMargin - totalExpenses;
    final currentCash = netCapitalValue - currentStockValue;

    return CapitalMetrics(
      initialCapital: latestCapital,
      currentCash: currentCash,
      currentStockValue: currentStockValue,
      historicalCapitals: historicalCapitals,
    );
  }
}
