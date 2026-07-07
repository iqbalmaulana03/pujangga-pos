import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_router.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../laporan/presentation/controllers/laporan_controller.dart';
import '../../domain/entities/transaksi_cart_item.dart';
import '../../domain/entities/transaksi_item.dart';
import '../controllers/transaksi_controller.dart';

class TransaksiPage extends ConsumerStatefulWidget {
  const TransaksiPage({super.key});

  @override
  ConsumerState<TransaksiPage> createState() => _TransaksiPageState();
}

class _TransaksiPageState extends ConsumerState<TransaksiPage> {
  final _searchController = TextEditingController();
  final _discountController = TextEditingController(text: '0');
  final _taxController = TextEditingController(text: '0');
  final _cashController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    _discountController.dispose();
    _taxController.dispose();
    _cashController.dispose();
    super.dispose();
  }

  Future<void> _submitTransaction() async {
    final controller = ref.read(transaksiControllerProvider.notifier);

    try {
      final receipt = await controller.submit();
      if (!mounted) {
        return;
      }

      _discountController.text = '0';
      _taxController.text = '0';
      _cashController.clear();
      _searchController.clear();
      ref.invalidate(dashboardSummaryProvider);
      ref.invalidate(salesReportSnapshotProvider);

      context.push('${AppRoutes.transactionSuccess}/${receipt.invoiceNumber}');
    } catch (error) {
      if (!mounted) {
        return;
      }

      final message = error is AppException
          ? error.message
          : 'Transaksi gagal disimpan. Coba lagi.';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _editItemDiscount(
    BuildContext context,
    TransaksiCartItem cartItem,
  ) async {
    final controller = TextEditingController(
      text: cartItem.itemDiscountAmount.toStringAsFixed(0),
    );

    final result = await showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            20 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Diskon ${cartItem.item.name}',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                'Maksimal ${CurrencyFormatter.format(cartItem.lineSubtotal)} untuk item ini.',
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Diskon item',
                  prefixText: 'Rp ',
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    Navigator.of(
                      context,
                    ).pop(double.tryParse(controller.text.trim()) ?? 0);
                  },
                  child: const Text('Terapkan Diskon'),
                ),
              ),
            ],
          ),
        );
      },
    );

    if (result != null) {
      ref
          .read(transaksiControllerProvider.notifier)
          .updateItemDiscount(cartItem.item.id, result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final transaksiAsync = ref.watch(transaksiControllerProvider);

    return transaksiAsync.when(
      data: (state) {
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF3F6B5A), Color(0xFF26463A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(28),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Transaksi Baru',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Pilih barang, jasa, atau transaksi campuran. Semua total dihitung otomatis dan penyimpanan berjalan local-first ke SQLite.',
                    style: TextStyle(color: Color(0xFFE0EFE8), height: 1.4),
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
                          .read(transaksiControllerProvider.notifier)
                          .updateSearch,
                      decoration: const InputDecoration(
                        hintText: 'Cari item atau kategori',
                        prefixIcon: Icon(Icons.search_rounded),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _FilterChipButton(
                          label: 'Semua',
                          selected: state.typeFilter == 'semua',
                          onTap: () => ref
                              .read(transaksiControllerProvider.notifier)
                              .updateFilter('semua'),
                        ),
                        _FilterChipButton(
                          label: 'Barang',
                          selected: state.typeFilter == 'barang',
                          onTap: () => ref
                              .read(transaksiControllerProvider.notifier)
                              .updateFilter('barang'),
                        ),
                        _FilterChipButton(
                          label: 'Jasa',
                          selected: state.typeFilter == 'jasa',
                          onTap: () => ref
                              .read(transaksiControllerProvider.notifier)
                              .updateFilter('jasa'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Katalog Aktif',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            if (state.filteredItems.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Text(
                    'Belum ada item aktif yang bisa dipilih untuk transaksi.',
                  ),
                ),
              )
            else
              ...state.filteredItems.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _CatalogItemCard(
                    item: item,
                    onAdd: () => ref
                        .read(transaksiControllerProvider.notifier)
                        .addItem(item),
                  ),
                ),
              ),
            const SizedBox(height: 20),
            Text(
              'Keranjang Transaksi',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            if (state.cartItems.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Text(
                    'Keranjang masih kosong. Tambahkan barang atau jasa dari katalog di atas.',
                  ),
                ),
              )
            else
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    children: [
                      for (final cartItem in state.cartItems) ...[
                        _CartItemCard(
                          cartItem: cartItem,
                          onDecrease: () => ref
                              .read(transaksiControllerProvider.notifier)
                              .decreaseQuantity(cartItem.item.id),
                          onIncrease: () => ref
                              .read(transaksiControllerProvider.notifier)
                              .increaseQuantity(cartItem.item.id),
                          onRemove: () => ref
                              .read(transaksiControllerProvider.notifier)
                              .removeItem(cartItem.item.id),
                          onEditDiscount: () =>
                              _editItemDiscount(context, cartItem),
                        ),
                        if (cartItem != state.cartItems.last)
                          const Divider(height: 28),
                      ],
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 20),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pembayaran dan Ringkasan',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _discountController,
                      keyboardType: TextInputType.number,
                      onChanged: (value) => ref
                          .read(transaksiControllerProvider.notifier)
                          .updateOrderDiscount(
                            double.tryParse(value.trim()) ?? 0,
                          ),
                      decoration: const InputDecoration(
                        labelText: 'Diskon total',
                        prefixText: 'Rp ',
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _taxController,
                      keyboardType: TextInputType.number,
                      onChanged: (value) => ref
                          .read(transaksiControllerProvider.notifier)
                          .updateTaxAmount(double.tryParse(value.trim()) ?? 0),
                      decoration: const InputDecoration(
                        labelText: 'Pajak',
                        prefixText: 'Rp ',
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Metode pembayaran',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final method in const {
                          'tunai': 'Tunai',
                          'transfer': 'Transfer',
                          'qris': 'QRIS',
                          'ewallet': 'E-Wallet',
                          'kartu': 'Kartu',
                        }.entries)
                          ChoiceChip(
                            label: Text(method.value),
                            selected: state.paymentMethod == method.key,
                            onSelected: (_) {
                              ref
                                  .read(transaksiControllerProvider.notifier)
                                  .updatePaymentMethod(method.key);
                              if (method.key != 'tunai') {
                                _cashController.clear();
                              }
                            },
                          ),
                      ],
                    ),
                    if (state.paymentMethod == 'tunai') ...[
                      const SizedBox(height: 16),
                      TextField(
                        controller: _cashController,
                        keyboardType: TextInputType.number,
                        onChanged: (value) => ref
                            .read(transaksiControllerProvider.notifier)
                            .updateCashPaid(double.tryParse(value.trim())),
                        decoration: const InputDecoration(
                          labelText: 'Nominal bayar',
                          prefixText: 'Rp ',
                        ),
                      ),
                    ],
                    const SizedBox(height: 18),
                    _SummaryRow(
                      label: 'Subtotal',
                      value: CurrencyFormatter.format(state.subtotalAmount),
                    ),
                    _SummaryRow(
                      label: 'Diskon item',
                      value: CurrencyFormatter.format(state.itemDiscountAmount),
                    ),
                    _SummaryRow(
                      label: 'Diskon total',
                      value: CurrencyFormatter.format(
                        state.orderDiscountAmount,
                      ),
                    ),
                    _SummaryRow(
                      label: 'Pajak',
                      value: CurrencyFormatter.format(state.taxAmount),
                    ),
                    const Divider(height: 24),
                    _SummaryRow(
                      label: 'Total transaksi',
                      value: CurrencyFormatter.format(state.totalAmount),
                      emphasize: true,
                    ),
                    if (state.paymentMethod == 'tunai')
                      _SummaryRow(
                        label: 'Kembalian',
                        value: CurrencyFormatter.format(
                          state.changeAmount < 0 ? 0 : state.changeAmount,
                        ),
                      ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: state.isSubmitting || !state.canSubmit
                            ? null
                            : _submitTransaction,
                        icon: const Icon(Icons.save_alt_rounded),
                        label: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Text(
                            state.isSubmitting
                                ? 'Menyimpan transaksi...'
                                : 'Simpan Transaksi',
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
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
                  'Gagal memuat modul transaksi',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(error.toString(), textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => ref.invalidate(transaksiControllerProvider),
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

class _CatalogItemCard extends StatelessWidget {
  const _CatalogItemCard({required this.item, required this.onAdd});

  final TransaksiItem item;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: item.isBarang
                    ? const Color(0xFFFFE3CF)
                    : const Color(0xFFDDEEE7),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                item.isBarang
                    ? Icons.inventory_2_outlined
                    : Icons.content_cut_rounded,
                color: item.isBarang
                    ? const Color(0xFF9C4F1A)
                    : const Color(0xFF3F6B5A),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.name,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          item.isBarang ? 'Barang' : 'Jasa',
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(item.category),
                  const SizedBox(height: 10),
                  Text(
                    CurrencyFormatter.format(item.sellingPrice),
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (item.isBarang && item.stockQuantity != null) ...[
                    const SizedBox(height: 4),
                    Text('Stok: ${item.stockQuantity} ${item.unitLabel ?? ''}'),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            FilledButton.tonalIcon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Tambah'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CartItemCard extends StatelessWidget {
  const _CartItemCard({
    required this.cartItem,
    required this.onDecrease,
    required this.onIncrease,
    required this.onRemove,
    required this.onEditDiscount,
  });

  final TransaksiCartItem cartItem;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;
  final VoidCallback onRemove;
  final VoidCallback onEditDiscount;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                cartItem.item.name,
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            IconButton(
              tooltip: 'Hapus item',
              onPressed: onRemove,
              icon: const Icon(Icons.delete_outline_rounded),
            ),
          ],
        ),
        Text(
          '${cartItem.item.category} • ${cartItem.item.isBarang ? 'Barang' : 'Jasa'}',
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            IconButton(
              onPressed: onDecrease,
              icon: const Icon(Icons.remove_circle_outline_rounded),
            ),
            Text(
              '${cartItem.quantity}',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            IconButton(
              onPressed: onIncrease,
              icon: const Icon(Icons.add_circle_outline_rounded),
            ),
            const Spacer(),
            Text(
              CurrencyFormatter.format(cartItem.lineSubtotal),
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            OutlinedButton.icon(
              onPressed: onEditDiscount,
              icon: const Icon(Icons.percent_rounded),
              label: Text(
                'Diskon ${CurrencyFormatter.format(cartItem.itemDiscountAmount)}',
              ),
            ),
            Text(
              'Total ${CurrencyFormatter.format(cartItem.lineTotal)}',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.emphasize = false,
  });

  final String label;
  final String value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final style = emphasize
        ? Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)
        : Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text(value, style: style),
        ],
      ),
    );
  }
}
