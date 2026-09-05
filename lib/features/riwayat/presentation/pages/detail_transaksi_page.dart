import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../app/router/app_router.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../transaksi/presentation/controllers/transaksi_controller.dart';
import '../controllers/riwayat_controller.dart';

class DetailTransaksiPage extends ConsumerWidget {
  const DetailTransaksiPage({required this.transactionId, super.key});

  final String transactionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final receiptAsync = ref.watch(transaksiReceiptProvider(transactionId));

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
          'Detail Transaksi',
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
      body: receiptAsync.when(
        data: (receipt) {
          if (receipt == null) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Detail transaksi tidak ditemukan.',
                  style: TextStyle(fontFamily: 'Inter', color: Color(0xFF3F4947)),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final formattedDate = DateFormat('dd MMM yyyy, HH:mm', 'id_ID').format(receipt.createdAt);

          return Stack(
            children: [
              SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 150),
                child: Center(
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 500),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (receipt.status == 'voided')
                          Column(
                            children: [
                              Container(
                                width: 64,
                                height: 64,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFFFDAD6),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.cancel,
                                  size: 40,
                                  color: Color(0xFFBA1A1A),
                                ),
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'Transaksi Dibatalkan',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFBA1A1A),
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Data telah divoid dan stok dikembalikan',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 13,
                                  color: Color(0xFF3F4947),
                                ),
                              ),
                            ],
                          )
                        else
                          // Status Card Success Check
                          Column(
                            children: [
                              Container(
                                width: 64,
                                height: 64,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFABEFE7),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.check_circle,
                                  size: 40,
                                  color: Color(0xFF0D5C56),
                                ),
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'Pembayaran Berhasil',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF191C1C),
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Transaksi telah selesai',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 13,
                                  color: Color(0xFF3F4947),
                                ),
                              ),
                            ],
                          ),
                        const SizedBox(height: 24),

                        // Transaction Info Card
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
                            children: [
                              _buildInfoRow('No. Invoice', '#${receipt.invoiceNumber}'),
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 12),
                                child: Divider(height: 1, thickness: 1, color: Color(0xFFF2F4F2)),
                              ),
                              _buildInfoRow('Tanggal & Waktu', formattedDate),
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 12),
                                child: Divider(height: 1, thickness: 1, color: Color(0xFFF2F4F2)),
                              ),
                              _buildInfoRow(
                                'Metode Pembayaran',
                                _paymentMethodLabel(receipt.paymentMethod),
                                icon: _paymentMethodIcon(receipt.paymentMethod),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Item Details Card
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
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: const [
                                  Icon(Icons.shopping_basket, size: 18, color: Color(0xFF3F4947)),
                                  SizedBox(width: 8),
                                  Text(
                                    'DETAIL BARANG',
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
                              const SizedBox(height: 16),
                              for (final item in receipt.items) ...[
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item.item.name,
                                            style: const TextStyle(
                                              fontFamily: 'Inter',
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF191C1C),
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '${item.quantity}x ${CurrencyFormatter.format(item.item.sellingPrice)}',
                                            style: const TextStyle(
                                              fontFamily: 'Inter',
                                              fontSize: 12,
                                              color: Color(0xFF3F4947),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      CurrencyFormatter.format(item.lineTotal),
                                      style: const TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF191C1C),
                                      ),
                                    ),
                                  ],
                                ),
                                if (item != receipt.items.last)
                                  const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 12),
                                    child: Divider(height: 1, thickness: 1, color: Color(0xFFF2F4F2)),
                                  ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Financial Summary Card
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
                            children: [
                              _buildFinancialRow('Subtotal', CurrencyFormatter.format(receipt.subtotalAmount)),
                              if (receipt.itemDiscountAmount > 0) ...[
                                const SizedBox(height: 8),
                                _buildFinancialRow('Diskon Item', '-${CurrencyFormatter.format(receipt.itemDiscountAmount)}'),
                              ],
                              if (receipt.orderDiscountAmount > 0) ...[
                                const SizedBox(height: 8),
                                _buildFinancialRow('Diskon Tambahan', '-${CurrencyFormatter.format(receipt.orderDiscountAmount)}'),
                              ],
                              const SizedBox(height: 8),
                              _buildFinancialRow(
                                'Pajak (${(receipt.subtotalAmount - receipt.itemDiscountAmount) > 0 ? (receipt.taxAmount / (receipt.subtotalAmount - receipt.itemDiscountAmount) * 100).round() : 0}%)',
                                CurrencyFormatter.format(receipt.taxAmount),
                              ),
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 12),
                                child: Divider(height: 1, thickness: 1, color: Color(0xFFF2F4F2)),
                              ),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Jumlah Total',
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF191C1C),
                                    ),
                                  ),
                                  Text(
                                    CurrencyFormatter.format(receipt.totalAmount),
                                    style: const TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF0D5C56),
                                    ),
                                  ),
                                ],
                              ),
                              if (receipt.cashPaidAmount != null) ...[
                                const SizedBox(height: 8),
                                _buildFinancialRow('Jumlah Diterima', CurrencyFormatter.format(receipt.cashPaidAmount!)),
                              ],
                              if (receipt.changeAmount > 0) ...[
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0D5C56).withValues(alpha: 0.05),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text(
                                        'Kembalian',
                                        style: TextStyle(
                                          fontFamily: 'Inter',
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF0D5C56),
                                        ),
                                      ),
                                      Text(
                                        CurrencyFormatter.format(receipt.changeAmount),
                                        style: const TextStyle(
                                          fontFamily: 'Inter',
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF0D5C56),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Action Buttons Cetak/Bagikan
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Mencetak struk...')),
                                  );
                                },
                                icon: const Icon(Icons.print, size: 18),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF0D5C56),
                                  side: const BorderSide(color: Color(0xFF0D5C56)),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                label: const Text('Cetak Struk', style: TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.bold)),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Membagikan struk...')),
                                  );
                                },
                                icon: const Icon(Icons.share, size: 18),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF0D5C56),
                                  side: const BorderSide(color: Color(0xFF0D5C56)),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                label: const Text('Bagikan Struk', style: TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Sticky Bottom Actions
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border(
                      top: BorderSide(
                        color: const Color(0xFFBEC9C6).withValues(alpha: 0.5),
                        width: 1,
                      ),
                    ),
                  ),
                  child: Center(
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 500),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (receipt.status == 'completed') ...[
                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: OutlinedButton(
                                onPressed: () {
                                  showDialog(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: const Text('Batalkan Transaksi?'),
                                      content: const Text(
                                        'Transaksi ini akan dibatalkan (void). Data penjualan akan ditarik dari laporan dan stok barang akan dikembalikan otomatis. Tindakan ini tidak dapat diurungkan.',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(ctx),
                                          child: const Text('Tutup'),
                                        ),
                                        FilledButton(
                                          onPressed: () {
                                            Navigator.pop(ctx);
                                            ref.read(riwayatControllerProvider.notifier).voidTransaction(receipt.invoiceNumber).then((_) {
                                              if (!context.mounted) return;
                                              ref.invalidate(transaksiReceiptProvider(transactionId));
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(content: Text('Transaksi berhasil dibatalkan.')),
                                              );
                                            });
                                          },
                                          style: FilledButton.styleFrom(
                                            backgroundColor: const Color(0xFFBA1A1A),
                                            foregroundColor: Colors.white,
                                          ),
                                          child: const Text('Ya, Batalkan'),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: Color(0xFFBA1A1A)),
                                  foregroundColor: const Color(0xFFBA1A1A),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: const Text(
                                  'Batalkan Transaksi (Void)',
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                          ],
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: FilledButton(
                              onPressed: () => context.go(AppRoutes.transaction),
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF0D5C56),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                'Transaksi Baru',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: OutlinedButton(
                              onPressed: () => context.pop(),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Color(0xFFBEC9C6)),
                                foregroundColor: const Color(0xFF191C1C),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                'Selesai',
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
                    ),
                  ),
                ),
              ),
            ],
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
                  'Gagal memuat detail transaksi',
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
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {IconData? icon}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 13,
            color: Color(0xFF3F4947),
          ),
        ),
        Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: const Color(0xFF0D5C56)),
              const SizedBox(width: 6),
            ],
            Text(
              value,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Color(0xFF191C1C),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFinancialRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 13,
            color: Color(0xFF3F4947),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: Color(0xFF191C1C),
          ),
        ),
      ],
    );
  }

  String _paymentMethodLabel(String paymentMethod) {
    switch (paymentMethod) {
      case 'tunai':
      case 'cash':
        return 'Tunai';
      case 'transfer':
        return 'Transfer Bank';
      case 'qris':
        return 'QRIS';
      case 'ewallet':
        return 'E-Wallet';
      case 'card':
      case 'kartu':
        return 'Kartu Debit/Kredit';
      default:
        return paymentMethod.toUpperCase();
    }
  }

  IconData? _paymentMethodIcon(String paymentMethod) {
    switch (paymentMethod) {
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
        return null;
    }
  }
}
