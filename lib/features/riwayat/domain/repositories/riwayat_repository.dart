import '../entities/riwayat_transaksi_summary.dart';

abstract class RiwayatRepository {
  Future<List<RiwayatTransaksiSummary>> getTransactions();
  Future<void> voidTransaction(String invoiceNumber);
}
