import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../../../../core/database/app_database.dart';
import '../../domain/entities/sales_report_export_file.dart';

typedef CsvExportDirectoryProvider = Future<Directory> Function();

class SalesReportCsvExportService {
  SalesReportCsvExportService({
    required this.database,
    required this.logger,
    this._exportDirectoryProvider,
  });

  final AppDatabase database;
  final Logger logger;
  final CsvExportDirectoryProvider? _exportDirectoryProvider;

  Future<SalesReportExportFile> exportSalesReport() async {
    final db = await database.database();
    final rows = await db.rawQuery('''
      SELECT
        st.invoice_no,
        st.transaction_date,
        st.total_amount,
        st.payment_method,
        COUNT(sti.id) AS item_count,
        GROUP_CONCAT(sti.item_name_snapshot, ' | ') AS item_summary
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

    final generatedAt = DateTime.now();
    final fileName = 'sales_report_${_formatTimestamp(generatedAt)}.csv';
    final directory =
        await (_exportDirectoryProvider?.call() ??
            getApplicationDocumentsDirectory());
    await directory.create(recursive: true);

    final file = File(path.join(directory.path, fileName));
    final csv = buildCsvForRows(rows);
    await file.writeAsString(csv);

    logger.info('Sales report CSV exported to ${file.path}');

    return SalesReportExportFile(
      filePath: file.path,
      fileName: fileName,
      generatedAt: generatedAt,
      transactionCount: rows.length,
    );
  }

  @visibleForTesting
  String buildCsvForRows(List<Map<String, Object?>> rows) {
    final buffer = StringBuffer();
    buffer.writeln(
      [
        'nomor_invoice',
        'tanggal_transaksi',
        'total_transaksi',
        'metode_pembayaran',
        'jumlah_item',
        'ringkasan_item',
      ].join(','),
    );

    for (final row in rows) {
      buffer.writeln(
        [
          _escapeCsv(row['invoice_no'] as String? ?? ''),
          _escapeCsv(row['transaction_date'] as String? ?? ''),
          _escapeCsv(
            ((row['total_amount'] as num?)?.toDouble() ?? 0).toStringAsFixed(2),
          ),
          _escapeCsv(_mapDbPaymentMethodToUi(row['payment_method'] as String?)),
          _escapeCsv(((row['item_count'] as num?)?.toInt() ?? 0).toString()),
          _escapeCsv(row['item_summary'] as String? ?? ''),
        ].join(','),
      );
    }

    return buffer.toString();
  }

  String _escapeCsv(String value) {
    final escaped = value.replaceAll('"', '""');
    return '"$escaped"';
  }

  String _mapDbPaymentMethodToUi(String? value) {
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

  String _formatTimestamp(DateTime value) {
    final year = value.year.toString().padLeft(4, '0');
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    final second = value.second.toString().padLeft(2, '0');
    return '$year$month$day$hour$minute$second';
  }
}
