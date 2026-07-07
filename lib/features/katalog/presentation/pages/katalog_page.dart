import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_router.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../domain/entities/catalog_item.dart';
import '../controllers/katalog_controller.dart';
import '../models/katalog_state.dart';

class KatalogPage extends ConsumerStatefulWidget {
  const KatalogPage({super.key});

  @override
  ConsumerState<KatalogPage> createState() => _KatalogPageState();
}

class _KatalogPageState extends ConsumerState<KatalogPage> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final katalogAsync = ref.watch(katalogControllerProvider);

    return katalogAsync.when(
      data: (state) {
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Kelola barang dan jasa untuk transaksi harian.',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                        FilledButton.icon(
                          onPressed: () =>
                              context.push(AppRoutes.catalogCreate),
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('Tambah Item'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _searchController,
                      onChanged: ref
                          .read(katalogControllerProvider.notifier)
                          .updateSearch,
                      decoration: const InputDecoration(
                        hintText: 'Cari nama item, kategori, atau SKU',
                        prefixIcon: Icon(Icons.search_rounded),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _FilterChipButton(
                          label: 'Semua',
                          selected: state.typeFilter == 'semua',
                          onTap: () => ref
                              .read(katalogControllerProvider.notifier)
                              .updateTypeFilter('semua'),
                        ),
                        _FilterChipButton(
                          label: 'Barang',
                          selected: state.typeFilter == 'barang',
                          onTap: () => ref
                              .read(katalogControllerProvider.notifier)
                              .updateTypeFilter('barang'),
                        ),
                        _FilterChipButton(
                          label: 'Jasa',
                          selected: state.typeFilter == 'jasa',
                          onTap: () => ref
                              .read(katalogControllerProvider.notifier)
                              .updateTypeFilter('jasa'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _FilterChipButton(
                          label: 'Semua Status',
                          selected: state.statusFilter == 'semua',
                          onTap: () => ref
                              .read(katalogControllerProvider.notifier)
                              .updateStatusFilter('semua'),
                        ),
                        _FilterChipButton(
                          label: 'Aktif',
                          selected: state.statusFilter == 'aktif',
                          onTap: () => ref
                              .read(katalogControllerProvider.notifier)
                              .updateStatusFilter('aktif'),
                        ),
                        _FilterChipButton(
                          label: 'Nonaktif',
                          selected: state.statusFilter == 'nonaktif',
                          onTap: () => ref
                              .read(katalogControllerProvider.notifier)
                              .updateStatusFilter('nonaktif'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            _CatalogSummaryCard(state: state),
            const SizedBox(height: 16),
            if (state.allItems.isEmpty)
              _EmptyCatalogState(
                title: 'Katalog masih kosong',
                description:
                    'Tambahkan barang atau jasa pertama agar transaksi bisa dimulai dari modul katalog yang sama.',
                ctaLabel: 'Tambah Item Pertama',
                onPressed: () => context.push(AppRoutes.catalogCreate),
              )
            else if (state.filteredItems.isEmpty)
              const _EmptyCatalogState(
                title: 'Tidak ada item yang cocok',
                description:
                    'Ubah kata kunci pencarian atau filter untuk melihat item lain di katalog.',
              )
            else
              ...state.filteredItems.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _CatalogListCard(item: item),
                ),
              ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.warning_amber_rounded, size: 48),
                const SizedBox(height: 16),
                const Text(
                  'Gagal memuat katalog',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(error.toString(), textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => ref.invalidate(katalogControllerProvider),
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

class _FilterChipButton extends StatelessWidget {
  const _FilterChipButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
    );
  }
}

class _CatalogSummaryCard extends StatelessWidget {
  const _CatalogSummaryCard({required this.state});

  final KatalogState state;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Expanded(
              child: _SummaryMetric(
                label: 'Aktif',
                value: '${state.activeCount}',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _SummaryMetric(
                label: 'Barang',
                value: '${state.barangCount}',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _SummaryMetric(label: 'Jasa', value: '${state.jasaCount}'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 6),
        Text(
          value,
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

class _EmptyCatalogState extends StatelessWidget {
  const _EmptyCatalogState({
    required this.title,
    required this.description,
    this.ctaLabel,
    this.onPressed,
  });

  final String title;
  final String description;
  final String? ctaLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Icon(Icons.inventory_2_outlined, size: 42),
            const SizedBox(height: 14),
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(description, textAlign: TextAlign.center),
            if (ctaLabel != null && onPressed != null) ...[
              const SizedBox(height: 16),
              FilledButton(onPressed: onPressed, child: Text(ctaLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

class _CatalogListCard extends ConsumerWidget {
  const _CatalogListCard({required this.item});

  final CatalogItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
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
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: 'Aksi item',
                  onSelected: (value) async {
                    if (value == 'edit') {
                      context.push('${AppRoutes.catalog}/edit/${item.id}');
                      return;
                    }

                    await ref
                        .read(katalogControllerProvider.notifier)
                        .toggleItemStatus(item);
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem<String>(
                      value: 'edit',
                      child: Text('Edit item'),
                    ),
                    PopupMenuItem<String>(
                      value: 'toggle',
                      child: Text(
                        item.isActive ? 'Nonaktifkan item' : 'Aktifkan item',
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _Pill(
                  label: item.isBarang ? 'Barang' : 'Jasa',
                  backgroundColor: item.isBarang
                      ? const Color(0xFFECE5D8)
                      : const Color(0xFFDDEEE7),
                ),
                _Pill(
                  label: item.isActive ? 'Aktif' : 'Nonaktif',
                  backgroundColor: item.isActive
                      ? const Color(0xFFDDEEE7)
                      : const Color(0xFFF0E0D4),
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
            const SizedBox(height: 12),
            Text(
              item.isBarang
                  ? 'Stok ${item.stockQuantity ?? 0} ${item.unitLabel ?? 'Pcs'}'
                  : 'Satuan ${item.unitLabel ?? 'Layanan'}',
            ),
          ],
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
