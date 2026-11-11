import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:pujangga_pos/core/database/app_database.dart';
import 'package:pujangga_pos/core/services/app_startup_service.dart';
import 'package:pujangga_pos/core/utils/app_date_formatting.dart';
import 'package:pujangga_pos/features/transaksi/data/datasources/transaction_local_data_source.dart';
import 'package:pujangga_pos/features/transaksi/domain/entities/transaksi_cart_item.dart';
import 'package:pujangga_pos/features/transaksi/domain/entities/transaksi_item.dart';
import 'package:pujangga_pos/features/transaksi/domain/entities/transaksi_submit_request.dart';
import 'package:pujangga_pos/features/transaksi/presentation/controllers/receipt_share_controller.dart';
import 'package:pujangga_pos/features/transaksi/presentation/pages/transaksi_berhasil_page.dart';

class _DisposableDatabase extends AppDatabase {
  _DisposableDatabase(this.filePath);
  final String filePath;
  @override
  Future<String> databasePath() async => filePath;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'saved receipt opens native Android Sharesheet; cancel preserves database',
    (tester) async {
      initializeAppDateFormatting();
      final temporary = await getTemporaryDirectory();
      expect(
        temporary.path,
        contains('/com.pujanggapos.pujangga_pos.issue55e2e/'),
      );
      final directory = await Directory(
        path.join(
          temporary.path,
          'receipt-${DateTime.now().microsecondsSinceEpoch}',
        ),
      ).create();
      final database = _DisposableDatabase(
        path.join(directory.path, 'isolated.db'),
      );
      expect(
        path.isWithin(directory.path, await database.databasePath()),
        isTrue,
      );
      final db = await database.database();
      final now = DateTime.now().toIso8601String();
      await db.insert('business_profile', {
        'business_name': 'Toko Uji Struk 55',
        'business_type': 'retail',
        'created_at': now,
        'updated_at': now,
      });
      final id = await db.insert('items', {
        'name': 'Kopi Uji',
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
                    name: 'Kopi Uji',
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
      final tables = (await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite_%' ORDER BY name",
      )).map((row) => row['name']! as String).toList();
      Future<List<Object>> snapshot() async => [
        for (final table in tables) await db.query(table),
      ];
      final before = await snapshot();
      final container = ProviderContainer(
        overrides: [appDatabaseProvider.overrideWithValue(database)],
      );
      addTearDown(() async {
        container.dispose();
        await database.reset();
        await directory.delete(recursive: true);
      });
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: TransaksiBerhasilPage(invoiceNumber: receipt.invoiceNumber),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('#${receipt.invoiceNumber}'), findsOneWidget);
      await tester.ensureVisible(find.text('Bagikan Struk'));
      await tester.tap(find.text('Bagikan Struk'));
      await tester.pump();
      // The host runner verifies the native chooser, then dismisses it with Back.
      debugPrint('E2E_SHARE_OPEN');
      await tester.runAsync(() async {
        for (var attempt = 0; attempt < 60; attempt++) {
          await Future<void>.delayed(const Duration(seconds: 1));
          if (!container.read(receiptShareControllerProvider)) return;
        }
        fail('Native sharesheet was not dismissed by host runner');
      });
      await tester.pumpAndSettle();
      expect(container.read(receiptShareControllerProvider), isFalse);
      expect(await snapshot(), before);
      expect(find.text('Pembayaran Berhasil'), findsOneWidget);
      debugPrint('E2E_SHARE_CANCEL_PRESERVED_ALL_TABLES');
    },
  );
}
