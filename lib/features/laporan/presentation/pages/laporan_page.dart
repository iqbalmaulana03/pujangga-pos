import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_router.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/quantity_formatter.dart';
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
                        border: Border.all(
                          color: const Color(0xFFBEC9C6).withValues(alpha: 0.3),
                        ),
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
                        border: Border.all(
                          color: const Color(0xFFBEC9C6).withValues(alpha: 0.3),
                        ),
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
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
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
                                    ? CurrencyFormatter.format(
                                        snapshot.netProfit,
                                      )
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
                              if (snapshot.marginIsComplete &&
                                  snapshot.revenue > 0)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
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
                                const Text(
                                  'Margin Kotor:',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Color(0xFF3F4947),
                                  ),
                                ),
                                Text(
                                  CurrencyFormatter.format(snapshot.margin),
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  '- Pengeluaran:',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Color(0xFFBA1A1A),
                                  ),
                                ),
                                Text(
                                  CurrencyFormatter.format(
                                    snapshot.totalExpenses,
                                  ),
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFFBA1A1A),
                                  ),
                                ),
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
                        value: CurrencyFormatter.format(
                          snapshot.averageTransactionValue,
                        ),
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
                      border: Border.all(
                        color: const Color(0xFFBEC9C6).withValues(alpha: 0.3),
                      ),
                    ),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.insert_chart_outlined_rounded,
                          size: 40,
                          color: Color(0xFFBEC9C6),
                        ),
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
                            onPressed: () =>
                                context.push(AppRoutes.transaction),
                            icon: const Icon(
                              Icons.point_of_sale_outlined,
                              size: 16,
                            ),
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF0D5C56),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            label: const Text(
                              'Buat Transaksi',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
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
                  _buildTopMarginItemsCard(
                    snapshot.topMarginItems,
                    snapshot.catalogMarginIsComplete,
                  ),
                  const SizedBox(height: 16),

                  // Payment Methods Breakdown Card
                  _buildPaymentMethodsCard(snapshot.paymentMethodBreakdown),
                  const SizedBox(height: 16),

                  // Sales Trend Card
                  _buildSalesTrendCard(
                    snapshot.salesTrend,
                    snapshot.salesCandles,
                    selectedPeriod,
                  ),
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
                const Icon(
                  Icons.warning_amber_rounded,
                  size: 48,
                  color: Color(0xFFBA1A1A),
                ),
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
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    color: Color(0xFF3F4947),
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => ref.invalidate(salesReportSnapshotProvider),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF0D5C56),
                  ),
                  child: const Text('Muat Ulang'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPeriodSelector(
    BuildContext context,
    WidgetRef ref,
    ReportPeriod selectedPeriod,
  ) {
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
                for (final period in ReportPeriod.values.where(
                  (p) => p != ReportPeriod.kustom,
                ))
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        ref
                            .read(selectedReportPeriodProvider.notifier)
                            .select(period);
                        ref
                            .read(customReportRangeProvider.notifier)
                            .setRange(null);
                      },
                      child: Container(
                        alignment: Alignment.center,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: selectedPeriod == period
                              ? const Color(0xFF0D5C56)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          period.label,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: selectedPeriod == period
                                ? Colors.white
                                : const Color(0xFF3F4947),
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
                ? DateTimeRange(
                    start: currentRange.start,
                    end: currentRange.endExclusive.subtract(
                      const Duration(days: 1),
                    ),
                  )
                : DateTimeRange(
                    start: now.subtract(const Duration(days: 7)),
                    end: now,
                  );

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
              ref
                  .read(customReportRangeProvider.notifier)
                  .setRange(
                    ReportRange(
                      start: picked.start,
                      endExclusive: picked.end.add(const Duration(days: 1)),
                    ),
                  );
              ref
                  .read(selectedReportPeriodProvider.notifier)
                  .select(ReportPeriod.kustom);
            }
          },
          icon: Icon(
            Icons.calendar_month_outlined,
            color: selectedPeriod == ReportPeriod.kustom
                ? const Color(0xFF0D5C56)
                : const Color(0xFF3F4947),
          ),
          style: IconButton.styleFrom(
            backgroundColor: selectedPeriod == ReportPeriod.kustom
                ? const Color(0xFFDDEEE7)
                : const Color(0xFFECEEED),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
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
                child: Divider(
                  height: 1,
                  thickness: 1,
                  color: Color(0xFFF2F4F2),
                ),
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
      imageUrl =
          'https://lh3.googleusercontent.com/aida-public/AB6AXuC-IY8P8kbPiw7Tj6de85ViUnzT5HFgCr4XYnnLUSaTWS5KCrrwwKTwMgsopdDwXuTdwp6AdRwJlGsyYFJSuF8cIUw-CUyY8kUl-bh6ejEo2O6DsK7s26YlpY0dsf_seWFBMarOo04l12vQpi-IKD9N0BcNgzQVqHhTMcKZtQ_dHyN2VPt8evCNpA4a3OD3MO3LAI8QgjFCDBIfTBfemMW_iA2MYc_h4WDopM-3ObRLPc9nAthjEUx8';
    } else if (nameLower.contains('matcha')) {
      imageUrl =
          'https://lh3.googleusercontent.com/aida-public/AB6AXuCgj_amFzOgHLhGY2wWxTyoT-7ofK0pOwT4djUezgrGDBpqMhJr_44s0-lCXbicDar4Wn4otWMTMSs-kcQIfhOzg5hQdz6T87B2ZAMjtYUe4AMsZT_Q5VD71itpaW0Kg4E0DjMFqCXhTHDoSb9Os57PjQlFGOCHR1WhKs50I-uccWPZ3jqki0LP17RMOqsJujimbY0GikVmvhhbCUKkmplEEnt3ksXnJMkkgMd6Ti3xBM9e-mG-wGIN';
    } else if (nameLower.contains('croissant')) {
      imageUrl =
          'https://lh3.googleusercontent.com/aida-public/AB6AXuDtw6FzoRqsgJnhCOMFExNBi-djCa-zF3rZDMdZOLFbH4bTzKIjXoBSUMo3v0dWBy7boOi0M6UuQiivP5poXcYwYgSrPPiefB9lKppiE5ND6zqXFMnqqqiywwHLiOxp62DhWEJH32LLCSAa0Pki_GcRlZsv_TtPC8ve8lo-R8H4R5Q5cQO34yMXSMHnNP2cODt_TgHWJWlbEIo2AswHm0foxdgL3BwPnTL9vuIe8qsBhlh4ZlBgX8Xf';
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
                ? DecorationImage(
                    image: NetworkImage(imageUrl),
                    fit: BoxFit.cover,
                  )
                : null,
          ),
          child: imageUrl == null
              ? Icon(
                  item.itemType == 'jasa'
                      ? Icons.construction
                      : Icons.local_cafe,
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
          '${QuantityFormatter.format(item.quantitySold)} terjual',
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
                      color: entry.key == map.keys.first
                          ? const Color(0xFF0D5C56)
                          : const Color(0xFF0D5C56),
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

  Widget _buildSalesTrendCard(
    List<SalesTrendPoint> trend,
    List<SalesCandlePoint> candles,
    ReportPeriod period,
  ) {
    return _SalesTrendCard(
      trend: trend,
      candles: candles,
      period: period,
      formatValueShort: _formatValueShort,
    );
  }

  String _formatValueShort(double value) {
    if (value == 0) return '0';
    if (value >= 1000000000000) {
      return '${(value / 1000000000000).toStringAsFixed(1)}T';
    }
    if (value >= 1000000000) {
      return '${(value / 1000000000).toStringAsFixed(1)}B';
    }
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    }
    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}k';
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

  Widget _buildTopMarginItemsCard(
    List<MarginItemSummary> items,
    bool catalogMarginIsComplete,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFBEC9C6).withValues(alpha: 0.3),
        ),
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
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
              separatorBuilder: (context, index) => const Divider(
                height: 1,
                thickness: 1,
                color: Color(0xFFECEEED),
              ),
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
                          color: index == 0
                              ? const Color(0xFF0D5C56)
                              : const Color(0xFFECEEED),
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '${index + 1}',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: index == 0
                                ? Colors.white
                                : const Color(0xFF3F4947),
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
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
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

