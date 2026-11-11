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
import 'package:pujangga_pos/features/transaksi/presentation/controllers/transaksi_controller.dart';
import 'package:pujangga_pos/features/transaksi/presentation/models/transaksi_state.dart';
import 'package:pujangga_pos/features/transaksi/presentation/pages/transaksi_berhasil_page.dart';

class _DisposableDatabase extends AppDatabase {
  _DisposableDatabase(this.filePath);
  final String filePath;
  @override
  Future<String> databasePath() async => filePath;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  for (final currency in ['IDR', 'USD', 'SGD']) {
    testWidgets('$currency discounted tax UI checkout and SQLite persistence', (
      tester,
    ) async {
      initializeAppDateFormatting();
      final temporary = await getTemporaryDirectory();
      expect(
        temporary.path,
        contains('/com.pujanggapos.pujangga_pos.pr67e2e/'),
      );
      final directory = await Directory(
        path.join(
          temporary.path,
          'tax-e2e-$currency-${DateTime.now().microsecondsSinceEpoch}',
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
        'business_name': 'PR67 Synthetic $currency',
        'business_type': 'retail',
        'created_at': stamp,
        'updated_at': stamp,
      });
      await db.update('app_settings', {
        'currency_code': currency,
        'currency_symbol': currency == 'IDR' ? 'Rp' : r'$',
        'default_tax_percent': 10,
      });
      final scale = currency == 'IDR' ? 1000.0 : 1.0;
      final itemId = await db.insert('items', {
        'name': 'PR67 Kopi',
        'item_type': 'product',
        'unit': 'Pcs',
        'sale_price': 100 * scale,
        'harga_modal': 40 * scale,
        'stock_qty': 100,
        'created_at': stamp,
        'updated_at': stamp,
      });
      final roundingId = await db.insert('items', {
        'name': 'PR67 Batas',
        'item_type': 'product',
        'unit': 'Pcs',
        'sale_price': currency == 'IDR' ? 200 : 2,
        'harga_modal': 0,
        'stock_qty': 100,
        'created_at': stamp,
        'updated_at': stamp,
      });
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

      Future<void> tapFinder(Finder finder) async {
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pumpAndSettle();
        await tester.ensureVisible(finder);
        await tester.tap(finder);
        await tester.pumpAndSettle();
      }

      Future<void> tap(String label) => tapFinder(find.text(label).last);
      TransaksiState current() =>
          container.read(transaksiControllerProvider).requireValue;
      TransaksiController controller() =>
          container.read(transaksiControllerProvider.notifier);
      Future<void> shot(String label) async {
        debugPrint('E2E_SCREENSHOT: $currency-$label');
        await Future<void>.delayed(const Duration(seconds: 2));
      }

      Future<void> discount(bool order, double amount) async {
        if (order) {
          await tapFinder(
            find
                .byWidgetPredicate(
                  (w) =>
                      w is Text &&
                      w.style?.decoration == TextDecoration.underline,
                )
                .last,
          );
        } else {
          await tapFinder(find.byIcon(Icons.percent).last);
        }
        final field = find.byWidgetPredicate(
          (w) =>
              w is TextField &&
              w.decoration?.labelText ==
                  (order ? 'Diskon Total' : 'Diskon Item'),
        );
        expect(field, findsOneWidget);
        await tester.enterText(field, '$amount');
        await tap('Terapkan Diskon');
      }

      void verify(double tax, double total) {
        expect(current().taxAmount, closeTo(tax, 1e-8));
        expect(current().totalAmount, closeTo(total, 1e-8));
        expect(find.text(CurrencyFormatter.format(tax)), findsWidgets);
        expect(find.text(CurrencyFormatter.format(total)), findsWidgets);
      }

      Future<void> start({String name = 'PR67 Kopi', bool cash = false}) async {
        await tap(name);
        await tap('Keranjang');
        if (!cash) await tap('QRIS');
      }

      var sales = 0;
      Future<void> pay(
        String label,
        double tax,
        double total, {
        bool cash = false,
      }) async {
        verify(tax, total);
        if (cash) {
          final cashField = find.byWidgetPredicate(
            (w) => w is TextField && w.textAlign == TextAlign.right,
          );
          await tester.ensureVisible(cashField);
          await tester.enterText(cashField, '${total + scale}');
          await tester.pumpAndSettle();
          expect(current().changeAmount, closeTo(scale, 1e-8));
          await shot('$label-keyboard');
        }
        await shot('$label-cart');
        if (!cash) await tap('QRIS');
        await tap('Proses Pembayaran');
        expect(find.byType(TransaksiBerhasilPage), findsOneWidget);
        final row = (await db.query(
          'sales_transactions',
          orderBy: 'id DESC',
          limit: 1,
        )).single;
        expect(row['tax_amount'], closeTo(tax, 1e-8));
        expect(row['total_amount'], closeTo(total, 1e-8));
        if (cash) {
          expect(row['payment_method'], 'cash');
          expect(row['paid_amount'], closeTo(total + scale, 1e-8));
          expect(row['change_amount'], closeTo(scale, 1e-8));
        }
        final details = await db.query(
          'sales_transaction_items',
          where: 'transaction_id = ?',
          whereArgs: [row['id']],
        );
        expect(details, hasLength(1));
        expect(details.single['qty'], 1);
        expect(find.text(CurrencyFormatter.format(total)), findsWidgets);
        sales++;
        expect(await db.query('sales_transactions'), hasLength(sales));
        debugPrint(
          'E2E_PASS: $currency $label UI checkout SQLite tax=$tax total=$total invoice=${row['invoice_no']}',
        );
        await shot('$label-receipt');
        await tap('Transaksi Baru');
      }

      await mount();
      await tap('Transaksi');

      await start();
      verify(10 * scale, 110 * scale);
      await discount(true, 20 * scale);
      verify(8 * scale, 88 * scale);
      await discount(true, 0);
      verify(10 * scale, 110 * scale);
      await discount(true, 20 * scale);
      await tapFinder(find.byIcon(Icons.add).last);
      verify(18 * scale, 198 * scale);
      await tapFinder(find.byIcon(Icons.remove).last);
      verify(8 * scale, 88 * scale);
      await pay('01-order-discount', 8 * scale, 88 * scale);

      await start();
      await discount(false, 20 * scale);
      await pay('02-item-discount', 8 * scale, 88 * scale);
      final equivalent = await db.query(
        'sales_transactions',
        orderBy: 'id',
        limit: 2,
      );
      expect(equivalent[0]['tax_amount'], equivalent[1]['tax_amount']);
      expect(equivalent[0]['total_amount'], equivalent[1]['total_amount']);
      expect(equivalent[0]['discount_amount'], 20 * scale);
      expect(equivalent[1]['discount_amount'], 20 * scale);
      final equivalentDetails = await db.query(
        'sales_transaction_items',
        orderBy: 'id',
        limit: 2,
      );
      expect(equivalentDetails[0]['line_discount_amount'], 0);
      expect(equivalentDetails[1]['line_discount_amount'], 20 * scale);

      await start();
      await discount(false, 10 * scale);
      await discount(true, 20 * scale);
      verify(7 * scale, 77 * scale);
      await discount(true, 90 * scale);
      verify(0, 0);
      await discount(true, 20 * scale);
      await pay('03-combined-discounts', 7 * scale, 77 * scale);

      await start();
      await discount(true, 100 * scale);
      await pay('04-full-discount', 0, 0);

      // The product has no manual-tax input. Exercise its public controller in
      // the mounted app, then finish via real UI and the real SQLite repository.
      await start();
      controller().updateTaxAmount(7);
      await tester.pumpAndSettle();
      await discount(true, 20 * scale);
      await tapFinder(find.byIcon(Icons.add).last);
      verify(7, 180 * scale + 7);
      await tapFinder(find.byIcon(Icons.remove).last);
      expect(current().taxMode, TaxMode.manual);
      await pay('05-manual-tax', 7, 80 * scale + 7);
      await start();
      expect(current().taxMode, TaxMode.automatic);
      verify(10 * scale, 110 * scale);
      controller().updateTaxAmount(0);
      await tester.pumpAndSettle();
      await discount(true, 20 * scale);
      await pay('06-manual-zero', 0, 80 * scale);

      // Cash is kept selected while editing both discounts. This reproduces
      // the initially clipped item control and exercises real keyboard insets.
      await start(cash: true);
      await discount(false, 10 * scale);
      await discount(true, 10 * scale);
      await pay('07-cash-discounts', 8 * scale, 88 * scale, cash: true);

      await start(name: 'PR67 Batas');
      final roundingDiscount = currency == 'IDR' ? 55.0 : 0.55;
      final roundedTax = currency == 'IDR' ? 15.0 : 0.15;
      final roundingBase = currency == 'IDR' ? 145.0 : 1.45;
      await discount(true, roundingDiscount);
      await pay('08-rounding', roundedTax, roundingBase + roundedTax);
      expect(sales, 8);
      expect(
        (await db.query(
          'items',
          where: 'id = ?',
          whereArgs: [itemId],
        )).single['stock_qty'],
        93,
      );
      expect(
        (await db.query(
          'items',
          where: 'id = ?',
          whereArgs: [roundingId],
        )).single['stock_qty'],
        99,
      );
      expect(
        await db.query('stock_movements', where: "movement_type = 'sale'"),
        hasLength(8),
      );
      final snapshot = await db.query('sales_transactions', orderBy: 'id');
      await tap('Laporan');
      await shot('08-report');
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
      await tap('Transaksi');
      await start();
      verify(10 * scale, 110 * scale);
      debugPrint(
        'E2E_PASS: $currency reopened SQLite: 8 sales retained, stock reconciled, integrity=ok, foreign_keys=ok, next draft automatic',
      );
      await shot('09-reopened');
      await tester.pumpWidget(const SizedBox.shrink());
      await reopened.reset();
      expect(tester.takeException(), isNull);
    });
  }
}
