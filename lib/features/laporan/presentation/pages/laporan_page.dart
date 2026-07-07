import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_router.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../domain/entities/item_sales_summary.dart';
import '../../domain/entities/report_period.dart';
import '../../domain/entities/sales_report_snapshot.dart';
import '../controllers/laporan_controller.dart';

class LaporanPage extends ConsumerWidget {
  const LaporanPage({super.key});

  Future<void> _refresh(WidgetRef ref, ReportPeriod period) async {
    ref.invalidate(salesReportSnapshotByPeriodProvider(period));
    ref.invalidate(salesReportSnapshotProvider);
    await ref.read(salesReportSnapshotByPeriodProvider(period).future);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedPeriod = ref.watch(selectedReportPeriodProvider);
    final laporanAsync = ref.watch(salesReportSnapshotProvider);

    return laporanAsync.when(
      data: (snapshot) {
        return RefreshIndicator(
          onRefresh: () => _refresh(ref, selectedPeriod),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Laporan Penjualan',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Pantau omzet, jumlah transaksi, dan rekap produk/jasa langsung dari data SQLite tanpa backend.',
                        style: Theme.of(
                          context,
                        ).textTheme.bodyMedium?.copyWith(height: 1.4),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final period in ReportPeriod.values)
                            ChoiceChip(
                              label: Text(period.label),
                              selected: selectedPeriod == period,
                              onSelected: (_) {
                                ref
                                    .read(selectedReportPeriodProvider.notifier)
                                    .select(period);
                              },
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF3A6452), Color(0xFF26463A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      selectedPeriod.label.toUpperCase(),
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: const Color(0xFFDDEEE7),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      CurrencyFormatter.format(snapshot.revenue),
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _formatRange(snapshot),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFFDDEEE7),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      selectedPeriod.description,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.32,
                children: [
                  _ReportMetricCard(
                    label: 'Jumlah Transaksi',
                    value: '${snapshot.transactionCount}',
                    supporting: snapshot.hasTransactions
                        ? 'Dalam periode ${selectedPeriod.label.toLowerCase()}'
                        : 'Belum ada transaksi',
                  ),
                  _ReportMetricCard(
                    label: 'Rata-Rata / Transaksi',
                    value: CurrencyFormatter.format(
                      snapshot.averageTransactionValue,
                    ),
                    supporting: 'Nilai rata-rata checkout',
                  ),
                  _ReportMetricCard(
                    label: 'Metode Pembayaran Top',
                    value: snapshot.topPaymentMethod ?? 'Belum ada',
                    supporting: snapshot.hasTransactions
                        ? 'Metode terbanyak dipakai'
                        : 'Akan muncul setelah ada penjualan',
                  ),
                  _ReportMetricCard(
                    label: 'Produk / Jasa Teratas',
                    value: snapshot.topItem?.itemName ?? 'Belum ada',
                    supporting: snapshot.topItem == null
                        ? 'Belum ada data item'
                        : '${snapshot.topItem!.quantitySold.toStringAsFixed(0)} unit/layanan',
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (!snapshot.hasTransactions)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        const Icon(Icons.insert_chart_outlined_rounded, size: 42),
                        const SizedBox(height: 14),
                        Text(
                          'Belum ada data laporan',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Simpan transaksi pertama agar omzet, metode pembayaran, dan rekap produk/jasa mulai terisi.',
                          textAlign: TextAlign.center,
                          style: Theme.of(
                            context,
                          ).textTheme.bodyMedium?.copyWith(height: 1.4),
                        ),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: () => context.push(AppRoutes.transaction),
                          icon: const Icon(Icons.point_of_sale_outlined),
                          label: const Text('Buat Transaksi'),
                        ),
                      ],
                    ),
                  ),
                )
              else ...[
                Text(
                  'Rekap Produk & Jasa',
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      children: [
                        for (var i = 0; i < snapshot.itemSummaries.length; i++) ...[
                          _ItemSummaryTile(item: snapshot.itemSummaries[i]),
                          if (i != snapshot.itemSummaries.length - 1)
                            const Divider(height: 24),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.warning_amber_rounded, size: 48),
                const SizedBox(height: 16),
                const Text(
                  'Gagal memuat laporan',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(error.toString(), textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => ref.invalidate(salesReportSnapshotProvider),
                  child: const Text('Muat Ulang'),
                ),
              ],
            ),
          ),
        );
      },
    );
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
    }
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

class _ReportMetricCard extends StatelessWidget {
  const _ReportMetricCard({
    required this.label,
    required this.value,
    required this.supporting,
  });

  final String label;
  final String value;
  final String supporting;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.bodyMedium),
            const Spacer(),
            Text(
              value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              supporting,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _ItemSummaryTile extends StatelessWidget {
  const _ItemSummaryTile({required this.item});

  final ItemSalesSummary item;

  @override
  Widget build(BuildContext context) {
    final badgeColor = item.itemType == 'jasa'
        ? const Color(0xFFDDEEE7)
        : const Color(0xFFFFE3CF);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: badgeColor,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(
            item.itemType == 'jasa'
                ? Icons.content_cut_rounded
                : Icons.inventory_2_outlined,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.itemName,
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                item.itemType == 'jasa' ? 'Jasa' : 'Barang',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              Text(
                '${item.quantitySold.toStringAsFixed(0)} terjual',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Text(
          CurrencyFormatter.format(item.totalSales),
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
      ],
    );
  }
}