enum _SalesChartMode { trend, comparison }

class _SalesTrendCard extends StatefulWidget {
  const _SalesTrendCard({
    required this.trend,
    required this.candles,
    required this.period,
    required this.formatValueShort,
  });

  final List<SalesTrendPoint> trend;
  final List<SalesCandlePoint> candles;
  final ReportPeriod period;
  final String Function(double value) formatValueShort;

  @override
  State<_SalesTrendCard> createState() => _SalesTrendCardState();
}

class _SalesTrendCardState extends State<_SalesTrendCard> {
  _SalesChartMode _mode = _SalesChartMode.trend;
  int? _selectedBucketIndex;

  String get _periodText {
    switch (widget.period) {
      case ReportPeriod.harian:
        return 'Hari Ini';
      case ReportPeriod.mingguan:
        return '7 Hari Terakhir';
      case ReportPeriod.bulanan:
        return 'Bulan Ini';
      case ReportPeriod.tahunan:
        return 'Tahun Ini';
      case ReportPeriod.kustom:
        return 'Kustom';
    }
  }

  SalesCandlePoint? get _selectedCandle {
    if (widget.candles.isEmpty) return null;
    for (final candle in widget.candles) {
      if (candle.bucketIndex == _selectedBucketIndex) return candle;
    }
    return widget.candles.last;
  }

