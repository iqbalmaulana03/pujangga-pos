import 'package:flutter_test/flutter_test.dart';
import 'package:pujangga_pos/features/laporan/domain/entities/report_period.dart';
import 'package:pujangga_pos/features/laporan/domain/entities/sales_report_snapshot.dart';

void main() {
  test('range harian memakai awal hari sampai hari berikutnya', () {
    final range = ReportPeriod.harian.resolveRange(
      DateTime(2026, 7, 7, 14, 30),
    );

    expect(range.start, DateTime(2026, 7, 7));
    expect(range.endExclusive, DateTime(2026, 7, 8));
  });

  test('range mingguan dimulai dari hari senin', () {
    final range = ReportPeriod.mingguan.resolveRange(
      DateTime(2026, 7, 9, 10, 0),
    );

    expect(range.start, DateTime(2026, 7, 6));
    expect(range.endExclusive, DateTime(2026, 7, 13));
  });

  test('range bulanan dimulai dari tanggal satu bulan berjalan', () {
    final range = ReportPeriod.bulanan.resolveRange(
      DateTime(2026, 7, 23, 9, 0),
    );

    expect(range.start, DateTime(2026, 7, 1));
    expect(range.endExclusive, DateTime(2026, 8, 1));
  });

  test('snapshot laporan menghitung rata-rata transaksi', () {
    final snapshot = SalesReportSnapshot(
      period: ReportPeriod.harian,
      start: DateTime(2026, 7, 7),
      endExclusive: DateTime(2026, 7, 8),
      revenue: 450000,
      transactionCount: 9,
      topPaymentMethod: 'QRIS',
      itemSummaries: [],
      paymentMethodBreakdown: const {},
      salesTrend: const [],
      margin: 0.0,
      marginIsComplete: true,
      catalogMarginIsComplete: true,
      topMarginItems: const [],
    );

    expect(snapshot.hasTransactions, isTrue);
    expect(snapshot.averageTransactionValue, 50000);
  });
}
