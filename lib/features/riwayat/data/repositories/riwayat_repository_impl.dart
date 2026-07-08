import '../../domain/entities/riwayat_transaksi_summary.dart';
import '../../domain/repositories/riwayat_repository.dart';
import '../datasources/riwayat_local_data_source.dart';

class RiwayatRepositoryImpl implements RiwayatRepository {
  RiwayatRepositoryImpl({required this.localDataSource});

  final RiwayatLocalDataSource localDataSource;

  @override
  Future<List<RiwayatTransaksiSummary>> getTransactions() async {
    final rows = await localDataSource.getTransactions();
    return rows.map((row) => row.toEntity()).toList();
  }
}
