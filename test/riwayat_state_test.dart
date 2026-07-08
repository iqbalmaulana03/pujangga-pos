import 'package:flutter_test/flutter_test.dart';
import 'package:pujangga_pos/features/riwayat/domain/entities/riwayat_transaksi_summary.dart';
import 'package:pujangga_pos/features/riwayat/presentation/models/riwayat_state.dart';

void main() {
  final today = DateTime.now();

  final transactions = [
    RiwayatTransaksiSummary(
      invoiceNumber: 'INV-001',
      createdAt: today,
      totalAmount: 80000,
      paymentMethod: 'qris',
      itemCount: 2,
      itemNames: const ['Es Kopi Susu', 'Croissant'],
    ),
    RiwayatTransaksiSummary(
      invoiceNumber: 'INV-002',
      createdAt: today.subtract(const Duration(days: 3)),
      totalAmount: 45000,
      paymentMethod: 'tunai',
      itemCount: 1,
      itemNames: const ['Haircut Reguler'],
    ),
    RiwayatTransaksiSummary(
      invoiceNumber: 'INV-003',
      createdAt: today.subtract(const Duration(days: 40)),
      totalAmount: 120000,
      paymentMethod: 'transfer',
      itemCount: 3,
      itemNames: const ['Beras 5kg', 'Minyak', 'Gula'],
    ),
  ];

  test('menyusun opsi metode pembayaran dari data transaksi', () {
    final state = RiwayatState(
      allTransactions: transactions,
      filteredTransactions: transactions,
    );

    expect(state.paymentOptions, ['semua', 'qris', 'transfer', 'tunai']);
  });

  test('itemSummary merangkum item pertama dan sisa jumlah item', () {
    expect(transactions.first.itemSummary, 'Es Kopi Susu +1 item');
    expect(transactions[1].itemSummary, 'Haircut Reguler');
  });
}
