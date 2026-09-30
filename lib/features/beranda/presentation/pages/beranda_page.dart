import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_router.dart';
import '../../../../core/services/app_startup_service.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/quantity_formatter.dart';
import '../../../laporan/presentation/controllers/laporan_controller.dart';
import '../../../riwayat/domain/entities/riwayat_transaksi_summary.dart';
import '../../../riwayat/presentation/controllers/riwayat_controller.dart';
import '../../../stok/domain/entities/stock_item.dart';
import '../../../stok/presentation/controllers/stok_controller.dart';

class BerandaPage extends ConsumerWidget {
  const BerandaPage({super.key});

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(businessProfileProvider);
    ref.invalidate(dashboardSummaryProvider);
    ref.invalidate(riwayatControllerProvider);
    ref.invalidate(stokControllerProvider);

    await Future.wait([
      ref.read(businessProfileProvider.future),
      ref.read(dashboardSummaryProvider.future),
      ref.read(riwayatControllerProvider.future),
      ref.read(stokControllerProvider.future),
    ]);
  }

  String _formatTime(DateTime value) {
    final hour = value.hour;
    final minute = value.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final hour12 = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '$hour12:$minute $period';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardAsync = ref.watch(dashboardSummaryProvider);
    final riwayatAsync = ref.watch(riwayatControllerProvider);
    final stokAsync = ref.watch(stokControllerProvider);

    return dashboardAsync.when(
      data: (summary) {
        final recentTransactions = riwayatAsync.maybeWhen(
          data: (state) => state.allTransactions.take(3).toList(),
          orElse: () => <RiwayatTransaksiSummary>[],
        );

        final lowStockItems = stokAsync.maybeWhen(
          data: (state) => state.lowStockItems.take(3).toList(),
          orElse: () => <StockItem>[],
        );

        return RefreshIndicator(
          onRefresh: () => _refresh(ref),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Daily Sales Summary Bento Section
              LayoutBuilder(
                builder: (context, constraints) {
                  final isNarrow = constraints.maxWidth < 720;
                  if (isNarrow) {
                    return Column(
                      children: [
                        _buildRevenueCard(
                          context,
                          summary.revenueToday,
                          summary.revenuePreviousDay,
                        ),
                        const SizedBox(height: 12),
                        _buildTransactionCard(
                          context,
                          summary.transactionCountToday,
                        ),
                        const SizedBox(height: 12),
                        _buildMarginCard(
                          context,
                          summary.marginToday,
                          summary.totalExpensesToday,
                          summary.netProfitToday,
                          summary.marginTodayIsComplete,
                        ),
                      ],
                    );
                  } else {
                    return Row(
                      children: [
                        Expanded(
                          child: _buildRevenueCard(
                            context,
                            summary.revenueToday,
                            summary.revenuePreviousDay,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildTransactionCard(
                            context,
                            summary.transactionCountToday,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildMarginCard(
                            context,
                            summary.marginToday,
                            summary.totalExpensesToday,
                            summary.netProfitToday,
                            summary.marginTodayIsComplete,
                          ),
                        ),
                      ],
                    );
                  }
                },
              ),
              const SizedBox(height: 24),
              // Quick Actions Section
              const Text(
                'Aksi Cepat',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF191C1C),
                ),
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () => context.push(AppRoutes.transaction),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D5C56),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.point_of_sale,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'Buat Transaksi',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Mulai pesanan baru',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 14,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.arrow_forward,
                        color: Colors.white,
                        size: 24,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => context.push(AppRoutes.catalogCreate),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0D5C56),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.add_box,
                                color: Colors.white,
                                size: 28,
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Tambah Item',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => context.push(AppRoutes.reports),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFFBEC9C6),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF2F4F2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.bar_chart,
                                color: Color(0xFF0D5C56),
                                size: 28,
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Laporan',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0D5C56),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => context.push(AppRoutes.addExpense),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFFBEC9C6),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF2F4F2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.money_off,
                                color: Color(0xFFBA1A1A),
                                size: 28,
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Pengeluaran',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFBA1A1A),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // Split Layout for Desktop / Tablet, Stack on Mobile
              LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth >= 600;
                  if (isWide) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 2,
                          child: _buildRecentTransactions(
                            context,
                            recentTransactions,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 1,
                          child: _buildLowStock(context, lowStockItems),
                        ),
                      ],
                    );
                  } else {
                    return Column(
                      children: [
                        _buildRecentTransactions(context, recentTransactions),
                        const SizedBox(height: 24),
                        _buildLowStock(context, lowStockItems),
                      ],
                    );
                  }
                },
              ),
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
                  'Gagal memuat dashboard',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(error.toString(), textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => ref.invalidate(dashboardSummaryProvider),
                  child: const Text('Muat Ulang'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRevenueCard(
    BuildContext context,
    double revenueToday,
    double? revenuePreviousDay,
  ) {
    final hasComparison = revenuePreviousDay != null && revenuePreviousDay > 0;
    final changePercent = hasComparison
        ? ((revenueToday - revenuePreviousDay) / revenuePreviousDay * 100)
        : null;
    final isUp = (changePercent ?? 0) >= 0;
    return Container(
      height: 140,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFECEEED)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Expanded(
                child: Text(
                  'Penjualan Hari Ini',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    color: Color(0xFF3F4947),
                  ),
                ),
              ),
              Icon(Icons.payments, color: Color(0xFF0D5C56)),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  CurrencyFormatter.format(revenueToday),
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF191C1C),
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  if (hasComparison) ...[
                    Icon(
                      isUp ? Icons.trending_up : Icons.trending_down,
                      color: isUp
                          ? const Color(0xFF0D5C56)
                          : const Color(0xFFBA1A1A),
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                  ],
                  Expanded(
                    child: Text(
                      hasComparison
                          ? '${isUp ? '+' : '-'}${changePercent!.abs().toStringAsFixed(1)}% dari kemarin'
                          : 'Belum ada data pembanding',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: hasComparison && !isUp
                            ? const Color(0xFFBA1A1A)
                            : const Color(0xFF0D5C56),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionCard(BuildContext context, int transactionCount) {
    return Container(
      height: 140,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFECEEED)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Expanded(
                child: Text(
                  'Transaksi',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    color: Color(0xFF3F4947),
                  ),
                ),
              ),
              Icon(Icons.receipt_long, color: Color(0xFF0D5C56)),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$transactionCount',
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF191C1C),
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Transaksi hari ini',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  color: Color(0xFF3F4947),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMarginCard(
    BuildContext context,
    double marginToday,
    double totalExpensesToday,
    double netProfitToday,
    bool isComplete,
  ) {
    return Container(
      height: 160,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFECEEED)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Expanded(
                child: Text(
                  'Keuntungan Bersih',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    color: Color(0xFF3F4947),
                  ),
                ),
              ),
              Icon(Icons.account_balance_wallet, color: Color(0xFF0D5C56)),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  isComplete
                      ? CurrencyFormatter.format(netProfitToday)
                      : 'Belum Lengkap',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: isComplete ? 28 : 22,
                    fontWeight: FontWeight.bold,
                    color: isComplete
                        ? const Color(0xFF191C1C)
                        : const Color(0xFFBA1A1A),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              if (isComplete) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Margin Kotor:',
                      style: TextStyle(fontSize: 10, color: Color(0xFF3F4947)),
                    ),
                    Text(
                      CurrencyFormatter.format(marginToday),
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
                      style: TextStyle(fontSize: 10, color: Color(0xFFBA1A1A)),
                    ),
                    Text(
                      CurrencyFormatter.format(totalExpensesToday),
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFBA1A1A),
                      ),
                    ),
                  ],
                ),
              ] else
                const Text(
                  'Isi harga modal produk',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11,
                    color: Color(0xFF3F4947),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRecentTransactions(
    BuildContext context,
    List<RiwayatTransaksiSummary> transactions,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Expanded(
              child: Text(
                'Transaksi Terakhir',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF191C1C),
                ),
              ),
            ),
            TextButton(
              onPressed: () => context.push(AppRoutes.history),
              child: const Text(
                'Lihat Semua',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0D5C56),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFECEEED)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: transactions.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                    child: Text(
                      'Belum ada transaksi hari ini.',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        color: Color(0xFF3F4947),
                      ),
                    ),
                  ),
                )
              : Column(
                  children: [
                    for (int i = 0; i < transactions.length; i++) ...[
                      InkWell(
                        onTap: () => context.push(
                          '${AppRoutes.history}/${transactions[i].invoiceNumber}',
                        ),
                        child: Container(
                          height: 72,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF8ED2CA),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.receipt,
                                  color: Color(0xFF0D5C56),
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      'Pesanan #${transactions[i].invoiceNumber}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF191C1C),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _formatTime(transactions[i].createdAt),
                                      style: const TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 12,
                                        color: Color(0xFF3F4947),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                CurrencyFormatter.format(
                                  transactions[i].totalAmount,
                                ),
                                style: const TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF191C1C),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (i < transactions.length - 1)
                        const Divider(
                          height: 1,
                          thickness: 1,
                          color: Color(0xFFECEEED),
                          indent: 16,
                          endIndent: 16,
                        ),
                    ],
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildLowStock(BuildContext context, List<StockItem> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: const [
            Icon(Icons.warning, color: Color(0xFFBA1A1A), size: 22),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Peringatan Stok Menipis',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF191C1C),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFFFFDAD6),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFFFB4AB)),
          ),
          child: items.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                  child: Text(
                    'Semua stok barang aman.',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      color: Color(0xFFBA1A1A),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )
              : Column(
                  children: [
                    for (int i = 0; i < items.length; i++) ...[
                      GestureDetector(
                        onTap: () =>
                            context.push('${AppRoutes.stock}/${items[i].id}'),
                        child: Container(
                          height: 48,
                          margin: EdgeInsets.only(
                            bottom: i < items.length - 1 ? 8 : 0,
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.04),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  items[i].name,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 14,
                                    color: Color(0xFF191C1C),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${QuantityFormatter.format(items[i].currentStock)} tersisa',
                                style: const TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 14,
                                  color: Color(0xFFBA1A1A),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
        ),
      ],
    );
  }
}
