import '../../domain/entities/transaksi_item.dart';
import '../../domain/entities/transaksi_receipt.dart';
import '../../domain/entities/transaksi_submit_request.dart';
import '../../domain/repositories/transaction_repository.dart';
import '../datasources/transaction_local_data_source.dart';

class TransactionRepositoryImpl implements TransactionRepository {
  TransactionRepositoryImpl({required this.localDataSource});

  final TransactionLocalDataSource localDataSource;

  @override
  Future<List<TransaksiItem>> getCatalogItems() async {
    final items = await localDataSource.getCatalogItems();
    return items.map((item) => item.toEntity()).toList();
  }

  @override
  Future<TransaksiReceipt?> getReceiptByInvoice(String invoiceNumber) {
    return localDataSource.getReceiptByInvoice(invoiceNumber);
  }

  @override
  Future<TransaksiReceipt> saveTransaction(TransaksiSubmitRequest request) {
    return localDataSource.saveTransaction(request);
  }
}
