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
      backgroundColor: const Color(0xFFF8FAF8),
      appBar: AppBar(
        toolbarHeight: 56,
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF0D5C56)),
          onPressed: () => context.go(AppRoutes.transaction),
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
              child: Text(
                'Bukti transaksi tidak ditemukan.',
                style: TextStyle(fontFamily: 'Inter', color: Color(0xFF3F4947)),
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
                        // Success Circle Banner
                        Column(
                          children: [
                            Container(
                              width: 80,
                              height: 80,
                              decoration: const BoxDecoration(
                                color: Color(0xFFABEFE7),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.check_circle,
                                size: 48,
                                color: Color(0xFF0D5C56),
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Pembayaran Berhasil',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF191C1C),
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Struk telah dibuat',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 14,
                                color: Color(0xFF3F4947),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 32),

                        // Transaction ID & General Info Card
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
                              _buildInfoRow('Nomor Faktur', '#${receipt.invoiceNumber}', isDashed: true),
                              const SizedBox(height: 12),
                              _buildInfoRow('Tanggal & Waktu', formattedDate, isDashed: true),
                              const SizedBox(height: 12),
                              _buildInfoRow(
                                'Metode Pembayaran',
                                _paymentMethodLabel(receipt.paymentMethod),
                                icon: _paymentMethodIcon(receipt.paymentMethod),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Items Summary Card
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
                              const Text(
                                'DETAIL BARANG',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF3F4947),
                                  letterSpacing: 0.8,
                                ),
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
                                            '${item.quantity}x ${CurrencyFormatter.format(item.unitPrice)}',
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
                              color: const Color(0xFF0D5C56).withValues(alpha: 0.3),
                              width: 2,
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
                              _buildFinancialRow('Jumlah Total', CurrencyFormatter.format(receipt.totalAmount)),
                              if (receipt.cashPaidAmount != null) ...[
                                const SizedBox(height: 8),
                                _buildFinancialRow('Jumlah Diterima', CurrencyFormatter.format(receipt.cashPaidAmount!)),
                              ],
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 12),
                                child: Divider(height: 1, thickness: 1, color: Color(0xFFBEC9C6)),
                              ),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Kembalian',
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF0D5C56),
                                    ),
                                  ),
                                  Text(
                                    CurrencyFormatter.format(receipt.changeAmount),
                                    style: const TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 26,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF0D5C56),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Utility Actions Row (Print / Share)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            GestureDetector(
                              onTap: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Mencetak struk...')),
                                );
                              },
                              child: Row(
                                children: const [
                                  Icon(Icons.print, size: 20, color: Color(0xFF0D5C56)),
                                  SizedBox(width: 6),
                                  Text(
                                    'Cetak Struk',
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF0D5C56),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 48),
                            GestureDetector(
                              onTap: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Membagikan struk...')),
                                );
                              },
                              child: Row(
                                children: const [
                                  Icon(Icons.share, size: 20, color: Color(0xFF0D5C56)),
                                  SizedBox(width: 6),
                                  Text(
                                    'Bagikan Struk',
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF0D5C56),
                                    ),
                                  ),
                                ],
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
                              onPressed: () => context.go(AppRoutes.home),
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
        error: (error, stackTrace) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.warning_amber_rounded, size: 48, color: Color(0xFFBA1A1A)),
                const SizedBox(height: 16),
                const Text(
                  'Gagal memuat bukti transaksi',
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

  Widget _buildInfoRow(String label, String value, {bool isDashed = false, IconData? icon}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 12,
            color: Color(0xFF3F4947),
          ),
        ),
        Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: const Color(0xFF0D5C56)),
              const SizedBox(width: 4),
            ],
            Text(
              value,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
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
            fontSize: 14,
            color: Color(0xFF191C1C),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 16,
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
        return paymentMethod.toUpperCase();
    }
  }

  IconData? _paymentMethodIcon(String paymentMethod) {
    switch (paymentMethod) {
      case 'tunai':
        return Icons.payments;
      case 'transfer':
        return Icons.account_balance;
      case 'qris':
        return Icons.qr_code;
      case 'ewallet':
        return Icons.account_balance_wallet;
      case 'kartu':
        return Icons.credit_card;
      default:
        return null;
    }
  }
}
