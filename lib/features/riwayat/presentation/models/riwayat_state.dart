import '../../domain/entities/riwayat_transaksi_summary.dart';

class RiwayatState {
  const RiwayatState({
    this.allTransactions = const [],
    this.filteredTransactions = const [],
    this.searchQuery = '',
    this.paymentFilter = 'semua',
    this.dateFilter = 'semua',
  });

  final List<RiwayatTransaksiSummary> allTransactions;
  final List<RiwayatTransaksiSummary> filteredTransactions;
  final String searchQuery;
  final String paymentFilter;
  final String dateFilter;

  List<String> get paymentOptions {
    final values =
        allTransactions
            .map((transaction) => transaction.paymentMethod)
            .toSet()
            .toList()
          ..sort();
    return ['semua', ...values];
  }

  RiwayatState copyWith({
    List<RiwayatTransaksiSummary>? allTransactions,
    List<RiwayatTransaksiSummary>? filteredTransactions,
    String? searchQuery,
    String? paymentFilter,
    String? dateFilter,
  }) {
    return RiwayatState(
      allTransactions: allTransactions ?? this.allTransactions,
      filteredTransactions: filteredTransactions ?? this.filteredTransactions,
      searchQuery: searchQuery ?? this.searchQuery,
      paymentFilter: paymentFilter ?? this.paymentFilter,
      dateFilter: dateFilter ?? this.dateFilter,
    );
  }
}
