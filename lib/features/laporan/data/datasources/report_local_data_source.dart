import '../../../../core/database/app_database.dart';
import '../../domain/entities/item_sales_summary.dart';

class ReportLocalDataSource {
  const ReportLocalDataSource({required this.database});

  final AppDatabase database;

  Future<double> getRevenueForRange(DateTime start, DateTime end) async {
    final db = await database.database();
    final rows = await db.rawQuery(
      '''
      SELECT COALESCE(SUM(total_amount), 0) AS revenue
      FROM sales_transactions
      WHERE transaction_date >= ? AND transaction_date <= ?
      ''',
      [start.toIso8601String(), end.toIso8601String()],
    );

    return (rows.first['revenue'] as num?)?.toDouble() ?? 0;
  }

  Future<List<ItemSalesSummary>> getItemSalesSummary({
    DateTime? start,
    DateTime? end,
  }) async {
    final db = await database.database();
    final whereClauses = <String>[];
    final whereArgs = <Object?>[];

    if (start != null) {
      whereClauses.add('st.transaction_date >= ?');
      whereArgs.add(start.toIso8601String());
    }

    if (end != null) {
      whereClauses.add('st.transaction_date <= ?');
      whereArgs.add(end.toIso8601String());
    }

    final whereSql = whereClauses.isEmpty
        ? ''
        : 'WHERE ${whereClauses.join(' AND ')}';

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
}