  @override
  Widget build(BuildContext context) {
    final selectedCandle = _selectedCandle;
    final title = _mode == _SalesChartMode.trend
        ? 'Tren Omzet'
        : 'Perbandingan Transaksi';
    final description = _mode == _SalesChartMode.trend
        ? 'Omzet pada setiap interval waktu.'
        : 'Lilin merangkum transaksi pertama, tertinggi, terendah, dan terakhir.';

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
              Flexible(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF191C1C),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _periodText,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 11,
                  color: Color(0xFF3F4947),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              _modeChip('Tren', _SalesChartMode.trend),
              _modeChip('Perbandingan', _SalesChartMode.comparison),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 11,
              color: Color(0xFF3F4947),
            ),
          ),
          const SizedBox(height: 12),
          if (_mode == _SalesChartMode.trend)
            _buildLineChart()
          else if (widget.candles.isEmpty)
            const SizedBox(
              height: 180,
              child: Center(
                child: Text(
                  'Belum ada transaksi pada rentang ini.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    color: Color(0xFF3F4947),
                  ),
                ),
              ),
            )
          else
            Column(
              children: [
                SizedBox(
                  height: 190,
                  width: double.infinity,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTapDown: (details) {
                          if (widget.trend.isEmpty) return;
                          const left = 54.0;
                          const rightInset = 8.0;
                          final plotWidth =
                              constraints.maxWidth - left - rightInset;
                          if (plotWidth <= 0) return;
                          final relative =
                              ((details.localPosition.dx - left) / plotWidth)
                                  .clamp(0.0, 1.0);
                          final target = (relative * (widget.trend.length - 1))
                              .round();
                          final nearest = widget.candles.reduce((a, b) {
                            return (a.bucketIndex - target).abs() <=
                                    (b.bucketIndex - target).abs()
                                ? a
                                : b;
                          });
                          setState(() {
                            _selectedBucketIndex = nearest.bucketIndex;
                          });
                        },
                        child: CustomPaint(
                          painter: _SalesCandlestickPainter(
                            trend: widget.trend,
                            candles: widget.candles,
                            selectedBucketIndex: selectedCandle?.bucketIndex,
                            formatValueShort: widget.formatValueShort,
                          ),
                          child: const SizedBox.expand(),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
                _buildCandleLegend(),
                if (selectedCandle != null) ...[
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '${selectedCandle.label} · ${selectedCandle.transactionCount} transaksi',
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF191C1C),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _ohlcValue('Buka', selectedCandle.open),
                      _ohlcValue('Tertinggi', selectedCandle.high),
                      _ohlcValue('Terendah', selectedCandle.low),
                      _ohlcValue('Tutup', selectedCandle.close),
                    ],
                  ),
                ],
              ],
            ),
        ],
      ),
    );
  }

  Widget _modeChip(String label, _SalesChartMode mode) {
    final selected = _mode == mode;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) {
        setState(() => _mode = mode);
      },
      showCheckmark: false,
      selectedColor: const Color(0xFFDDEEE7),
      backgroundColor: const Color(0xFFF3F6F5),
      side: BorderSide(
        color: selected ? const Color(0xFF0D5C56) : const Color(0xFFBEC9C6),
      ),
      labelStyle: TextStyle(
        fontFamily: 'Inter',
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: selected ? const Color(0xFF0D5C56) : const Color(0xFF3F4947),
      ),
    );
  }

  Widget _buildLineChart() {
    if (widget.trend.isEmpty) {
      return const SizedBox(
        height: 180,
        child: Center(
          child: Text(
            'Belum ada data laporan.',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              color: Color(0xFF3F4947),
            ),
          ),
        ),
      );
    }

    final maxValue = widget.trend.fold<double>(
      0,
      (maximum, point) => point.value > maximum ? point.value : maximum,
    );
    final chartMax = maxValue > 0 ? maxValue * 1.2 : 1.0;
    final interval = chartMax / 4;
    final labelIndices = widget.trend.length > 8
        ? List<int>.generate(
            8,
            (step) => ((widget.trend.length - 1) * step / 7).round(),
          ).toSet()
        : Set<int>.from(
            List<int>.generate(widget.trend.length, (index) => index),
          );

    return SizedBox(
      height: 190,
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: math.max(1, widget.trend.length - 1).toDouble(),
          minY: 0,
          maxY: chartMax,
          lineTouchData: LineTouchData(
            enabled: true,
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => const Color(0xFF191C1C),
              getTooltipItems: (spots) => spots
                  .map(
                    (spot) => LineTooltipItem(
                      CurrencyFormatter.format(spot.y),
                      const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        fontFamily: 'Inter',
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 1,
                reservedSize: 28,
                getTitlesWidget: (value, meta) {
                  final index = value.round();
                  if (index < 0 ||
                      index >= widget.trend.length ||
                      !labelIndices.contains(index)) {
                    return const SizedBox();
                  }
                  var label = widget.trend[index].label;
                  if (widget.trend.length >= 24 && label.contains(':')) {
                    label = label.split(':').first;
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      label,
                      style: const TextStyle(
                        color: Color(0xFF3F4947),
                        fontSize: 8,
                        fontFamily: 'Inter',
                      ),
                    ),
                  );
                },
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
                    padding: const EdgeInsets.only(right: 8),
                    child: Text(
                      widget.formatValueShort(value),
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
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: interval,
            getDrawingHorizontalLine: (_) =>
                const FlLine(color: Color(0xFFECEEED), strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: [
                for (var i = 0; i < widget.trend.length; i++)
                  FlSpot(i.toDouble(), widget.trend[i].value),
              ],
              isCurved: false,
              color: const Color(0xFF0D5C56),
              barWidth: 2.5,
              dotData: FlDotData(show: widget.trend.length <= 14),
              belowBarData: BarAreaData(
                show: true,
                color: const Color(0xFF0D5C56).withValues(alpha: 0.08),
              ),
            ),
          ],
        ),
        duration: Duration.zero,
      ),
    );
  }

  Widget _buildCandleLegend() {
    return Row(
      children: [
        _legendSwatch(const Color(0xFF0D5C56), 'Naik'),
        const SizedBox(width: 16),
        _legendSwatch(const Color(0xFFB3261E), 'Turun'),
        const Spacer(),
        const Text(
          'Ketuk lilin untuk rincian',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 10,
            color: Color(0xFF3F4947),
          ),
        ),
      ],
    );
  }

  Widget _legendSwatch(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 10,
            color: Color(0xFF3F4947),
          ),
        ),
      ],
    );
  }

  Widget _ohlcValue(String label, double value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 9,
              color: Color(0xFF3F4947),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            CurrencyFormatter.format(value),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Color(0xFF191C1C),
            ),
          ),
        ],
      ),
    );
  }
}

