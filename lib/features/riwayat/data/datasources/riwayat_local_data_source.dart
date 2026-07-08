import '../../../../core/database/app_database.dart';
import '../models/riwayat_transaksi_summary_db_model.dart';

class RiwayatLocalDataSource {
  RiwayatLocalDataSource({required this.database});

  final AppDatabase database;

  Future<List<RiwayatTransaksiSummaryDbModel>> getTransactions() async {
    final db = await database.database();
    final rows = await db.rawQuery('''
      SELECT
        st.invoice_no,
        st.transaction_date,
        st.total_amount,
        st.payment_method,
        COUNT(sti.id) AS item_count,
        GROUP_CONCAT(sti.item_name_snapshot, '|||') AS item_names
      FROM sales_transactions st
      LEFT JOIN sales_transaction_items sti
        ON sti.transaction_id = st.id
      GROUP BY
        st.id,
        st.invoice_no,
        st.transaction_date,
        st.total_amount,
        st.payment_method
      ORDER BY st.transaction_date DESC, st.id DESC
    ''');

    return rows.map(RiwayatTransaksiSummaryDbModel.fromMap).toList();
  }
}
