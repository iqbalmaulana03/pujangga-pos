import '../../domain/entities/riwayat_transaksi_summary.dart';

class RiwayatTransaksiSummaryDbModel {
  const RiwayatTransaksiSummaryDbModel({
    required this.invoiceNumber,
    required this.createdAt,
    required this.totalAmount,
    required this.paymentMethod,
    required this.itemCount,
    required this.itemNames,
    this.status = 'completed',
  });

  final String invoiceNumber;
  final DateTime createdAt;
  final double totalAmount;
  final String paymentMethod;
  final int itemCount;
  final List<String> itemNames;
  final String status;

  factory RiwayatTransaksiSummaryDbModel.fromMap(Map<String, Object?> map) {
    final rawNames = (map['item_names'] as String? ?? '').trim();
    return RiwayatTransaksiSummaryDbModel(
      invoiceNumber: map['invoice_no'] as String,
      createdAt: DateTime.parse(map['transaction_date'] as String),
      totalAmount: (map['total_amount'] as num).toDouble(),
      paymentMethod: map['payment_method'] as String,
      itemCount: (map['item_count'] as num?)?.toInt() ?? 0,
      itemNames: rawNames.isEmpty
          ? const []
          : rawNames.split('|||').map((name) => name.trim()).toList(),
      status: map['status'] as String? ?? 'completed',
    );
  }

  RiwayatTransaksiSummary toEntity() {
    return RiwayatTransaksiSummary(
      invoiceNumber: invoiceNumber,
      createdAt: createdAt,
      totalAmount: totalAmount,
      paymentMethod: paymentMethod,
      itemCount: itemCount,
      itemNames: itemNames,
      status: status,
    );
  }
}
