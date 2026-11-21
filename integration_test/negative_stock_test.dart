import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pujangga_pos/app/app.dart';
import 'package:pujangga_pos/app/router/app_router.dart';
import 'package:pujangga_pos/core/database/app_database.dart';
import 'package:pujangga_pos/core/services/app_startup_service.dart';
import 'package:pujangga_pos/core/utils/app_date_formatting.dart';
import 'package:pujangga_pos/features/pengaturan/data/services/app_backup_service.dart';
import 'package:pujangga_pos/features/pengaturan/data/services/app_restore_service.dart';
import 'package:pujangga_pos/features/transaksi/presentation/pages/transaksi_berhasil_page.dart';
import 'package:sqflite/sqflite.dart';

const _package = 'com.pujanggapos.pujangga_pos.pr74e2e';

class _TestDatabase extends AppDatabase {
  _TestDatabase(this.file);

  final String file;

  @override
  Future<String> databasePath() async => file;
}

Future<Map<String, List<Map<String, Object?>>>> _snapshot(
  Database database,
) async => {
  for (final table in AppBackupService.backupTables)
    table: await database.query(table, orderBy: 'id'),
};

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Android checkout, adjustment, void and restore honor negative stock',
    (tester) async {
      initializeAppDateFormatting();
      final cache = await getTemporaryDirectory();
      expect(cache.path, contains('/$_package/'));
      final root = await cache.createTemp('negative-stock-');
      final source = _TestDatabase(p.join(root.path, 'source.sqlite'));
      final destination = _TestDatabase(p.join(root.path, 'restored.sqlite'));
      final container = ProviderContainer(
        overrides: [appDatabaseProvider.overrideWithValue(source)],
      );
      addTearDown(() async {
        container.dispose();
        await source.reset();
        await destination.reset();
        await root.delete(recursive: true);
      });

      for (final database in [source, destination]) {
        final expected = await database.databasePath();
        expect(p.isWithin(root.path, expected), isTrue);
        final connection = await database.database();
        final effective = (await connection.rawQuery('PRAGMA database_list'))
            .singleWhere((row) => row['name'] == 'main');
        expect(effective['file'], expected);
      }
      expect(
        await source.databasePath(),
        isNot(await destination.databasePath()),
      );
      final db = await source.database();
      final now = DateTime.now().toIso8601String();
      await db.insert('business_profile', {
        'business_name': 'Toko Uji Stok Minus',
        'business_type': 'retail',
        'created_at': now,
        'updated_at': now,
      });
      Future<int> seed(String name, String unit) => db.insert('items', {
        'name': name,
        'item_type': 'product',
        'sale_price': 1000,
        'stock_qty': 0,
        'unit': unit,
        'created_at': now,
        'updated_at': now,
      });

      const saleName = 'Barang Uji Penjualan';
      const adjustmentName = 'Barang Uji Penyesuaian';
      final saleItem = await seed(saleName, 'pcs');
      final adjustItem = await seed(adjustmentName, 'kg');
      Future<num> balance(int id) async =>
          (await db.query(
                'items',
                where: 'id = ?',
                whereArgs: [id],
              )).single['stock_qty']
              as num;
      Future<List<Map<String, Object?>>> movements(int id) => db.query(
        'stock_movements',
        where: 'item_id = ?',
        whereArgs: [id],
        orderBy: 'id',
      );

      Future<void> tap(Finder finder) async {
        tester
            .state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger).first)
            .clearSnackBars();
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pumpAndSettle();
        expect(finder, findsOneWidget);
        await tester.ensureVisible(finder);
        await tester.tap(finder);
        await tester.pumpAndSettle();
      }

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const PujanggaPosApp(),
        ),
      );
      await tester.pumpAndSettle();
      tester.testTextInput.register();
      final router =
          tester.widget<MaterialApp>(find.byType(MaterialApp)).routerConfig!
              as GoRouter;
      Future<void> go(String location) async {
        router.go(location);
        await tester.pumpAndSettle();
      }

      Future<void> toggle(bool enabled) async {
        await go(AppRoutes.settings);
        final label = find.text('Izinkan Stok Minus');
        final row = find.ancestor(of: label, matching: find.byType(Row)).first;
        final control = find.descendant(of: row, matching: find.byType(Switch));
        expect(tester.widget<Switch>(control).value, !enabled);
        await tap(control);
        expect(
          (await db.query('app_settings')).single['stock_allow_negative'],
          enabled ? 1 : 0,
        );
      }

      final cash = find.byWidgetPredicate(
        (widget) => widget is TextField && widget.textAlign == TextAlign.right,
      );
      Future<void> checkout({required bool allowed}) async {
        await tap(find.text(saleName).first);
        await tap(find.text('Keranjang'));
        await tester.ensureVisible(cash);
        await tester.enterText(cash, '1000');
        await tap(find.widgetWithText(FilledButton, 'Proses Pembayaran'));
        if (allowed) {
          expect(find.byType(TransaksiBerhasilPage), findsOneWidget);
          await tap(find.widgetWithText(FilledButton, 'Transaksi Baru'));
        } else {
          expect(
            find.textContaining('tidak cukup untuk transaksi ini'),
            findsOneWidget,
          );
          final cart = find.text('Keranjang Transaksi');
          if (cart.evaluate().isNotEmpty) {
            Navigator.of(tester.element(cart)).pop();
            await tester.pumpAndSettle();
          }
        }
      }

      Future<void> adjust(
        String type,
        String quantity, {
        required bool allowed,
      }) async {
        await tap(find.widgetWithText(FilledButton, 'Sesuaikan Stok'));
        await tap(find.byType(DropdownButtonFormField<String>));
        await tap(find.text(type).last);
        final field = find.widgetWithText(
          TextFormField,
          type == 'Set stok akhir' ? 'Stok akhir' : 'Jumlah penyesuaian',
        );
        expect(
          tester
              .widget<TextField>(
                find.descendant(of: field, matching: find.byType(TextField)),
              )
              .keyboardType
              .signed,
          type == 'Set stok akhir',
        );
        await tester.enterText(field, quantity);
        await tap(find.widgetWithText(FilledButton, 'Simpan Penyesuaian'));
        if (allowed) {
          final sheet = find.text('Jenis penyesuaian');
          final feedback = find.descendant(
            of: find.byType(SnackBar),
            matching: find.byType(Text),
          );
          final messages = <String>{};
          for (
            var attempt = 0;
            attempt < 20 && sheet.evaluate().isNotEmpty;
            attempt++
          ) {
            messages.addAll(
              tester.widgetList<Text>(feedback).map((text) => text.data ?? ''),
            );
            await tester.pump(const Duration(milliseconds: 250));
          }
          await tester.pumpAndSettle();
          expect(
            sheet,
            findsNothing,
            reason: 'Saldo: ${await balance(adjustItem)}. Pesan: $messages',
          );
        } else {
          expect(
            find.textContaining('Stok akhir tidak boleh negatif'),
            findsOneWidget,
          );
          Navigator.of(tester.element(find.text('Jenis penyesuaian'))).pop();
          await tester.pumpAndSettle();
        }
      }

      await go(AppRoutes.transaction);
      final initial = await _snapshot(db);
      await checkout(allowed: false);
      expect(await _snapshot(db), initial);
      debugPrint('E2E74: zero-stock sale rejected without writes');

      // Open the detail route directly so the stock list has no active listener.
      await go('${AppRoutes.stock}/$adjustItem');
      await adjust('Kurangi stok', '0,1', allowed: false);
      await adjust('Set stok akhir', '-0,3', allowed: false);
      expect(await _snapshot(db), initial);
      debugPrint(
        'E2E74: both negative adjustment paths rejected without writes',
      );

      await toggle(true);
      await go(AppRoutes.transaction);
      await checkout(allowed: true);
      await checkout(allowed: true);
      expect(await balance(saleItem), -2);
      final sales = await db.query('sales_transactions', orderBy: 'id');
      expect(sales, hasLength(2));
      debugPrint(
        'E2E74: settings UI enables zero-stock and negative-stock checkout',
      );

      await go('${AppRoutes.stock}/$adjustItem');
      await adjust('Kurangi stok', '0,1', allowed: true);
      expect(await balance(adjustItem), -0.1);
      await adjust('Set stok akhir', '-0,3', allowed: true);
      expect(await balance(adjustItem), -0.3);
      expect(find.text('-0,3 kg'), findsWidgets);
      expect(find.text('Stok -0,1 -> -0,3'), findsOneWidget);
      expect(
        (await movements(adjustItem)).map(
          (row) => [row['qty_before'], row['qty_change'], row['qty_after']],
        ),
        [
          [0, -0.1, -0.1],
          [-0.1, -0.2, -0.3],
        ],
      );
      await go(AppRoutes.stock);
      final stockBalance = find.text('-0,3 kg');
      await tester.scrollUntilVisible(
        stockBalance,
        240,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      final stockCard = find
          .ancestor(of: stockBalance, matching: find.byType(InkWell))
          .first;
      expect(
        find.descendant(of: stockCard, matching: find.text('Stok Habis')),
        findsOneWidget,
      );
      await go(AppRoutes.catalog);
      expect(find.text('-0,3 stok tersedia'), findsOneWidget);
      debugPrint(
        'E2E74: signed inputs, stock badges and signed ledger verified in UI',
      );

      await toggle(false);
      await go(AppRoutes.catalog);
      router.push<void>('${AppRoutes.catalog}/edit/$adjustItem');
      await tester.pumpAndSettle();
      final itemName = find.byWidgetPredicate(
        (widget) =>
            widget is TextFormField &&
            widget.controller?.text == adjustmentName,
      );
      await tester.enterText(itemName, 'Barang Uji Berganti Nama');
      await tap(find.text('Simpan Perubahan'));
      expect(find.text('Simpan Perubahan'), findsNothing);
      expect(find.text('Barang Uji Berganti Nama'), findsOneWidget);
      expect(await balance(adjustItem), -0.3);
      expect(await movements(adjustItem), hasLength(2));
      expect(
        (await db.query(
          'items',
          where: 'id = ?',
          whereArgs: [adjustItem],
        )).single['name'],
        'Barang Uji Berganti Nama',
      );
      debugPrint(
        'E2E74: catalog metadata edit preserves a negative balance with option off',
      );

      final invoice = sales.first['invoice_no'];
      await go('${AppRoutes.history}/$invoice');
      await tap(
        find.widgetWithText(OutlinedButton, 'Batalkan Transaksi (Void)'),
      );
      await tap(find.widgetWithText(FilledButton, 'Ya, Batalkan'));
      await tester.pumpAndSettle();
      expect(
        find.text('Data telah divoid dan stok dikembalikan'),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(OutlinedButton, 'Batalkan Transaksi (Void)'),
        findsNothing,
      );
      expect(await balance(saleItem), -1);
      expect(
        (await movements(saleItem)).map(
          (row) => [row['qty_before'], row['qty_change'], row['qty_after']],
        ),
        [
          [0, -1, -1],
          [-1, -1, -2],
          [-2, 1, -1],
        ],
      );
      expect(
        (await db.query('sales_transactions', orderBy: 'id')).first['status'],
        'voided',
      );
      debugPrint(
        'E2E74: UI void returns the sold quantity once after option is turned off',
      );

      final expected = await _snapshot(db);
      final logger = Logger('negative-stock-e2e');
      final file = await AppBackupService(
        database: source,
        logger: logger,
        backupDirectoryProvider: () async => root,
      ).createBackup(password: null);
      final restore = AppRestoreService(database: destination, logger: logger);
      await restore.restoreBackup(
        await restore.inspectBackupFile(file.filePath),
      );
      final restored = await destination.database();
      expect(await _snapshot(restored), expected);
      expect(await restored.rawQuery('PRAGMA foreign_key_check'), isEmpty);
      expect(await _snapshot(db), expected);
      expect(tester.takeException(), isNull);
      debugPrint(
        'E2E74: real Android backup and restore preserve all tables and signed balances',
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );
}
