import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pujangga_pos/features/transaksi/domain/entities/transaksi_item.dart';
import 'package:pujangga_pos/features/transaksi/presentation/controllers/transaksi_controller.dart';
import 'package:pujangga_pos/features/pengaturan/presentation/controllers/pengaturan_settings_controller.dart';
import 'package:pujangga_pos/features/pengaturan/domain/entities/app_settings.dart';
import 'package:pujangga_pos/features/transaksi/domain/repositories/transaction_repository.dart';
import 'package:pujangga_pos/features/transaksi/domain/entities/transaksi_receipt.dart';
import 'package:pujangga_pos/features/transaksi/domain/entities/transaksi_submit_request.dart';

class MockTransactionRepository implements TransactionRepository {
  @override
  Future<List<TransaksiItem>> getCatalogItems() async {
    return [];
  }
  
  @override
  Future<TransaksiReceipt> saveTransaction(TransaksiSubmitRequest request) async {
    throw UnimplementedError();
  }

  @override
  Future<TransaksiReceipt?> getReceiptByInvoice(String invoiceNumber) async {
    return null;
  }
}

void main() {
  const barang = TransaksiItem(
    id: 'barang-1',
    name: 'Kopi Literan',
    category: 'Minuman',
    itemType: 'barang',
    sellingPrice: 50000,
    stockQuantity: 12,
    unitLabel: 'Botol',
    isActive: true,
  );

  test('setQuantity memperbarui jumlah barang dalam keranjang dengan benar', () async {
    final container = ProviderContainer(
      overrides: [
        appSettingsProvider.overrideWith((ref) async => const AppSettings(
          currencyCode: 'IDR',
          currencySymbol: 'Rp',
          defaultTaxPercent: 0,
          stockAllowNegative: false,
        )),
        transactionRepositoryProvider.overrideWithValue(MockTransactionRepository()),
      ],
    );

    // Ambil controller
    final controller = container.read(transaksiControllerProvider.notifier);

    // Tunggu sampai controller siap (build selesai)
    await container.read(transaksiControllerProvider.future);

    // Tambah barang (kuantitas awal 1)
    controller.addItem(barang);
    
    var state = container.read(transaksiControllerProvider).value!;
    expect(state.cartItems.length, 1);
    expect(state.cartItems.first.quantity, 1);

    // Set kuantitas menjadi 10
    controller.setQuantity(barang.id, 10);
    state = container.read(transaksiControllerProvider).value!;
    expect(state.cartItems.first.quantity, 10);

    // Set kuantitas menjadi 0 harus menghapus item
    controller.setQuantity(barang.id, 0);
    state = container.read(transaksiControllerProvider).value!;
    expect(state.cartItems.isEmpty, isTrue);

    container.dispose();
  });
}
