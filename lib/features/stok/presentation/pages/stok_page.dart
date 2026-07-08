import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_router.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../domain/entities/stock_item.dart';
import '../controllers/stok_controller.dart';
import '../models/stok_state.dart';

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

    return stokAsync.when(
      data: (state) {
        return RefreshIndicator(
          onRefresh: () => ref.read(stokControllerProvider.notifier).refresh(),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
            children: [
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF76512D), Color(0xFF9C6B3F)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PANTAU STOK BARANG',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: const Color(0xFFFFF2E6),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Cek stok aktif, temukan item menipis, dan buka detail penyesuaian manual dari satu alur.',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: _HeroMetric(
                            label: 'Barang',
                            value: '${state.totalItems}',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _HeroMetric(
                            label: 'Menipis',
                            value: '${state.lowStockCount}',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _HeroMetric(
                            label: 'Unit',
                            value: '${state.totalUnits}',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: _searchController,
                        onChanged: ref
                            .read(stokControllerProvider.notifier)
                            .updateSearch,
                        decoration: const InputDecoration(
                          hintText: 'Cari nama barang, kategori, atau SKU',
                          prefixIcon: Icon(Icons.search_rounded),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final category in state.categories)
                            ChoiceChip(
                              label: Text(
                                category == 'semua'
                                    ? 'Semua Kategori'
                                    : category,
                              ),
                              selected: state.categoryFilter == category,
                              onSelected: (_) {
                                ref
                                    .read(stokControllerProvider.notifier)
                                    .updateCategoryFilter(category);
                              },
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (state.lowStockItems.isNotEmpty) ...[
                Text(
                  'Perlu Perhatian',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                ...state.lowStockItems
                    .take(3)
                    .map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _LowStockAlertCard(item: item),
                      ),
                    ),
                const SizedBox(height: 8),
              ],
              if (state.allItems.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        const Icon(Icons.inventory_2_outlined, size: 42),
                        const SizedBox(height: 14),
                        Text(
                          'Belum ada barang di katalog',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Tambahkan item bertipe barang dari katalog agar modul stok mulai menampilkan ringkasan dan histori pergerakan.',
                          textAlign: TextAlign.center,
                          style: Theme.of(
                            context,
                          ).textTheme.bodyMedium?.copyWith(height: 1.4),
                        ),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: () =>
                              context.push(AppRoutes.catalogCreate),
                          child: const Text('Tambah Item'),
                        ),
                      ],
                    ),
                  ),
                )
              else if (state.filteredItems.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        const Icon(Icons.filter_alt_off_outlined, size: 42),
                        const SizedBox(height: 14),
                        Text(
                          'Tidak ada barang yang cocok',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Ubah kata kunci pencarian atau filter kategori untuk melihat item lain.',
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              else ...[
                Text(
                  'Daftar Barang',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                ...state.filteredItems.map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _StockItemCard(item: item),
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
                  'Gagal memuat stok',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(error.toString(), textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => ref.invalidate(stokControllerProvider),
                  child: const Text('Muat Ulang'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _HeroMetric extends StatelessWidget {
  const _HeroMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(color: const Color(0xFFFFF2E6)),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _LowStockAlertCard extends StatelessWidget {
  const _LowStockAlertCard({required this.item});

  final StockItem item;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push('${AppRoutes.stock}/${item.id}'),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFE6D5),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  color: Color(0xFF9C4F1A),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${item.currentStock} ${item.unitLabel ?? 'pcs'} tersisa • ${item.category}',
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

class _StockItemCard extends StatelessWidget {
  const _StockItemCard({required this.item});

  final StockItem item;

  @override
  Widget build(BuildContext context) {
    final stockColor = item.isLowStock
        ? const Color(0xFF9C4F1A)
        : const Color(0xFF11564F);

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push('${AppRoutes.stock}/${item.id}'),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
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
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        Text(item.category),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    CurrencyFormatter.format(item.sellingPrice),
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _Pill(
                    label: item.isActive ? 'Aktif' : 'Nonaktif',
                    backgroundColor: item.isActive
                        ? const Color(0xFFDDEEE7)
                        : const Color(0xFFF0E0D4),
                  ),
                  _Pill(
                    label: item.isLowStock ? 'Stok menipis' : 'Stok aman',
                    backgroundColor: item.isLowStock
                        ? const Color(0xFFFFE3CF)
                        : const Color(0xFFE5F2EC),
                  ),
                  if ((item.sku ?? '').isNotEmpty)
                    _Pill(
                      label: 'SKU ${item.sku}',
                      backgroundColor: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                    ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: stockColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${item.currentStock} ${item.unitLabel ?? 'pcs'}',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: stockColor,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Lihat detail',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
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
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.backgroundColor});

  final String label;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label, style: Theme.of(context).textTheme.labelMedium),
    );
  }
}
