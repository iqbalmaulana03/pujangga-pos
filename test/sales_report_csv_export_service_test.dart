import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:pujangga_pos/core/database/app_database.dart';
import 'package:pujangga_pos/features/pengaturan/data/services/sales_report_csv_export_service.dart';

void main() {
  test('membangun CSV laporan penjualan dengan header yang konsisten', () {
    final service = SalesReportCsvExportService(
      database: AppDatabase.instance,
      logger: Logger.root,
    );

    final csv = service.buildCsvForRows([
      {
        'invoice_no': 'INV-001',
        'transaction_date': '2026-07-12T09:00:00.000',
        'total_amount': 125000.0,
        'payment_method': 'qris',
        'item_count': 2,
        'item_summary': 'Es Kopi Susu | Croffle',
      },
    ]);

    final lines = csv.trim().split('\n');
    expect(
      lines.first,
      'nomor_invoice,tanggal_transaksi,total_transaksi,metode_pembayaran,jumlah_item,ringkasan_item',
    );
    expect(lines.last, contains('"INV-001"'));
    expect(lines.last, contains('"QRIS"'));
    expect(lines.last, contains('"2"'));
    expect(lines.last, contains('"Es Kopi Susu | Croffle"'));
  });

  test('meng-escape nilai CSV yang mengandung koma dan kutip', () {
    final service = SalesReportCsvExportService(
      database: AppDatabase.instance,
      logger: Logger.root,
    );

    final csv = service.buildCsvForRows([
      {
        'invoice_no': 'INV-002',
        'transaction_date': '2026-07-12T10:00:00.000',
        'total_amount': 45000.0,
        'payment_method': 'cash',
        'item_count': 1,
        'item_summary': 'Paket "Hemat", Es Teh',
      },
    ]);

    final lines = csv.trim().split('\n');
    expect(lines.last, contains('"Tunai"'));
    expect(lines.last, contains('"Paket ""Hemat"", Es Teh"'));
  });

  test('menetralkan awalan formula dan tetap mengutip newline pada teks', () {
    final service = SalesReportCsvExportService(
      database: AppDatabase.instance,
      logger: Logger.root,
    );

    final csv = service.buildCsvForRows([
      {
        'invoice_no': 'INV-003',
        'transaction_date': '2026-07-12T11:00:00.000',
        'total_amount': 12000.0,
        'payment_method': 'cash',
        'item_count': 1,
        'item_summary': '=HYPERLINK("https://invalid", "click"),\n@SUM(A1:A2)',
      },
      {
        'invoice_no': '+CMD',
        'transaction_date': '2026-07-12T12:00:00.000',
        'total_amount': 1.0,
        'payment_method': 'cash',
        'item_count': 1,
        'item_summary': '-1 + @name',
      },
    ]);

    expect(csv, contains("\"'=HYPERLINK("));
    expect(csv, contains("\"'+CMD\""));
    expect(csv, contains("\"'-1 + @name\""));
    expect(csv, contains('\n@SUM(A1:A2)'));
  });
}