class _SalesCandlestickPainter extends CustomPainter {
  const _SalesCandlestickPainter({
    required this.trend,
    required this.candles,
    required this.selectedBucketIndex,
    required this.formatValueShort,
  });

  final List<SalesTrendPoint> trend;
  final List<SalesCandlePoint> candles;
  final int? selectedBucketIndex;
  final String Function(double value) formatValueShort;

  @override
  void paint(Canvas canvas, Size size) {
    if (trend.isEmpty ||
        candles.isEmpty ||
        size.width <= 64 ||
        size.height <= 40) {
      return;
    }

    const left = 52.0;
    const right = 8.0;
    const top = 8.0;
    const bottom = 30.0;
    final plot = Rect.fromLTRB(
      left,
      top,
      size.width - right,
      size.height - bottom,
    );
    if (plot.width <= 0 || plot.height <= 0) return;

    var minValue = candles.first.low;
    var maxValue = candles.first.high;
    for (final candle in candles.skip(1)) {
      if (candle.low < minValue) minValue = candle.low;
      if (candle.high > maxValue) maxValue = candle.high;
    }
    final rawRange = maxValue - minValue;
    final padding = math
        .max(math.max(rawRange * 0.1, maxValue.abs() * 0.1), 1.0)
        .toDouble();
    final minY = math.max(0.0, minValue - padding).toDouble();
    final maxY = maxValue + padding;
    final yRange = math.max(maxY - minY, 1.0).toDouble();

    double yFor(double value) =>
        plot.bottom - ((value - minY) / yRange) * plot.height;
    double xFor(int index) => trend.length <= 1
        ? plot.left + plot.width / 2
        : plot.left + (index / (trend.length - 1)) * plot.width;

    final gridPaint = Paint()
      ..color = const Color(0xFFECEEED)
      ..strokeWidth = 1;
    for (var step = 0; step <= 4; step++) {
      final fraction = step / 4;
      final y = plot.bottom - fraction * plot.height;
      canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), gridPaint);
      final value = minY + fraction * yRange;
      _drawText(
        canvas,
        formatValueShort(value),
        Offset(0, y - 6),
        const TextStyle(
          color: Color(0xFF3F4947),
          fontSize: 9,
          fontFamily: 'Inter',
        ),
        maxWidth: left - 5,
        textAlign: TextAlign.right,
      );
    }

    final labelIndices = trend.length > 8
        ? List<int>.generate(
            8,
            (step) => ((trend.length - 1) * step / 7).round(),
          ).toSet()
        : Set<int>.from(List<int>.generate(trend.length, (index) => index));
    for (final index in labelIndices) {
      var label = trend[index].label;
      if (trend.length >= 24 && label.contains(':')) {
        label = label.split(':').first;
      }
      _drawText(
        canvas,
        label,
        Offset(xFor(index) - 18, plot.bottom + 7),
        const TextStyle(
          color: Color(0xFF3F4947),
          fontSize: 8,
          fontFamily: 'Inter',
        ),
        maxWidth: 36,
        textAlign: TextAlign.center,
      );
    }

    final slotWidth = plot.width / trend.length;
    final bodyWidth = (slotWidth * 0.52).clamp(2.0, 12.0).toDouble();
    for (final candle in candles) {
      final x = xFor(candle.bucketIndex);
      if (candle.bucketIndex == selectedBucketIndex) {
        final selectedPaint = Paint()
          ..color = const Color(0xFFDDEEE7).withValues(alpha: 0.55);
        canvas.drawRect(
          Rect.fromLTRB(
            x - slotWidth / 2,
            plot.top,
            x + slotWidth / 2,
            plot.bottom,
          ),
          selectedPaint,
        );
      }

      final color = candle.close >= candle.open
          ? const Color(0xFF0D5C56)
          : const Color(0xFFB3261E);
      final paint = Paint()
        ..color = color
        ..strokeWidth = 1.5;
      canvas.drawLine(
        Offset(x, yFor(candle.high)),
        Offset(x, yFor(candle.low)),
        paint,
      );

      final openY = yFor(candle.open);
      final closeY = yFor(candle.close);
      final bodyTop = math.min(openY, closeY).toDouble();
      final bodyBottom = math.max(openY, closeY).toDouble();
      final bodyHeight = math.max(bodyBottom - bodyTop, 2.0).toDouble();
      canvas.drawRect(
        Rect.fromLTWH(
          x - bodyWidth / 2,
          bodyTop - (bodyHeight == 2.0 && bodyBottom == bodyTop ? 1 : 0),
          bodyWidth,
          bodyHeight,
        ),
        paint,
      );
    }
  }

  void _drawText(
    Canvas canvas,
    String text,
    Offset offset,
    TextStyle style, {
    required double maxWidth,
    TextAlign textAlign = TextAlign.left,
  }) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textAlign: textAlign,
      maxLines: 1,
      ellipsis: '...',
    )..layout(maxWidth: maxWidth);
    painter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _SalesCandlestickPainter oldDelegate) =>
      oldDelegate.trend != trend ||
      oldDelegate.candles != candles ||
      oldDelegate.selectedBucketIndex != selectedBucketIndex;
}
