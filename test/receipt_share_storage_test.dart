import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:path/path.dart' as path;
import 'package:pujangga_pos/core/database/app_database.dart';
import 'package:pujangga_pos/core/services/app_startup_service.dart';
import 'package:pujangga_pos/features/transaksi/data/datasources/transaction_local_data_source.dart';
import 'package:pujangga_pos/features/transaksi/domain/entities/transaksi_cart_item.dart';
import 'package:pujangga_pos/features/transaksi/domain/entities/transaksi_item.dart';
import 'package:pujangga_pos/features/transaksi/domain/entities/transaksi_submit_request.dart';
import 'package:pujangga_pos/features/transaksi/presentation/controllers/receipt_share_controller.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    await initializeDateFormatting('id_ID');
  });

  test('shares persisted snapshots after catalog edit; cancellation/failure leave all tables unchanged', () async {
    final temporary = await Directory.systemTemp.createTemp(
      'receipt_share_55_',
    );
    await databaseFactory.setDatabasesPath(temporary.path);
    final database = AppDatabase();
    // Prove effective path before opening or writing any database.
    expect(path.dirname(await database.databasePath()), temporary.path);
    addTearDown(() async {
      await database.reset();
      await temporary.delete(recursive: true);
    });
    final db = await database.database();
    final now = DateTime.now().toIso8601String();
    final id = await db.insert('items', {
      'name': 'Kopi Tersimpan',
      'item_type': 'product',
      'sale_price': 10000,
      'harga_modal': 7777,
      'stock_qty': 10,
      'created_at': now,
      'updated_at': now,
    });
    final receipt = await TransactionLocalDataSource(database: database)
        .saveTransaction(
          TransaksiSubmitRequest(
            items: [
              TransaksiCartItem(
                item: TransaksiItem(
                  id: '$id',
                  name: 'Kopi Tersimpan',
                  category: '',
                  itemType: 'barang',
                  sellingPrice: 10000,
                  isActive: true,
                ),
                quantity: 2,
                itemDiscountAmount: 1000,
              ),
            ],
            orderDiscountAmount: 2000,
            taxAmount: 500,
            paymentMethod: 'tunai',
            cashPaidAmount: 20000,
          ),
        );
    await db.update(
      'items',
      {'name': 'Nama Baru', 'sale_price': 99999},
      where: 'id = ?',
      whereArgs: [id],
    );
    final tables = (await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite_%' ORDER BY name",
    )).map((row) => row['name']! as String).toList();
    Future<List<Object>> snapshot() async => [
      for (final table in tables) await db.query(table),
    ];
    final before = await snapshot();
    for (final fail in [false, true]) {
      final payloads = <ShareParams>[];
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          businessProfileProvider.overrideWith((ref) async => null),
          receiptShareLauncherProvider.overrideWithValue((params) async {
            payloads.add(params);
            if (fail) throw StateError('Injected share failure');
            return const ShareResult('', ShareResultStatus.dismissed);
          }),
        ],
      );
      try {
        final sharing = container
            .read(receiptShareControllerProvider.notifier)
            .share(receipt.invoiceNumber);
        if (fail) {
          await expectLater(sharing, throwsStateError);
        } else {
          await sharing;
        }
        final text = payloads.single.text!;
        expect(text, contains(receipt.invoiceNumber));
        expect(text, contains('Kopi Tersimpan'));
        expect(text, contains('2 x Rp10.000'));
        expect(text, contains('Total: Rp17.500'));
        expect(text, contains('Kembalian: Rp2.500'));
        expect(text, isNot(contains('Nama Baru')));
        expect(text, isNot(contains('7777')));
        expect(await snapshot(), before);
      } finally {
        container.dispose();
      }
    }
  });
}
