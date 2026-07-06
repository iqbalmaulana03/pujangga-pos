import '../entities/transaksi_item.dart';
import '../entities/transaksi_receipt.dart';
import '../entities/transaksi_submit_request.dart';

abstract class TransactionRepository {
  Future<List<TransaksiItem>> getCatalogItems();
  Future<TransaksiReceipt> saveTransaction(TransaksiSubmitRequest request);
  Future<TransaksiReceipt?> getReceiptByInvoice(String invoiceNumber);
}
