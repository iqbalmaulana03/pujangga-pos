import 'package:flutter_test/flutter_test.dart';
import 'package:pujangga_pos/features/setup_usaha/domain/entities/business_profile.dart';
import 'package:pujangga_pos/features/katalog/domain/entities/catalog_item.dart';
import 'package:pujangga_pos/features/laporan/domain/entities/margin_item_summary.dart';
import 'package:pujangga_pos/features/laporan/domain/entities/dashboard_summary.dart';
import 'package:pujangga_pos/features/laporan/domain/entities/sales_report_snapshot.dart';
import 'package:pujangga_pos/features/laporan/domain/entities/report_period.dart';

void main() {
  group('Margin & Capital Features Unit Tests', () {
    test('BusinessProfile modalAwalUsaha copyWith and instantiation', () {
      const profile = BusinessProfile(
        businessName: 'Toko Kopi Pujangga',
        businessType: 'F&B',
        modalAwalUsaha: 5000000.0,
      );

      expect(profile.modalAwalUsaha, 5000000.0);

      final updated = profile.copyWith(modalAwalUsaha: 7500000.0);
      expect(updated.modalAwalUsaha, 7500000.0);
      expect(updated.businessName, 'Toko Kopi Pujangga');
    });

    test('CatalogItem costPrice field mapping', () {
      final item = CatalogItem(
        id: '1',
        name: 'Kopi Aren',
        category: 'Kopi',
        itemType: 'barang',
        sellingPrice: 18000.0,
        isActive: true,
        costPrice: 8000.0,
      );

      expect(item.costPrice, 8000.0);
      expect(item.sellingPrice, 18000.0);
      expect(item.isBarang, true);
    });

    test('MarginItemSummary calculations', () {
      const summary = MarginItemSummary(
        name: 'Kopi Aren',
        itemType: 'barang',
        marginPercent: 55.5,
        sellingPrice: 18000.0,
        unitLabel: 'cup',
      );

      expect(summary.name, 'Kopi Aren');
      expect(summary.marginPercent, 55.5);
      expect(summary.sellingPrice, 18000.0);
      expect(summary.unitLabel, 'cup');
    });

    test('DashboardSummary margin details', () {
      const summary = DashboardSummary(
        revenueToday: 150000.0,
        transactionCountToday: 5,
        topItemName: 'Kopi Aren',
        topItemQuantity: 10,
        topPaymentMethod: 'QRIS',
        marginToday: 75000.0,
        marginTodayIsComplete: true,
      );

      expect(summary.marginToday, 75000.0);
      expect(summary.marginTodayIsComplete, true);
    });

    test('SalesReportSnapshot margin details', () {
      final now = DateTime.now();
      final snapshot = SalesReportSnapshot(
        period: ReportPeriod.harian,
        start: now,
        endExclusive: now.add(const Duration(days: 1)),
        revenue: 500000.0,
        transactionCount: 20,
        topPaymentMethod: 'Tunai',
        itemSummaries: [],
        paymentMethodBreakdown: {},
        salesTrend: [],
        margin: 250000.0,
        marginIsComplete: false,
        catalogMarginIsComplete: false,
        topMarginItems: const [
          MarginItemSummary(
            name: 'Kopi Aren',
            itemType: 'barang',
            marginPercent: 55.0,
            sellingPrice: 18000.0,
          ),
        ],
      );

      expect(snapshot.margin, 250000.0);
      expect(snapshot.marginIsComplete, false);
      expect(snapshot.catalogMarginIsComplete, false);
      expect(snapshot.topMarginItems.first.name, 'Kopi Aren');
    });
  });
}
