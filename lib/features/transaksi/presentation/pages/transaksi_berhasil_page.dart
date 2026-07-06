import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../app/router/app_router.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../controllers/transaksi_controller.dart';

class TransaksiBerhasilPage extends ConsumerWidget {
  const TransaksiBerhasilPage({required this.invoiceNumber, super.key});

  final String invoiceNumber;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final receiptAsync = ref.watch(transaksiReceiptProvider(invoiceNumber));

    return Scaffold(
      appBar: AppBar(title: const Text('Transaksi Berhasil')),
      body: receiptAsync.when(
        data: (receipt) {
          if (receipt == null) {
            return const Center(
              child: Text('Bukti transaksi tidak ditemukan.'),
            );
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF9C4F1A), Color(0xFFC56E33)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(28),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.check_circle_rounded,
                      color: Colors.white,
                      size: 42,
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Transaksi berhasil disimpan',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Ringkasan transaksi ini sudah tersimpan lokal dan stok barang terkait telah diperbarui.',
                      style: TextStyle(color: Color(0xFFFDEADF), height: 1.4),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _ReceiptRow(
                        label: 'Invoice',
                        value: receipt.invoiceNumber,
                      ),
                      _ReceiptRow(
                        label: 'Tanggal',
                        value: DateFormat(
                          'dd MMM yyyy, HH:mm',
                          'id_ID',
                        ).format(receipt.createdAt),
                      ),
                      _ReceiptRow(
                        label: 'Pembayaran',
                        value: _paymentMethodLabel(receipt.paymentMethod),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Item Transaksi',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 16),
                      for (final item in receipt.items) ...[
                        _ReceiptRow(
                          label: '${item.item.name} x${item.quantity}',
                          value: CurrencyFormatter.format(item.lineTotal),
                        ),
                        if (item != receipt.items.last)
                          const Divider(height: 20),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _ReceiptRow(
                        label: 'Subtotal',
                        value: CurrencyFormatter.format(receipt.subtotalAmount),
                      ),
                      _ReceiptRow(
                        label: 'Diskon item',
                        value: CurrencyFormatter.format(
                          receipt.itemDiscountAmount,
                        ),
                      ),
                      _ReceiptRow(
                        label: 'Diskon total',
                        value: CurrencyFormatter.format(
                          receipt.orderDiscountAmount,
                        ),
                      ),
                      _ReceiptRow(
                        label: 'Pajak',
                        value: CurrencyFormatter.format(receipt.taxAmount),
                      ),
                      if (receipt.cashPaidAmount != null)
                        _ReceiptRow(
                          label: 'Bayar tunai',
                          value: CurrencyFormatter.format(
                            receipt.cashPaidAmount!,
                          ),
                        ),
                      if (receipt.changeAmount > 0)
                        _ReceiptRow(
                          label: 'Kembalian',
                          value: CurrencyFormatter.format(receipt.changeAmount),
                        ),
                      const Divider(height: 24),
                      _ReceiptRow(
                        label: 'Total dibayar',
                        value: CurrencyFormatter.format(receipt.totalAmount),
                        emphasize: true,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => context.go(AppRoutes.transaction),
                  child: const Text('Transaksi Baru'),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => context.go(AppRoutes.home),
                  child: const Text('Selesai'),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.warning_amber_rounded, size: 48),
                const SizedBox(height: 16),
                const Text(
                  'Gagal memuat bukti transaksi',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(error.toString(), textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _paymentMethodLabel(String paymentMethod) {
    switch (paymentMethod) {
      case 'tunai':
        return 'Tunai';
      case 'transfer':
        return 'Transfer';
      case 'qris':
        return 'QRIS';
      case 'ewallet':
        return 'E-Wallet';
      case 'kartu':
        return 'Kartu';
      default:
        return paymentMethod;
    }
  }
}

class _ReceiptRow extends StatelessWidget {
  const _ReceiptRow({
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(label, style: style)),
          const SizedBox(width: 16),
          Flexible(
            child: Text(value, textAlign: TextAlign.right, style: style),
          ),
        ],
      ),
    );
  }
}
