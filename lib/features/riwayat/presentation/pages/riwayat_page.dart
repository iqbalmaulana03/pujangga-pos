import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../app/router/app_router.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../domain/entities/riwayat_transaksi_summary.dart';
import '../controllers/riwayat_controller.dart';
import '../models/riwayat_state.dart';

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
      appBar: AppBar(title: const Text('Riwayat Transaksi')),
      body: riwayatAsync.when(
        data: (state) {
          return RefreshIndicator(
            onRefresh: () =>
                ref.read(riwayatControllerProvider.notifier).refresh(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Cari transaksi berdasarkan invoice atau nama item.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _searchController,
                          onChanged: ref
                              .read(riwayatControllerProvider.notifier)
                              .updateSearch,
                          decoration: const InputDecoration(
                            hintText: 'Cari invoice atau item',
                            prefixIcon: Icon(Icons.search_rounded),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Filter Tanggal',
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _FilterChipButton(
                              label: 'Semua Tanggal',
                              selected: state.dateFilter == 'semua',
                              onTap: () => ref
                                  .read(riwayatControllerProvider.notifier)
                                  .updateDateFilter('semua'),
                            ),
                            _FilterChipButton(
                              label: 'Hari Ini',
                              selected: state.dateFilter == 'hari_ini',
                              onTap: () => ref
                                  .read(riwayatControllerProvider.notifier)
                                  .updateDateFilter('hari_ini'),
                            ),
                            _FilterChipButton(
                              label: '7 Hari',
                              selected: state.dateFilter == '7_hari',
                              onTap: () => ref
                                  .read(riwayatControllerProvider.notifier)
                                  .updateDateFilter('7_hari'),
                            ),
                            _FilterChipButton(
                              label: '30 Hari',
                              selected: state.dateFilter == '30_hari',
                              onTap: () => ref
                                  .read(riwayatControllerProvider.notifier)
                                  .updateDateFilter('30_hari'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Metode Pembayaran',
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final paymentMethod in state.paymentOptions)
                              _FilterChipButton(
                                label: _paymentLabel(paymentMethod),
                                selected: state.paymentFilter == paymentMethod,
                                onTap: () => ref
                                    .read(riwayatControllerProvider.notifier)
                                    .updatePaymentFilter(paymentMethod),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _RiwayatSummaryCard(state: state),
                const SizedBox(height: 16),
                if (state.allTransactions.isEmpty)
                  _EmptyRiwayatState(
                    isFiltered: false,
                    onCreateTransaction: () =>
                        context.push(AppRoutes.transaction),
                  )
                else if (state.filteredTransactions.isEmpty)
                  const _EmptyRiwayatState(isFiltered: true)
                else ...[
                  Text(
                    'Daftar Transaksi',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...state.filteredTransactions.map(
                    (transaction) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _RiwayatTransactionCard(transaction: transaction),
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
                    'Gagal memuat riwayat transaksi',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Text(error.toString(), textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => ref.invalidate(riwayatControllerProvider),
                    child: const Text('Muat Ulang'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
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

class _RiwayatSummaryCard extends StatelessWidget {
  const _RiwayatSummaryCard({required this.state});

  final RiwayatState state;

  @override
  Widget build(BuildContext context) {
    final filteredRevenue = state.filteredTransactions.fold<double>(
      0,
      (total, transaction) => total + transaction.totalAmount,
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Expanded(
              child: _SummaryMetric(
                label: 'Transaksi',
                value: '${state.filteredTransactions.length}',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _SummaryMetric(
                label: 'Omzet',
                value: CurrencyFormatter.format(filteredRevenue),
              ),
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
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
      ],
    );
  }
}

class _EmptyRiwayatState extends StatelessWidget {
  const _EmptyRiwayatState({
    required this.isFiltered,
    this.onCreateTransaction,
  });

  final bool isFiltered;
  final VoidCallback? onCreateTransaction;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Icon(Icons.receipt_long_outlined, size: 42),
            const SizedBox(height: 14),
            Text(
              isFiltered
                  ? 'Tidak ada transaksi yang cocok'
                  : 'Riwayat transaksi masih kosong',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              isFiltered
                  ? 'Ubah kata kunci pencarian atau filter untuk melihat transaksi lain.'
                  : 'Simpan transaksi pertama agar daftar riwayat dan detail invoice mulai terisi.',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(height: 1.4),
            ),
            if (!isFiltered && onCreateTransaction != null) ...[
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onCreateTransaction,
                icon: const Icon(Icons.point_of_sale_outlined),
                label: const Text('Buat Transaksi'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RiwayatTransactionCard extends StatelessWidget {
  const _RiwayatTransactionCard({required this.transaction});

  final RiwayatTransaksiSummary transaction;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () =>
            context.push('${AppRoutes.history}/${transaction.invoiceNumber}'),
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
                          transaction.invoiceNumber,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          DateFormat(
                            'dd MMM yyyy, HH:mm',
                            'id_ID',
                          ).format(transaction.createdAt),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    CurrencyFormatter.format(transaction.totalAmount),
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
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
                    label: _paymentLabel(transaction.paymentMethod),
                    backgroundColor: const Color(0xFFDDEEE7),
                  ),
                  _Pill(
                    label: '${transaction.itemCount} item',
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                transaction.itemSummary,
                style: Theme.of(context).textTheme.bodyMedium,
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
      return 'Kartu';
    case 'semua':
      return 'Semua Metode';
    default:
      return value;
  }
}
