import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_router.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../domain/entities/item_sales_summary.dart';
import '../../domain/entities/report_period.dart';
import '../../domain/entities/sales_report_snapshot.dart';
import '../../domain/entities/margin_item_summary.dart';
import '../controllers/laporan_controller.dart';
import '../widgets/capital_growth_section.dart';

class LaporanPage extends ConsumerWidget {
  const LaporanPage({super.key});

  Future<void> _refresh(WidgetRef ref, ReportPeriod period) async {
    ref.invalidate(salesReportSnapshotByPeriodProvider(period));
    ref.invalidate(salesReportSnapshotProvider);
    ref.invalidate(capitalMetricsProvider);
    await ref.read(salesReportSnapshotByPeriodProvider(period).future);
    await ref.read(capitalMetricsProvider.future);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedPeriod = ref.watch(selectedReportPeriodProvider);
    final laporanAsync = ref.watch(salesReportSnapshotProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAF8),
      body: laporanAsync.when(
        data: (snapshot) {
          return RefreshIndicator(
            onRefresh: () => _refresh(ref, selectedPeriod),
            color: const Color(0xFF0D5C56),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              children: [
                // Custom Segmented Period Selector
                _buildPeriodSelector(context, ref, selectedPeriod),
                const SizedBox(height: 16),

                // Total Revenue Card
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isNarrow = constraints.maxWidth < 600;
                    final revenueCard = Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFBEC9C6).withValues(alpha: 0.3)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.02),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Total Pendapatan',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF3F4947),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                CurrencyFormatter.format(snapshot.revenue),
                                style: const TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0D5C56),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _formatRange(snapshot),
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 11,
                              color: Color(0xFF3F4947),
                            ),
                          ),
                        ],
                      ),
                    );

                    final marginCard = Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFBEC9C6).withValues(alpha: 0.3)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.02),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Keuntungan Bersih',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF3F4947),
                                ),
                              ),
                              if (!snapshot.marginIsComplete)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFDAD6),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'Margin belum lengkap',
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFFBA1A1A),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                snapshot.marginIsComplete
                                    ? CurrencyFormatter.format(snapshot.netProfit)
                                    : 'Belum Lengkap',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: snapshot.marginIsComplete
                                      ? const Color(0xFF0D5C56)
                                      : const Color(0xFFBA1A1A),
                                ),
                              ),
                              const SizedBox(width: 8),
                              if (snapshot.marginIsComplete && snapshot.revenue > 0)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFDDEEE7),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    '${(snapshot.netProfit / snapshot.revenue * 100).toStringAsFixed(0)}%',
                                    style: const TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF0D5C56),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (snapshot.marginIsComplete) ...[
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Margin Kotor:', style: TextStyle(fontSize: 10, color: Color(0xFF3F4947))),
                                Text(CurrencyFormatter.format(snapshot.margin), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                              ],
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('- Pengeluaran:', style: TextStyle(fontSize: 10, color: Color(0xFFBA1A1A))),
                                Text(CurrencyFormatter.format(snapshot.totalExpenses), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFBA1A1A))),
                              ],
                            ),
                            const SizedBox(height: 4),
                          ],
                          Text(
                            _formatRange(snapshot),
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 11,
                              color: Color(0xFF3F4947),
                            ),
                          ),
                        ],
                      ),
                    );

                    if (isNarrow) {
                      return Column(
                        children: [
                          revenueCard,
                          const SizedBox(height: 12),
                          marginCard,
                        ],
                      );
                    } else {
                      return Row(
                        children: [
                          Expanded(child: revenueCard),
                          const SizedBox(width: 12),
                          Expanded(child: marginCard),
                        ],
                      );
                    }
                  },
                ),
                const SizedBox(height: 12),

                // Transactions & Avg Value Bento Grid
                Row(
                  children: [
                    Expanded(
                      child: _buildBentoMetricCard(
                        title: 'Transaksi',
                        value: '${snapshot.transactionCount}',
                        subtitle: 'Total checkout selesai',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildBentoMetricCard(
                        title: 'Rata-rata Transaksi',
                        value: CurrencyFormatter.format(snapshot.averageTransactionValue),
                        subtitle: 'Rata-rata keranjang',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                if (!snapshot.hasTransactions)
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFBEC9C6).withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.insert_chart_outlined_rounded, size: 40, color: Color(0xFFBEC9C6)),
                        const SizedBox(height: 12),
                        const Text(
                          'Belum ada data laporan',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF191C1C),
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Simpan transaksi pertama agar omzet, metode pembayaran, dan rekap produk/jasa mulai terisi.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            color: Color(0xFF3F4947),
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 38,
                          child: FilledButton.icon(
                            onPressed: () => context.push(AppRoutes.transaction),
                            icon: const Icon(Icons.point_of_sale_outlined, size: 16),
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF0D5C56),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            label: const Text(
                              'Buat Transaksi',
                              style: TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                else ...[
                  // Top Selling Items Card
                  _buildTopSellingCard(snapshot.itemSummaries),
                  const SizedBox(height: 16),

                  // Top Margin Items Card
                  _buildTopMarginItemsCard(snapshot.topMarginItems, snapshot.catalogMarginIsComplete),
                  const SizedBox(height: 16),

                  // Payment Methods Breakdown Card
                  _buildPaymentMethodsCard(snapshot.paymentMethodBreakdown),
                  const SizedBox(height: 16),

                  // Sales Trend Card
                  _buildSalesTrendCard(snapshot.salesTrend, selectedPeriod),
                  const SizedBox(height: 16),

                  // Capital Growth & ROI Section
                  const CapitalGrowthSection(),
                ],
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.warning_amber_rounded, size: 48, color: Color(0xFFBA1A1A)),
                const SizedBox(height: 16),
                const Text(
                  'Gagal memuat laporan',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF191C1C),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  error.toString(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontFamily: 'Inter', color: Color(0xFF3F4947)),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => ref.invalidate(salesReportSnapshotProvider),
                  style: FilledButton.styleFrom(backgroundColor: const Color(0xFF0D5C56)),
                  child: const Text('Muat Ulang'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPeriodSelector(BuildContext context, WidgetRef ref, ReportPeriod selectedPeriod) {
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFFECEEED),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                for (final period in ReportPeriod.values.where((p) => p != ReportPeriod.kustom))
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        ref.read(selectedReportPeriodProvider.notifier).select(period);
                        ref.read(customReportRangeProvider.notifier).setRange(null);
                      },
                      child: Container(
                        alignment: Alignment.center,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: selectedPeriod == period ? const Color(0xFF0D5C56) : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          period.label,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: selectedPeriod == period ? Colors.white : const Color(0xFF3F4947),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          onPressed: () async {
            final now = DateTime.now();
            final currentRange = ref.read(customReportRangeProvider);
            final initialRange = currentRange != null 
                ? DateTimeRange(start: currentRange.start, end: currentRange.endExclusive.subtract(const Duration(days: 1))) 
                : DateTimeRange(start: now.subtract(const Duration(days: 7)), end: now);

            final picked = await showDateRangePicker(
              context: context,
              firstDate: DateTime(2020),
              lastDate: now,
              initialDateRange: initialRange,
              builder: (context, child) {
                return Theme(
                  data: Theme.of(context).copyWith(
                    colorScheme: const ColorScheme.light(
                      primary: Color(0xFF0D5C56),
                      onPrimary: Colors.white,
                      surface: Colors.white,
                      onSurface: Color(0xFF191C1C),
                    ),
                  ),
                  child: child!,
                );
              },
            );

            if (picked != null) {
              ref.read(customReportRangeProvider.notifier).setRange(ReportRange(
                start: picked.start,
                endExclusive: picked.end.add(const Duration(days: 1)),
              ));
              ref.read(selectedReportPeriodProvider.notifier).select(ReportPeriod.kustom);
            }
          },
          icon: Icon(
            Icons.calendar_month_outlined, 
            color: selectedPeriod == ReportPeriod.kustom ? const Color(0xFF0D5C56) : const Color(0xFF3F4947),
          ),
          style: IconButton.styleFrom(
            backgroundColor: selectedPeriod == ReportPeriod.kustom ? const Color(0xFFDDEEE7) : const Color(0xFFECEEED),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.all(12),
          ),
        ),
      ],
    );
  }

  Widget _buildBentoMetricCard({
    required String title,
    required String value,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFBEC9C6).withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Color(0xFF3F4947),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF191C1C),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 10,
              color: Color(0xFF3F4947),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopSellingCard(List<ItemSalesSummary> items) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFBEC9C6).withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Barang Terlaris',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Color(0xFF191C1C),
            ),
          ),
          const SizedBox(height: 16),
          for (int i = 0; i < items.length; i++) ...[
            _buildTopItemRow(items[i]),
            if (i != items.length - 1)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Divider(height: 1, thickness: 1, color: Color(0xFFF2F4F2)),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildTopItemRow(ItemSalesSummary item) {
    String? imageUrl;
    final nameLower = item.itemName.toLowerCase();
    if (nameLower.contains('espresso')) {
      imageUrl = 'https://lh3.googleusercontent.com/aida-public/AB6AXuC-IY8P8kbPiw7Tj6de85ViUnzT5HFgCr4XYnnLUSaTWS5KCrrwwKTwMgsopdDwXuTdwp6AdRwJlGsyYFJSuF8cIUw-CUyY8kUl-bh6ejEo2O6DsK7s26YlpY0dsf_seWFBMarOo04l12vQpi-IKD9N0BcNgzQVqHhTMcKZtQ_dHyN2VPt8evCNpA4a3OD3MO3LAI8QgjFCDBIfTBfemMW_iA2MYc_h4WDopM-3ObRLPc9nAthjEUx8';
    } else if (nameLower.contains('matcha')) {
      imageUrl = 'https://lh3.googleusercontent.com/aida-public/AB6AXuCgj_amFzOgHLhGY2wWxTyoT-7ofK0pOwT4djUezgrGDBpqMhJr_44s0-lCXbicDar4Wn4otWMTMSs-kcQIfhOzg5hQdz6T87B2ZAMjtYUe4AMsZT_Q5VD71itpaW0Kg4E0DjMFqCXhTHDoSb9Os57PjQlFGOCHR1WhKs50I-uccWPZ3jqki0LP17RMOqsJujimbY0GikVmvhhbCUKkmplEEnt3ksXnJMkkgMd6Ti3xBM9e-mG-wGIN';
    } else if (nameLower.contains('croissant')) {
      imageUrl = 'https://lh3.googleusercontent.com/aida-public/AB6AXuDtw6FzoRqsgJnhCOMFExNBi-djCa-zF3rZDMdZOLFbH4bTzKIjXoBSUMo3v0dWBy7boOi0M6UuQiivP5poXcYwYgSrPPiefB9lKppiE5ND6zqXFMnqqqiywwHLiOxp62DhWEJH32LLCSAa0Pki_GcRlZsv_TtPC8ve8lo-R8H4R5Q5cQO34yMXSMHnNP2cODt_TgHWJWlbEIo2AswHm0foxdgL3BwPnTL9vuIe8qsBhlh4ZlBgX8Xf';
    }

    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: const Color(0xFFECEEED),
            borderRadius: BorderRadius.circular(8),
            image: imageUrl != null
                ? DecorationImage(image: NetworkImage(imageUrl), fit: BoxFit.cover)
                : null,
          ),
          child: imageUrl == null
              ? Icon(
                  item.itemType == 'jasa' ? Icons.construction : Icons.local_cafe,
                  size: 20,
                  color: const Color(0xFFBEC9C6),
                )
              : null,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.itemName,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF191C1C),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                item.itemType == 'jasa' ? 'Layanan' : 'Produk',
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 11,
                  color: Color(0xFF3F4947),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '${item.quantitySold.toStringAsFixed(0)} terjual',
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0D5C56),
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentMethodsCard(Map<String, double> map) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFBEC9C6).withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Metode Pembayaran',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Color(0xFF191C1C),
            ),
          ),
          const SizedBox(height: 16),
          for (final entry in map.entries) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        entry.key,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          color: Color(0xFF191C1C),
                        ),
                      ),
                      Text(
                        '${(entry.value * 100).toStringAsFixed(0)}%',
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF191C1C),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: entry.value,
                      minHeight: 8,
                      backgroundColor: const Color(0xFFECEEED),
                      color: entry.key == map.keys.first ? const Color(0xFF0D5C56) : const Color(0xFF0D5C56),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSalesTrendCard(List<SalesTrendPoint> trend, ReportPeriod period) {
    String periodText = '24 Jam Terakhir';
    if (period == ReportPeriod.mingguan) {
      periodText = '7 Hari Terakhir';
    } else if (period == ReportPeriod.bulanan) {
      periodText = 'Bulan Ini';
    } else if (period == ReportPeriod.tahunan) {
      periodText = 'Tahun Ini';
    } else if (period == ReportPeriod.kustom) {
      periodText = 'Kustom';
    }

    final maxVal = trend.map((e) => e.value).fold<double>(0.0, (m, v) => v > m ? v : m);
    double interval = maxVal / 4;
    if (interval == 0) interval = 1;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFBEC9C6).withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Tren Penjualan',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF191C1C),
                ),
              ),
              Text(
                periodText,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 11,
                  color: Color(0xFF3F4947),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 180,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxVal * 1.2,
                barTouchData: BarTouchData(
                  enabled: true,
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => const Color(0xFF191C1C),
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      return BarTooltipItem(
                        CurrencyFormatter.format(rod.toY),
                        const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          fontFamily: 'Inter',
                        ),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index < 0 || index >= trend.length) return const SizedBox();
                        return Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            trend[index].label,
                            style: const TextStyle(
                              color: Color(0xFF3F4947),
                              fontSize: 9,
                              fontFamily: 'Inter',
                            ),
                          ),
                        );
                      },
                      reservedSize: 28,
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      interval: interval,
                      getTitlesWidget: (value, meta) {
                        if (value == 0) return const SizedBox();
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: Text(
                            _formatValueShort(value),
                            textAlign: TextAlign.right,
                            style: const TextStyle(
                              color: Color(0xFF3F4947),
                              fontSize: 10,
                              fontFamily: 'Inter',
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: interval,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: const Color(0xFFECEEED),
                      strokeWidth: 1,
                    );
                  },
                ),
                borderData: FlBorderData(show: false),
                barGroups: List.generate(trend.length, (index) {
                  final isMax = trend[index].value > 0 && trend[index].value == maxVal;
                  return BarChartGroupData(
                    x: index,
                    barRods: [
                      BarChartRodData(
                        toY: trend[index].value,
                        color: isMax ? const Color(0xFF0D5C56) : const Color(0xFFBEC9C6),
                        width: 16,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatValueShort(double value) {
    if (value == 0) return '0';
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    }
    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(0)}k';
    }
    return value.toStringAsFixed(0);
  }



  String _formatRange(SalesReportSnapshot snapshot) {
    switch (snapshot.period) {
      case ReportPeriod.harian:
        return _formatFullDate(snapshot.start);
      case ReportPeriod.mingguan:
        final end = snapshot.endExclusive.subtract(const Duration(days: 1));
        return '${_formatShortDate(snapshot.start)} - ${_formatShortDateWithYear(end)}';
      case ReportPeriod.bulanan:
        return _formatMonthYear(snapshot.start);
      case ReportPeriod.tahunan:
        return snapshot.start.year.toString();
      case ReportPeriod.kustom:
        final end = snapshot.endExclusive.subtract(const Duration(days: 1));
        return '${_formatShortDate(snapshot.start)} - ${_formatShortDateWithYear(end)}';
    }
  }

  String _formatFullDate(DateTime value) {
    const days = [
      'Senin',
      'Selasa',
      'Rabu',
      'Kamis',
      'Jumat',
      'Sabtu',
      'Minggu',
    ];

    return '${days[value.weekday - 1]}, ${_formatShortDateWithYear(value)}';
  }

  String _formatShortDate(DateTime value) {
    return '${value.day} ${_monthLabel(value.month)}';
  }

  String _formatShortDateWithYear(DateTime value) {
    return '${value.day} ${_monthLabel(value.month)} ${value.year}';
  }

  String _formatMonthYear(DateTime value) {
    return '${_monthLabel(value.month, long: true)} ${value.year}';
  }

  String _monthLabel(int month, {bool long = false}) {
    const shortMonths = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agu',
      'Sep',
      'Okt',
      'Nov',
      'Des',
    ];
    const longMonths = [
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember',
    ];

    return (long ? longMonths : shortMonths)[month - 1];
  }

  Widget _buildTopMarginItemsCard(List<MarginItemSummary> items, bool catalogMarginIsComplete) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFBEC9C6).withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Produk Margin Tertinggi',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF191C1C),
                ),
              ),
              if (!catalogMarginIsComplete)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFDAD6),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'Margin belum lengkap',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFBA1A1A),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'Belum ada data margin item.',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    color: Color(0xFF3F4947),
                  ),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: items.length,
              separatorBuilder: (context, index) => const Divider(height: 1, thickness: 1, color: Color(0xFFECEEED)),
              itemBuilder: (context, index) {
                final item = items[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    children: [
                      // Rank number badge
                      Container(
                        width: 24,
                        height: 24,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: index == 0 ? const Color(0xFF0D5C56) : const Color(0xFFECEEED),
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '${index + 1}',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: index == 0 ? Colors.white : const Color(0xFF3F4947),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Item Name & Category / Price
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.name,
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF191C1C),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${CurrencyFormatter.format(item.sellingPrice)}${item.unitLabel != null && item.unitLabel!.isNotEmpty ? '/${item.unitLabel}' : ''}',
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 12,
                                color: Color(0xFF3F4947),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Margin percent
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDDEEE7),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${item.marginPercent.toStringAsFixed(0)}% Margin',
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0D5C56),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
