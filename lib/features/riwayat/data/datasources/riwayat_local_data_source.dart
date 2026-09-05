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
        st.status,
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
        st.payment_method,
        st.status
      ORDER BY st.transaction_date DESC, st.id DESC
    ''');

    return rows.map(RiwayatTransaksiSummaryDbModel.fromMap).toList();
  }

  Future<void> voidTransaction(String invoiceNumber) async {
    final db = await database.database();
    
    await db.transaction((txn) async {
      final transactions = await txn.query(
        'sales_transactions',
        columns: ['id', 'status'],
        where: 'invoice_no = ?',
        whereArgs: [invoiceNumber],
        limit: 1,
      );

      if (transactions.isEmpty) return;
      
      final transaction = transactions.first;
      final transactionId = (transaction['id'] as num).toInt();
      final currentStatus = transaction['status'] as String? ?? 'completed';
      
      if (currentStatus == 'voided') return;

      final now = DateTime.now().toIso8601String();

      await txn.update(
        'sales_transactions',
        {'status': 'voided', 'updated_at': now},
        where: 'id = ?',
        whereArgs: [transactionId],
      );

      final items = await txn.query(
        'sales_transaction_items',
        columns: ['item_id', 'qty', 'item_type_snapshot', 'item_name_snapshot'],
        where: 'transaction_id = ?',
        whereArgs: [transactionId],
      );

      for (final item in items) {
        if (item['item_type_snapshot'] == 'product') {
          final itemId = (item['item_id'] as num).toInt();
          final qty = (item['qty'] as num).toDouble();
          
          final itemRows = await txn.query('items', columns: ['stock_qty'], where: 'id = ?', whereArgs: [itemId], limit: 1);
          if (itemRows.isNotEmpty) {
            final currentStock = (itemRows.first['stock_qty'] as num).toDouble();
            final updatedStock = currentStock + qty;
            
            await txn.update(
              'items',
              {'stock_qty': updatedStock, 'updated_at': now},
              where: 'id = ?',
              whereArgs: [itemId],
            );
            
            await txn.insert('stock_movements', {
              'item_id': itemId,
              'movement_type': 'void',
              'qty_change': qty,
              'qty_before': currentStock,
              'qty_after': updatedStock,
              'reference_type': 'transaction',
              'reference_id': transactionId,
              'notes': 'Pembatalan transaksi $invoiceNumber',
              'created_at': now,
            });
          }
        }
      }
    });
  }
}
