import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_router.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/quantity_formatter.dart';
import '../../domain/entities/stock_item.dart';
import '../controllers/stok_controller.dart';

class StokPage extends ConsumerStatefulWidget {
  const StokPage({super.key});

  @override
  ConsumerState<StokPage> createState() => _StokPageState();
}

class _StokPageState extends ConsumerState<StokPage> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stokAsync = ref.watch(stokControllerProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAF8),
      body: stokAsync.when(
        data: (state) {
          final outOfStockCount = state.allItems
              .where((item) => item.currentStock == 0)
              .length;

          return RefreshIndicator(
            onRefresh: () =>
                ref.read(stokControllerProvider.notifier).refresh(),
            color: const Color(0xFF0D5C56),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              children: [
                // Top Metrics Cards Bento
                Row(
                  children: [
                    Expanded(
                      child: _buildMetricCard(
                        title: 'Barang Dipantau',
                        value: '${state.totalItems}',
                        valueColor: const Color(0xFF0D5C56),
                        icon: Icons.inventory_2_outlined,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildMetricCard(
                        title: 'Stok Menipis',
                        value: '${state.lowStockCount}',
                        valueColor: const Color(0xFF9C4F1A),
                        icon: Icons.warning_amber_rounded,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildMetricCard(
                        title: 'Stok Habis',
                        value: '$outOfStockCount',
                        valueColor: const Color(0xFFBA1A1A),
                        icon: Icons.error_outline_rounded,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildMetricCard(
                        title: 'Nilai Aset Stok',
                        value: CurrencyFormatter.format(
                          state.liveAssetValuation,
                        ),
                        valueColor: const Color(0xFF0D5C56),
                        icon: Icons.account_balance_wallet_outlined,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildMetricCard(
                        title: 'Stok Mati (Dead Stock)',
                        value: CurrencyFormatter.format(
                          state.deadStockValuation,
                        ),
                        valueColor: const Color(0xFFBA1A1A),
                        icon: Icons.money_off_outlined,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Search & Category Filter Section Card
                Container(
                  padding: const EdgeInsets.all(16),
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: _searchController,
                        onChanged: ref
                            .read(stokControllerProvider.notifier)
                            .updateSearch,
                        decoration: InputDecoration(
                          hintText: 'Cari nama barang, kategori, atau SKU...',
                          prefixIcon: const Icon(
                            Icons.search,
                            color: Color(0xFF3F4947),
                          ),
                          filled: true,
                          fillColor: const Color(0xFFF2F4F2),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: const BorderSide(
                              color: Color(0xFF0D5C56),
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            for (final category in state.categories) ...[
                              GestureDetector(
                                onTap: () {
                                  ref
                                      .read(stokControllerProvider.notifier)
                                      .updateCategoryFilter(category);
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: state.categoryFilter == category
                                        ? const Color(0xFF0D5C56)
                                        : const Color(0xFFECEEED),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Text(
                                    category == 'semua'
                                        ? 'Semua Kategori'
                                        : category,
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 12,
                                      fontWeight:
                                          state.categoryFilter == category
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                      color: state.categoryFilter == category
                                          ? Colors.white
                                          : const Color(0xFF3F4947),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Attention section if items are low stock
                if (state.lowStockItems.isNotEmpty) ...[
                  Row(
                    children: const [
                      Icon(
                        Icons.notification_important_outlined,
                        color: Color(0xFF9C4F1A),
                        size: 20,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'Perlu Perhatian Segera',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF9C4F1A),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ...state.lowStockItems
                      .take(2)
                      .map(
                        (item) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _buildAttentionCard(item),
                        ),
                      ),
                  const SizedBox(height: 10),
                ],

                // Main stock item list
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    Text(
                      'Daftar Stok Barang',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF191C1C),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                if (state.allItems.isEmpty)
                  _buildEmptyStateCard(
                    icon: Icons.inventory_2_outlined,
                    title: 'Belum ada barang di katalog',
                    subtitle:
                        'Tambahkan item bertipe barang dari katalog agar modul stok mulai menampilkan ringkasan.',
                    actionLabel: 'Tambah Item',
                    onAction: () => context.push(AppRoutes.catalogCreate),
                  )
                else if (state.filteredItems.isEmpty)
                  _buildEmptyStateCard(
                    icon: Icons.filter_alt_off_outlined,
                    title: 'Tidak ada barang yang cocok',
                    subtitle:
                        'Ubah kata kunci pencarian atau filter kategori untuk melihat item lain.',
                  )
                else
                  ...state.filteredItems.map(
                    (item) => _buildStockItemCard(item),
                  ),
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
                  'Gagal memuat data stok',
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
                  onPressed: () => ref.invalidate(stokControllerProvider),
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

  Widget _buildMetricCard({
    required String title,
    required String value,
    required Color valueColor,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
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
            children: [Icon(icon, size: 18, color: const Color(0xFF3F4947))],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: valueColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF3F4947),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttentionCard(StockItem item) {
    return GestureDetector(
      onTap: () => context.push('${AppRoutes.stock}/${item.id}'),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFDAD6),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFFBA1A1A).withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: Color(0xFFBA1A1A),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.warning, size: 16, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF410002),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Sisa stok: ${QuantityFormatter.format(item.currentStock)} ${item.unitLabel ?? "pcs"} • ${item.category}',
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11,
                      color: Color(0xFF410002),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Color(0xFF410002)),
          ],
        ),
      ),
    );
  }

  Widget _buildStockItemCard(StockItem item) {
    final isOutOfStock = item.currentStock == 0;
    final isLowStock = item.isLowStock;

    Color stockBadgeColor;
    Color stockTextColor;
    String stockStatusText;

    if (isOutOfStock) {
      stockBadgeColor = const Color(0xFFFFDAD6);
      stockTextColor = const Color(0xFFBA1A1A);
      stockStatusText = 'Stok Habis';
    } else if (isLowStock) {
      stockBadgeColor = const Color(0xFFFFE3CF);
      stockTextColor = const Color(0xFF9C4F1A);
      stockStatusText = 'Stok Menipis';
    } else {
      stockBadgeColor = const Color(0xFFDDEEE7);
      stockTextColor = const Color(0xFF0D5C56);
      stockStatusText = 'Stok Aman';
    }

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
        onTap: () => context.push('${AppRoutes.stock}/${item.id}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF191C1C),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${item.category} • ${item.unitLabel ?? "pcs"}',
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            color: Color(0xFF3F4947),
                          ),
                        ),
                        if ((item.sku ?? '').isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            'SKU: ${item.sku}',
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF3F4947),
                            ),
                          ),
                        ],
                        if (item.isDeadStock) ...[
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFDAD6),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: const Color(0xFFBA1A1A),
                              ),
                            ),
                            child: const Text(
                              'Stok Mati (>30 hari)',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFBA1A1A),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        CurrencyFormatter.format(item.sellingPrice),
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0D5C56),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: stockBadgeColor,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          stockStatusText,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: stockTextColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Divider(
                  height: 1,
                  thickness: 1,
                  color: Color(0xFFF2F4F2),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.inventory_2,
                        size: 16,
                        color: Color(0xFF0D5C56),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${QuantityFormatter.format(item.currentStock)} ${item.unitLabel ?? "pcs"}',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isOutOfStock
                              ? const Color(0xFFBA1A1A)
                              : const Color(0xFF191C1C),
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: const [
                      Text(
                        'Detail Stok',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0D5C56),
                        ),
                      ),
                      SizedBox(width: 4),
                      Icon(
                        Icons.arrow_forward_ios,
                        size: 10,
                        color: Color(0xFF0D5C56),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyStateCard({
    required IconData icon,
    required String title,
    required String subtitle,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return Container(
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
          Icon(icon, size: 40, color: const Color(0xFFBEC9C6)),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Color(0xFF191C1C),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              color: Color(0xFF3F4947),
              height: 1.4,
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 16),
            SizedBox(
              height: 38,
              child: FilledButton(
                onPressed: onAction,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF0D5C56),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  actionLabel,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
