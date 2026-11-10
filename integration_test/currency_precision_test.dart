import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:pujangga_pos/app/app.dart';
import 'package:pujangga_pos/core/database/app_database.dart';
import 'package:pujangga_pos/core/services/app_startup_service.dart';
import 'package:pujangga_pos/core/utils/app_date_formatting.dart';
import 'package:pujangga_pos/core/utils/currency_formatter.dart';
import 'package:pujangga_pos/features/katalog/presentation/pages/item_form_page.dart';
import 'package:pujangga_pos/features/pengaturan/presentation/controllers/pengaturan_settings_controller.dart';
import 'package:pujangga_pos/features/pengaturan/presentation/pages/pengaturan_page.dart';
import 'package:pujangga_pos/features/transaksi/presentation/controllers/transaksi_controller.dart';
import 'package:pujangga_pos/features/transaksi/presentation/pages/transaksi_berhasil_page.dart';

class _DisposableDatabase extends AppDatabase {
  _DisposableDatabase(this.filePath);
  final String filePath;
  @override
  Future<String> databasePath() async => filePath;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  for (final currency in ['USD', 'SGD', 'IDR']) {
    testWidgets('$currency prices and taxes survive UI save, checkout and reopen', (
      tester,
    ) async {
      initializeAppDateFormatting();
      final temporary = await getTemporaryDirectory();
      // Identity and effective path must be proven before the first DB write.
      expect(
        temporary.path,
        contains('/com.pujanggapos.pujangga_pos.pr63e2e/'),
      );
      final directory = await Directory(
        path.join(
          temporary.path,
          'currency-e2e-$currency-${DateTime.now().microsecondsSinceEpoch}',
        ),
      ).create();
      final file = path.join(directory.path, 'isolated.db');
      final database = _DisposableDatabase(file);
      expect(
        path.isWithin(temporary.path, await database.databasePath()),
        isTrue,
      );
      debugPrint('E2E_ISOLATION: $currency $file');
      final db = await database.database();
      final stamp = DateTime.now().toIso8601String();
      await db.insert('business_profile', {
        'business_name': 'PR63 Synthetic $currency',
        'business_type': 'retail',
        'modal_awal_usaha': 1000000,
        'created_at': stamp,
        'updated_at': stamp,
      });
      final idr = currency == 'IDR';
      final price = idr ? 1500.0 : 1.50;
      final cost = idr ? 650.0 : 0.65;
      final wholesale = idr ? 1250.0 : 1.25;
      final itemId = await db.insert('items', {
        'name': 'PR63 Kopi',
        'item_type': 'product',
        'unit': 'Pcs',
        'sale_price': price,
        'harga_modal': cost,
        'stock_qty': 10,
        'wholesale_price': wholesale,
        'wholesale_min_quantity': 2,
        'created_at': stamp,
        'updated_at': stamp,
      });
      for (final entry in {
        'PR63 Satu': idr ? 1000.0 : 1.0,
        'PR63 Batas': idr ? 1450.0 : 1.45,
      }.entries) {
        await db.insert('items', {
          'name': entry.key,
          'item_type': 'product',
          'unit': 'Pcs',
          'sale_price': entry.value,
          'harga_modal': 0,
          'stock_qty': 10,
          'created_at': stamp,
          'updated_at': stamp,
        });
      }
      var container = ProviderContainer(
        overrides: [appDatabaseProvider.overrideWithValue(database)],
      );
      addTearDown(() async {
        container.dispose();
        await database.reset();
        await directory.delete(recursive: true);
        debugPrint('E2E_CLEANUP: $currency isolated database removed');
      });

      Future<void> mount() async {
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const PujanggaPosApp(),
          ),
        );
        await tester.pumpAndSettle();
      }

      Future<void> clearNotification() async {
        for (
          var i = 0;
          i < 60 && find.byType(SnackBar).evaluate().isNotEmpty;
          i++
        ) {
          await tester.pump(const Duration(milliseconds: 100));
          await Future<void>.delayed(const Duration(milliseconds: 100));
        }
      }

      Future<void> tap(String label) async {
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pumpAndSettle();
        await clearNotification();
        final finder = find.text(label).last;
        await tester.ensureVisible(finder);
        await tester.tap(finder);
        await tester.pumpAndSettle();
      }

      Future<void> screenshot(String label) async {
        debugPrint('E2E_SCREENSHOT: $currency-$label');
        await Future<void>.delayed(const Duration(seconds: 2));
      }

      await mount();
      await tester.tap(find.byIcon(Icons.menu).first);
      await tester.pumpAndSettle();
      expect(find.byType(PengaturanPage), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Mata Uang'),
        350,
        scrollable: find
            .descendant(
              of: find.byType(PengaturanPage),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tap('Mata Uang');
      await tap(switch (currency) {
        'USD' => r'US Dollar (USD) - $',
        'SGD' => r'Singapore Dollar (SGD) - S$',
        _ => 'Rupiah (IDR) - Rp',
      });
      await tap('Pajak Default');
      await tester.enterText(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextFormField),
        ),
        '10',
      );
      await tap('Simpan');
      await clearNotification();
      final settings = await container.read(appSettingsProvider.future);
      expect(settings.currencyCode, currency);
      expect(settings.defaultTaxPercent, 10);
      expect(
        (await db.query('app_settings')).single['currency_code'],
        currency,
      );
      await tester.tap(find.byIcon(Icons.arrow_back).first);
      await tester.pumpAndSettle();

      await tap('Katalog');
      await tester.enterText(find.byType(TextField).first, 'PR63 Kopi');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byType(PopupMenuButton<String>).first);
      await tester.tap(find.byType(PopupMenuButton<String>).first);
      await tester.pumpAndSettle();
      await tap('Edit item');
      expect(find.byType(ItemFormPage), findsOneWidget);
      // The first item is selected by the actual catalog menu; verify identity.
      final nameField = find.byWidgetPredicate(
        (w) => w is TextFormField && w.controller?.text == 'PR63 Kopi',
      );
      expect(nameField, findsOneWidget);
      expect(find.text(idr ? '1500' : '1.50'), findsOneWidget);
      expect(find.text(idr ? '650' : '0.65'), findsOneWidget);
      expect(find.text(idr ? '1250' : '1.25'), findsOneWidget);
      await tester.enterText(nameField, 'PR63 Kopi Baru');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await screenshot('01-edit-prices');
      await tap('Simpan Perubahan');
      final edited = (await db.query(
        'items',
        where: 'id = ?',
        whereArgs: [itemId],
      )).single;
      expect(edited['name'], 'PR63 Kopi Baru');
      expect(edited['sale_price'], price);
      expect(edited['harga_modal'], cost);
      expect(edited['wholesale_price'], wholesale);
      debugPrint(
        'E2E_PASS: $currency name-only UI edit persisted price=$price cost=$cost wholesale=$wholesale',
      );

