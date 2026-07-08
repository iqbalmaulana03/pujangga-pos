import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/utils/currency_formatter.dart';
import '../../../transaksi/presentation/controllers/transaksi_controller.dart';

class DetailTransaksiPage extends ConsumerWidget {
  const DetailTransaksiPage({required this.transactionId, super.key});

  final String transactionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final receiptAsync = ref.watch(transaksiReceiptProvider(transactionId));

    return Scaffold(
      appBar: AppBar(title: const Text('Detail Transaksi')),
      body: receiptAsync.when(
        data: (receipt) {
          if (receipt == null) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Detail transaksi tidak ditemukan.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF7A4C2B), Color(0xFFA46C43)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      receipt.invoiceNumber,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      DateFormat(
                        'dd MMM yyyy, HH:mm',
                        'id_ID',
                      ).format(receipt.createdAt),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFFFDEADF),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _Pill(
                          label: _paymentMethodLabel(receipt.paymentMethod),
                          backgroundColor: Colors.white.withValues(alpha: 0.15),
                          foregroundColor: Colors.white,
                        ),
                        _Pill(
                          label: '${receipt.items.length} item',
                          backgroundColor: Colors.white.withValues(alpha: 0.15),
                          foregroundColor: Colors.white,
                        ),
                      ],
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
                      Text(
                        'Item Transaksi',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 16),
                      for (
                        var index = 0;
                        index < receipt.items.length;
                        index++
                      ) ...[
                        _ItemRow(
                          name: receipt.items[index].item.name,
                          quantity: receipt.items[index].quantity,
                          unitLabel: receipt.items[index].item.unitLabel,
                          lineTotal: receipt.items[index].lineTotal,
                        ),
                        if (index != receipt.items.length - 1)
                          const Divider(height: 24),
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
            ],
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
                    'Gagal memuat detail transaksi',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Text(error.toString(), textAlign: TextAlign.center),
                ],
              ),
            ),
          );
        },
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

class _ItemRow extends StatelessWidget {
  const _ItemRow({
    required this.name,
    required this.quantity,
    required this.unitLabel,
    required this.lineTotal,
  });

  final String name;
  final int quantity;
  final String? unitLabel;
  final double lineTotal;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text('$quantity ${unitLabel ?? 'item'}'),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Text(
          CurrencyFormatter.format(lineTotal),
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
      ],
    );
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

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  final String label;
  final Color backgroundColor;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.labelMedium?.copyWith(color: foregroundColor),
      ),
    );
  }
}
