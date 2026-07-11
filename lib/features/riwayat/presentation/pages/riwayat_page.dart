import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../app/router/app_router.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../domain/entities/riwayat_transaksi_summary.dart';
import '../controllers/riwayat_controller.dart';

class RiwayatPage extends ConsumerStatefulWidget {
  const RiwayatPage({super.key});

  @override
  ConsumerState<RiwayatPage> createState() => _RiwayatPageState();
}

class _RiwayatPageState extends ConsumerState<RiwayatPage> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final riwayatAsync = ref.watch(riwayatControllerProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAF8),
      appBar: AppBar(
        toolbarHeight: 56,
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF0D5C56)),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Riwayat Transaksi',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0D5C56),
          ),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(
            height: 1,
            thickness: 1,
            color: Color(0xFFBEC9C6),
          ),
        ),
      ),
      body: riwayatAsync.when(
        data: (state) {
          if (state.allTransactions.isEmpty) {
            return _buildFullEmptyState(context);
          }

          final filteredRevenue = state.filteredTransactions.fold<double>(
            0,
            (total, transaction) => total + transaction.totalAmount,
          );

          return RefreshIndicator(
            onRefresh: () => ref.read(riwayatControllerProvider.notifier).refresh(),
            color: const Color(0xFF0D5C56),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              children: [
                // Search Bar Section
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFFBEC9C6).withValues(alpha: 0.3),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: ref.read(riwayatControllerProvider.notifier).updateSearch,
                    decoration: InputDecoration(
                      hintText: 'Cari faktur atau barang...',
                      prefixIcon: const Icon(Icons.search, color: Color(0xFF3F4947)),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: Color(0xFF0D5C56),
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Filters Chips Horizontal Scroll
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      // Date Filter Chips
                      _buildFilterChip(
                        label: 'Semua Tanggal',
                        selected: state.dateFilter == 'semua',
                        onTap: () => ref.read(riwayatControllerProvider.notifier).updateDateFilter('semua'),
                      ),
                      const SizedBox(width: 6),
                      _buildFilterChip(
                        label: 'Hari Ini',
                        selected: state.dateFilter == 'hari_ini',
                        onTap: () => ref.read(riwayatControllerProvider.notifier).updateDateFilter('hari_ini'),
                      ),
                      const SizedBox(width: 6),
                      _buildFilterChip(
                        label: '7 Hari',
                        selected: state.dateFilter == '7_hari',
                        onTap: () => ref.read(riwayatControllerProvider.notifier).updateDateFilter('7_hari'),
                      ),
                      const SizedBox(width: 6),
                      _buildFilterChip(
                        label: '30 Hari',
                        selected: state.dateFilter == '30_hari',
                        onTap: () => ref.read(riwayatControllerProvider.notifier).updateDateFilter('30_hari'),
                      ),
                      const SizedBox(width: 12),
                      // Divider line
                      Container(width: 1, height: 20, color: const Color(0xFFBEC9C6)),
                      const SizedBox(width: 12),
                      // Payment Option Chips
                      for (final paymentMethod in state.paymentOptions) ...[
                        _buildFilterChip(
                          label: _paymentLabel(paymentMethod),
                          selected: state.paymentFilter == paymentMethod,
                          onTap: () => ref.read(riwayatControllerProvider.notifier).updatePaymentFilter(paymentMethod),
                        ),
                        const SizedBox(width: 6),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Metrics Summary Card Bento
                Row(
                  children: [
                    Expanded(
                      child: _buildBentoCard(
                        title: 'Transaksi',
                        value: '${state.filteredTransactions.length}',
                        icon: Icons.receipt_long,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildBentoCard(
                        title: 'Omzet',
                        value: CurrencyFormatter.format(filteredRevenue),
                        icon: Icons.payments,
                        valueColor: const Color(0xFF0D5C56),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Transaction list section header
                Row(
                  children: const [
                    Text(
                      'TRANSAKSI TERBARU',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF3F4947),
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                if (state.allTransactions.isEmpty)
                  _buildEmptyState(
                    isFiltered: false,
                    onCreateTransaction: () => context.push(AppRoutes.transaction),
                  )
                else if (state.filteredTransactions.isEmpty)
                  _buildEmptyState(isFiltered: true)
                else
                  ...state.filteredTransactions.map((tx) => _buildTransactionCard(tx)),
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
                  'Gagal memuat riwayat transaksi',
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
                  onPressed: () => ref.invalidate(riwayatControllerProvider),
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

  Widget _buildFilterChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF0D5C56) : const Color(0xFFECEEED),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 12,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            color: selected ? Colors.white : const Color(0xFF3F4947),
          ),
        ),
      ),
    );
  }

  Widget _buildBentoCard({
    required String title,
    required String value,
    required IconData icon,
    Color? valueColor,
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
          Icon(icon, size: 20, color: const Color(0xFF3F4947)),
          const SizedBox(height: 12),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: valueColor ?? const Color(0xFF191C1C),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 11,
              color: Color(0xFF3F4947),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionCard(RiwayatTransaksiSummary tx) {
    final formattedDate = DateFormat('dd MMM yyyy, HH:mm', 'id_ID').format(tx.createdAt);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push('${AppRoutes.history}/${tx.invoiceNumber}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '#${tx.invoiceNumber}',
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0D5C56),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          formattedDate,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            color: Color(0xFF3F4947),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          tx.itemSummary,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 13,
                            color: Color(0xFF191C1C),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    CurrencyFormatter.format(tx.totalAmount),
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0D5C56),
                    ),
                  ),
                ],
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Divider(height: 1, thickness: 1, color: Color(0xFFF2F4F2)),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        _paymentIcon(tx.paymentMethod),
                        size: 16,
                        color: const Color(0xFF3F4947),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _paymentLabel(tx.paymentMethod),
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          color: Color(0xFF191C1C),
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECEEED),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${tx.itemCount} Barang',
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF3F4947),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState({
    required bool isFiltered,
    VoidCallback? onCreateTransaction,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFBEC9C6).withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          const Icon(Icons.receipt_long_outlined, size: 40, color: Color(0xFFBEC9C6)),
          const SizedBox(height: 12),
          Text(
            isFiltered ? 'Tidak ada transaksi yang cocok' : 'Riwayat transaksi masih kosong',
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Color(0xFF191C1C),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            isFiltered
                ? 'Ubah kata kunci pencarian atau filter untuk melihat transaksi lain.'
                : 'Simpan transaksi pertama agar daftar riwayat dan detail invoice mulai terisi.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              color: Color(0xFF3F4947),
              height: 1.4,
            ),
          ),
          if (!isFiltered && onCreateTransaction != null) ...[
            const SizedBox(height: 16),
            SizedBox(
              height: 38,
              child: FilledButton.icon(
                onPressed: onCreateTransaction,
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
        ],
      ),
    );
  }

  String _paymentLabel(String value) {
    switch (value) {
      case 'tunai':
      case 'cash':
        return 'Tunai';
      case 'transfer':
        return 'Transfer';
      case 'qris':
        return 'QRIS';
      case 'ewallet':
        return 'E-Wallet';
      case 'card':
      case 'kartu':
        return 'Kartu Debit/Kredit';
      case 'semua':
        return 'Semua Metode';
      default:
        return value.toUpperCase();
    }
  }

  IconData _paymentIcon(String value) {
    switch (value) {
      case 'tunai':
      case 'cash':
        return Icons.payments;
      case 'transfer':
        return Icons.account_balance;
      case 'qris':
        return Icons.qr_code;
      case 'ewallet':
        return Icons.account_balance_wallet;
      case 'card':
      case 'kartu':
        return Icons.credit_card;
      default:
        return Icons.payment;
    }
  }

  Widget _buildFullEmptyState(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Center(
            child: SizedBox(
              width: 200,
              height: 200,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 160,
                    height: 160,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D5C56).withValues(alpha: 0.05),
                      shape: BoxShape.circle,
                    ),
                  ),
                  Transform.rotate(
                    angle: -0.1,
                    child: Container(
                      width: 100,
                      height: 140,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFBEC9C6), width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(width: 40, height: 6, decoration: BoxDecoration(color: const Color(0xFFBEC9C6).withValues(alpha: 0.6), borderRadius: BorderRadius.circular(3))),
                          const SizedBox(height: 12),
                          Container(width: 76, height: 5, decoration: BoxDecoration(color: const Color(0xFFECEEED), borderRadius: BorderRadius.circular(3))),
                          const SizedBox(height: 8),
                          Container(width: 76, height: 5, decoration: BoxDecoration(color: const Color(0xFFECEEED), borderRadius: BorderRadius.circular(3))),
                          const SizedBox(height: 8),
                          Container(width: 50, height: 5, decoration: BoxDecoration(color: const Color(0xFFECEEED), borderRadius: BorderRadius.circular(3))),
                          const Spacer(),
                          const Divider(height: 1, thickness: 1, color: Color(0xFFBEC9C6)),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(width: 20, height: 10, decoration: BoxDecoration(color: const Color(0xFF8FD3CB), borderRadius: BorderRadius.circular(2))),
                              Container(width: 30, height: 10, decoration: BoxDecoration(color: const Color(0xFF0D5C56).withValues(alpha: 0.2), borderRadius: BorderRadius.circular(2))),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 10,
                    right: 20,
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0D5C56),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 6,
                            offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.receipt_long,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
          const SizedBox(height: 24),
          const Text(
            'Belum ada transaksi',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF191C1C),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Penjualan akan muncul di sini setelah Anda memproses pesanan pertama',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              color: Color(0xFF3F4947),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: 240,
            height: 52,
            child: FilledButton.icon(
              onPressed: () => context.push(AppRoutes.transaction),
              icon: const Icon(Icons.add_shopping_cart, size: 20),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF0D5C56),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              label: const Text(
                'Mulai Penjualan Baru',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