      await tap('Transaksi');
      Future<void> checkout(
        String name,
        int quantity,
        double subtotal,
        double tax,
        double total,
      ) async {
        for (var i = 0; i < quantity; i++) {
          await tap(name);
        }
        await tap('Keranjang');
        final state = container.read(transaksiControllerProvider).requireValue;
        expect(state.subtotalAmount, closeTo(subtotal, 1e-9));
        expect(state.taxAmount, closeTo(tax, 1e-9));
        expect(state.totalAmount, closeTo(total, 1e-9));
        expect(find.text(CurrencyFormatter.format(tax)), findsWidgets);
        await screenshot('02-cart-${name.split(' ').last}');
        await tap('QRIS');
        await tap('Proses Pembayaran');
        expect(find.byType(TransaksiBerhasilPage), findsOneWidget);
        final sale = (await db.query(
          'sales_transactions',
          orderBy: 'id DESC',
          limit: 1,
        )).single;
        expect(sale['subtotal_amount'], closeTo(subtotal, 1e-9));
        expect(sale['tax_amount'], closeTo(tax, 1e-9));
        expect(sale['total_amount'], closeTo(total, 1e-9));
        final details = await db.query(
          'sales_transaction_items',
          where: 'transaction_id = ?',
          whereArgs: [sale['id']],
        );
        expect(
          details.single['price_snapshot'],
          closeTo(subtotal / quantity, 1e-9),
        );
        expect(details.single['qty'], quantity);
        debugPrint(
          'E2E_PASS: $currency $name qty=$quantity SQLite subtotal=$subtotal tax=$tax total=$total invoice=${sale['invoice_no']}',
        );
        await screenshot('03-receipt-${name.split(' ').last}');
        await tap('Transaksi Baru');
      }

      await checkout(
        'PR63 Satu',
        1,
        idr ? 1000 : 1,
        idr ? 100 : 0.10,
        idr ? 1100 : 1.10,
      );
      await checkout(
        'PR63 Batas',
        1,
        idr ? 1450 : 1.45,
        idr ? 145 : 0.15,
        idr ? 1595 : 1.60,
      );
      await checkout(
        'PR63 Kopi Baru',
        2,
        idr ? 2500 : 2.50,
        idr ? 250 : 0.25,
        idr ? 2750 : 2.75,
      );
      expect(await db.query('sales_transactions'), hasLength(3));
      expect(
        await db.query('stock_movements', where: "movement_type = 'sale'"),
        hasLength(3),
      );
      expect(
        (await db.query(
          'items',
          where: 'id = ?',
          whereArgs: [itemId],
        )).single['stock_qty'],
        8,
      );
      final snapshot = await db.query('sales_transactions', orderBy: 'id');
      await tap('Laporan');
      await screenshot('04-report');

      // Dispose providers, close SQLite, and start from the same on-disk data.
      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
      await db.close();
      final reopened = _DisposableDatabase(file);
      final persisted = await reopened.database();
      expect(
        await persisted.query('sales_transactions', orderBy: 'id'),
        snapshot,
      );
      expect(
        (await persisted.query(
          'items',
          where: 'id = ?',
          whereArgs: [itemId],
        )).single['sale_price'],
        price,
      );
      expect(
        (await persisted.rawQuery('PRAGMA integrity_check'))
            .single
            .values
            .single,
        'ok',
      );
      expect(await persisted.rawQuery('PRAGMA foreign_key_check'), isEmpty);
      container = ProviderContainer(
        overrides: [appDatabaseProvider.overrideWithValue(reopened)],
      );
      await mount();
      expect(
        (await container.read(appSettingsProvider.future)).currencyCode,
        currency,
      );
      await tap('Katalog');
      expect(find.text('PR63 Kopi Baru'), findsOneWidget);
      await screenshot('05-reopened-catalog');
      debugPrint(
        'E2E_PASS: $currency reopened SQLite: 3 sales, prices/stock/settings retained, integrity=ok, foreign_keys=ok',
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await reopened.reset();
      expect(tester.takeException(), isNull);
    });
  }
}
