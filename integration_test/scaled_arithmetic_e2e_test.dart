import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pujangga_pos/app/app.dart';
import 'package:pujangga_pos/core/database/app_database.dart';
import 'package:pujangga_pos/core/services/app_startup_service.dart';
import 'package:pujangga_pos/core/utils/app_date_formatting.dart';
import 'package:pujangga_pos/core/utils/quantity_formatter.dart';
import 'package:pujangga_pos/core/utils/scaled_arithmetic.dart';
import 'package:pujangga_pos/features/pengaturan/data/services/app_backup_service.dart';
import 'package:pujangga_pos/features/pengaturan/data/services/app_restore_service.dart';
import 'package:pujangga_pos/features/pengaturan/presentation/controllers/pengaturan_settings_controller.dart';
import 'package:pujangga_pos/features/riwayat/presentation/pages/detail_transaksi_page.dart';
import 'package:pujangga_pos/features/stok/data/datasources/stock_local_data_source.dart';
import 'package:pujangga_pos/features/stok/domain/entities/stock_adjustment_request.dart';
import 'package:pujangga_pos/features/transaksi/data/datasources/transaction_local_data_source.dart';
import 'package:pujangga_pos/features/transaksi/domain/entities/transaksi_cart_item.dart';
import 'package:pujangga_pos/features/transaksi/domain/entities/transaksi_submit_request.dart';
import 'package:pujangga_pos/features/transaksi/presentation/controllers/transaksi_controller.dart';
import 'package:pujangga_pos/features/transaksi/presentation/models/transaksi_state.dart';
import 'package:pujangga_pos/features/transaksi/presentation/pages/transaksi_berhasil_page.dart';
import 'package:sqflite/sqflite.dart';

const package = 'com.pujanggapos.pujangga_pos.pr82e2e';
const revision = String.fromEnvironment('E2E_SOURCE_REVISION');
typedef Tables = Map<String, List<Map<String, Object?>>>;

class TestDatabase extends AppDatabase {
  TestDatabase(this.file);
  final String file;
  @override
  Future<String> databasePath() async => file;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('PR82 real Android decimal checkout, void, reopen and backup', (
    tester,
  ) async {
    initializeAppDateFormatting();
    expect(revision, matches(RegExp(r'^[a-f0-9]{40}$')));
    final cache = await getTemporaryDirectory();
    expect(cache.path, contains('/$package/'));
    final evidence = Directory(p.join(cache.path, 'pr82-evidence'));
    expect(
      await evidence.exists(),
      isFalse,
      reason: 'Never reuse stale evidence',
    );
    await evidence.create();
    final events = <String>[];
    final results = <String, Object?>{};
    void passed(String name) {
      events.add(name);
      debugPrint('PR82_PASS: $name');
    }

    Future<void> tap(Finder finder) async {
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      expect(finder, findsOneWidget);
      await tester.ensureVisible(finder);
      await tester.tap(finder);
      await tester.pumpAndSettle();
    }

    Future<void> capture(String name) async {
      debugPrint('PR82_CAPTURE: $name');
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(seconds: 3)),
      );
    }

    Future<Tables> snapshot(Database db) async => {
      for (final table in AppBackupService.backupTables)
        table: await db.query(table, orderBy: 'id'),
    };
    Finder quantityLabel() => find.byWidgetPredicate(
      (widget) =>
          widget is Text &&
          widget.style?.fontSize == 14 &&
          widget.style?.decoration == TextDecoration.underline,
    );
    final cash = find.byWidgetPredicate(
      (widget) => widget is TextField && widget.textAlign == TextAlign.right,
    );
    final submit = find.widgetWithText(FilledButton, 'Proses Pembayaran');
    Future<void> editQuantity(String text) async {
      await tap(quantityLabel());
      final field = find.byWidgetPredicate(
        (widget) =>
            widget is TextField && widget.decoration?.labelText == 'Kuantitas',
      );
      await tester.enterText(field, text);
      await tap(find.widgetWithText(FilledButton, 'Simpan'));
    }

    Future<void> closeCartIfOpen() async {
      final title = find.text('Keranjang Transaksi');
      if (title.evaluate().isNotEmpty) {
        Navigator.of(tester.element(title)).pop();
        await tester.pumpAndSettle();
      }
    }

    for (final currency in ['USD', 'SGD', 'IDR']) {
      final factor = currency == 'IDR' ? 100.0 : 1.0;
      final root = await cache.createTemp('pr82-$currency-');
      var source = TestDatabase(p.join(root.path, 'source.sqlite'));
      var destination = TestDatabase(p.join(root.path, 'restored.sqlite'));
      for (final database in [source, destination]) {
        expect(p.isWithin(root.path, await database.databasePath()), isTrue);
        final connection = await database.database();
        final effective = (await connection.rawQuery('PRAGMA database_list'))
            .singleWhere((row) => row['name'] == 'main');
        expect(effective['file'], await database.databasePath());
      }
      expect(
        await source.databasePath(),
        isNot(await destination.databasePath()),
      );
      debugPrint('PR82_ISOLATION: $currency ${root.path}');
      var db = await source.database();
      final stamp = DateTime.now().toIso8601String();
      await db.insert('business_profile', {
        'business_name': 'PR82 Synthetic $currency',
        'business_type': 'retail',
        'created_at': stamp,
        'updated_at': stamp,
      });
      await db.update('app_settings', {
        'currency_code': currency,
        'currency_symbol': currency == 'IDR' ? 'Rp' : r'$',
        'default_tax_percent': 0,
      });
      Future<int> seed(
        String name,
        String type,
        double price,
        double stock,
        String unit,
      ) async {
        final id = await db.insert('items', {
          'name': name,
          'item_type': type,
          'sale_price': price * factor,
          'stock_qty': stock,
          'unit': unit,
          'harga_modal': type == 'product' ? 0.04 * factor : null,
          'biaya_dasar': type == 'service' ? 0.02 * factor : null,
          'created_at': stamp,
          'updated_at': stamp,
        });
        if (type == 'product') {
          await db.insert('stock_movements', {
            'item_id': id,
            'movement_type': 'initial',
            'qty_change': stock,
            'qty_before': 0,
            'qty_after': stock,
            'reference_type': 'item',
            'reference_id': id,
            'created_at': stamp,
          });
        }
        return id;
      }

      final weighted = await seed('PR82 Berat', 'product', 1, 0.3, 'kg');
      final cents = await seed('PR82 Sen', 'product', 0.1, 20, 'Pcs');
      final service = await seed('PR82 Jasa', 'service', 0.1, 0, 'Layanan');
      final partial = await seed('PR82 Bagian', 'product', 1, 0.3, 'kg');
      final employee = await db.insert('employees', {
        'name': 'PR82 Komisi',
        'is_active': 1,
        'compensation_type': 'commission',
        'commission_percent': 10,
        'commission_scope': 'service',
        'effective_from': stamp,
        'created_at': stamp,
        'updated_at': stamp,
      });
      var container = ProviderContainer(
        overrides: [appDatabaseProvider.overrideWithValue(source)],
      );
      TransaksiState current() =>
          container.read(transaksiControllerProvider).requireValue;
      TransaksiController controller() =>
          container.read(transaksiControllerProvider.notifier);
      Future<void> mount() async {
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const PujanggaPosApp(),
          ),
        );
        await tester.pumpAndSettle();
        tester.testTextInput.register();
      }

      Future<void> openCart(String name) async {
        await tap(find.text(name).first);
        await tap(find.text('Keranjang'));
      }

      Future<void> pay(double amount, {bool native = false}) async {
        await tester.ensureVisible(cash);
        await tester.enterText(cash, '');
        if (native) {
          FocusManager.instance.primaryFocus?.unfocus();
          await tester.pumpAndSettle();
          tester.testTextInput.unregister();
          await tester.tap(cash);
          await tester.pumpAndSettle();
          debugPrint('PR82_ADB_INPUT: ${amount.toStringAsFixed(2)}');
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(seconds: 5)),
          );
          await tester.pumpAndSettle();
        } else {
          await tester.enterText(cash, '$amount');
        }
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pumpAndSettle();
        if (native) tester.testTextInput.register();
        expect(current().cashPaidAmount, amount);
        expect(current().canSubmit, isTrue);
        await tap(submit);
        expect(find.byType(TransaksiBerhasilPage), findsOneWidget);
        expect(tester.takeException(), isNull);
      }

      Future<void> newSale() async =>
          tap(find.widgetWithText(FilledButton, 'Transaksi Baru'));
      Future<double> stock(int id) async =>
          ((await db.query(
                    'items',
                    where: 'id = ?',
                    whereArgs: [id],
                  )).single['stock_qty']
                  as num)
              .toDouble();
      try {
        await mount();
        await tap(find.text('Transaksi').last);
        await openCart('PR82 Berat');
        await editQuantity('0.1234');
        expect(current().cartItems.single.quantity, 1);
        await editQuantity('0.001');
        expect(current().cartItems.single.quantity, 0.001);
        await editQuantity('1');
        for (var index = 0; index < 10; index++) {
          await tap(find.byIcon(Icons.remove));
        }
        expect(current().cartItems, isEmpty);
        passed('$currency ten UI decrements remove cart row');
        // Close the empty cart, then start the stock-exhaustion scenario.
        await closeCartIfOpen();
        await openCart('PR82 Berat');
        await editQuantity('0.1');
        await tap(find.byIcon(Icons.add).last);
        await tap(find.byIcon(Icons.add).last);
        expect(current().cartItems.single.quantity, 0.3);
        expect(current().totalAmount, 0.3 * factor);
        await pay(0.3 * factor);
        expect(await stock(weighted), 0);
        expect(
          (await db.query(
            'stock_movements',
            where: 'item_id = ?',
            whereArgs: [weighted],
            orderBy: 'id DESC',
            limit: 1,
          )).single['qty_after'],
          0,
        );
        await capture('${currency.toLowerCase()}-fractional-receipt');
        passed('$currency UI 0.1 + 0.1 + 0.1 sells stock 0.3 exactly');
        await newSale();
        // The exact cents case uses Android's real IME + adb input on USD.
        await openCart('PR82 Sen');
        await editQuantity('3');
        await tester.enterText(cash, '${0.29 * factor}');
        await tester.pumpAndSettle();
        expect(current().canSubmit, isFalse);
        expect(tester.widget<FilledButton>(submit).onPressed, isNull);
        await pay(0.3 * factor, native: currency == 'USD');
        final exact = (await db.query(
          'sales_transactions',
          orderBy: 'id DESC',
          limit: 1,
        )).single;
        expect(exact['total_amount'], 0.3 * factor);
        expect(exact['paid_amount'], 0.3 * factor);
        expect(exact['change_amount'], 0);
        await capture('${currency.toLowerCase()}-exact-payment');
        passed(
          '$currency UI 0.10 x 3 exact payment; insufficient payment blocked',
        );
        await newSale();
        for (var index = 0; index < 3; index++) {
          await openCart('PR82 Bagian');
          await editQuantity('0.1');
          await pay(0.1 * factor);
          expect(await stock(partial), [0.2, 0.1, 0.0][index]);
          await newSale();
        }
        passed('$currency three partial sales leave zero stock');
        // Keep oversized finite input editable and exercise all affected UI paths.
        await openCart('PR82 Sen');
        final beforeBad = await snapshot(db);
        controller().setQuantity('$cents', 1e100);
        await tester.pumpAndSettle();
        await tap(find.byIcon(Icons.add).last);
        await tap(find.byIcon(Icons.remove));
        expect(current().cartItems.single.quantity, 1e100);
        expect(current().canSubmit, isFalse);
        expect(find.textContaining('Nominal tidak valid'), findsWidgets);
        expect(tester.takeException(), isNull);
        controller().addItem(current().cartItems.single.item);
        expect(current().cartItems.single.quantity, 1e100);
        expect(await snapshot(db), beforeBad);
        await capture('${currency.toLowerCase()}-overflow-validation');
        await editQuantity('1');
        expect(current().cartItems.single.quantity, 1);
        await tap(find.byTooltip('Hapus Semua'));
        await closeCartIfOpen();
        passed(
          '$currency overflow controls do not throw and valid UI input recovers',
        );
        // Mixed real UI checkout; percent tax and commission use native SQLite.
        await db.update('app_settings', {'default_tax_percent': 10});
        container.invalidate(appSettingsProvider);
        await container.read(appSettingsProvider.future);
        await tap(find.text('PR82 Sen').first);
        await tap(find.text('PR82 Jasa').first);
        await tap(find.text('Keranjang'));
        controller().setQuantity('$cents', 3);
        controller().setQuantity('$service', 3);
        controller().updateItemDiscount('$cents', 0.01 * factor);
        controller().updateOrderDiscount(0.09 * factor);
        await tester.pumpAndSettle();
        await tap(find.byType(DropdownButtonFormField<int?>));
        await tap(find.textContaining('PR82 Komisi').last);
        expect(current().employeeId, employee);
        expect(current().taxAmount, 0.05 * factor);
        final mixedTotal = currency == 'IDR' ? 55.0 : 0.55;
        expect(current().totalAmount, mixedTotal);
        await pay(mixedTotal);
        final mixed = (await db.query(
          'sales_transactions',
          orderBy: 'id DESC',
          limit: 1,
        )).single;
        expect(mixed['commission_amount'], 0.03 * factor);
        expect((await db.query('expenses')).single['amount'], 0.03 * factor);
        await capture('${currency.toLowerCase()}-mixed-receipt');
        passed(
          '$currency mixed sale item/order discount tax and commission reconcile',
        );
        final invoice = mixed['invoice_no'] as String;
        GoRouter.of(tester.element(find.byType(TransaksiBerhasilPage)))
            .go('/history/$invoice');
        await tester.pumpAndSettle();
        expect(find.byType(DetailTransaksiPage), findsOneWidget);
        await tap(
          find.widgetWithText(OutlinedButton, 'Batalkan Transaksi (Void)'),
        );
        await tap(find.widgetWithText(FilledButton, 'Ya, Batalkan'));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(seconds: 1)),
        );
        await tester.pumpAndSettle();
        expect(
          (await db.query(
            'sales_transactions',
            where: 'invoice_no = ?',
            whereArgs: [invoice],
          )).single['status'],
          'voided',
        );
        expect(await db.query('expenses'), isEmpty);
        expect(await stock(cents), 17);
        expect(
          find.text('Data telah divoid dan stok dikembalikan'),
          findsOneWidget,
        );
        await capture('${currency.toLowerCase()}-void-detail');
        passed('$currency UI void restores stock and removes commission once');
        // Manual stock arithmetic and rounding boundaries run on the device too.
        final adjustment = StockLocalDataSource(database: source);
        for (final type in ['manual_add', 'manual_reduce']) {
          for (var index = 0; index < 10; index++) {
            await adjustment.adjustStock(
              StockAdjustmentRequest(
                itemId: '$weighted',
                adjustmentType: type,
                quantity: 0.1,
              ),
            );
          }
        }
        expect(await stock(weighted), 0);
        for (final sign in [-1, 1]) {
          expect(
            ScaledArithmetic.moneyUnits(
              sign * 1.5 / (currency == 'IDR' ? 1 : 100),
              currency,
            ),
            sign * 2,
          );
          expect(
            ScaledArithmetic.moneyUnits(
              sign * 1.49999 / (currency == 'IDR' ? 1 : 100),
              currency,
            ),
            sign,
          );
          expect(
            ScaledArithmetic.moneyUnits(
              sign * 1.50001 / (currency == 'IDR' ? 1 : 100),
              currency,
            ),
            sign * 2,
          );
          expect(ScaledArithmetic.percentage(sign * 145, 10), sign * 15);
        }
        expect(QuantityFormatter.parse('0.1234'), isNull);
        expect(QuantityFormatter.parse('0,001'), 0.001);
        passed(
          '$currency native stock adjustments and half-away-from-zero boundaries',
        );
        // Seed a pre-fix historical row; opening it and backups must not reprice it.
        final dataSource = TransactionLocalDataSource(database: source);
        final entity = (await dataSource.getCatalogItems())
            .firstWhere((item) => item.id == service)
            .toEntity();
        final legacy = await dataSource.saveTransaction(
          TransaksiSubmitRequest(
            items: [
              TransaksiCartItem(
                item: entity,
                quantity: 0.15,
                itemDiscountAmount: 0,
              ),
            ],
            currencyCode: currency,
            orderDiscountAmount: 0,
            taxAmount: 0,
            paymentMethod: 'qris',
          ),
        );
        final oldProduct = 0.1 * factor * 0.15;
        await db.update(
          'sales_transaction_items',
          {'line_subtotal': oldProduct, 'line_total': oldProduct},
          where: 'transaction_id = (SELECT id FROM sales_transactions WHERE invoice_no = ?)',
          whereArgs: [legacy.invoiceNumber],
        );
        await db.update(
          'sales_transactions',
          {'subtotal_amount': oldProduct, 'total_amount': oldProduct},
          where: 'invoice_no = ?',
          whereArgs: [legacy.invoiceNumber],
        );
        final after = await snapshot(db);
        final backup = AppBackupService(
          database: source,
          logger: Logger('PR82'),
          backupDirectoryProvider: () async => evidence,
        );
        final backups = <String>[];
        for (final password in <String?>[
          null,
          'PR82 Synthetic backup password',
        ]) {
          final file = (await tester.runAsync(
            () => backup.createBackup(password: password),
          ))!;
          final extension = password == null ? 'plaintext' : 'encrypted';
          final name = '$currency-$extension.json';
          await File(file.filePath).copy(p.join(evidence.path, name));
          backups.add(name);
          final restore = AppRestoreService(
            database: destination,
            logger: Logger('PR82'),
          );
          final candidate = (await tester.runAsync(
            () => restore.inspectBackupFile(file.filePath, password: password),
          ))!;
          await tester.runAsync(() => restore.restoreBackup(candidate));
          expect(await snapshot(await destination.database()), after);
          passed(
            '$currency $extension backup restores old and new snapshots unchanged',
          );
        }
        await tester.pumpWidget(const SizedBox.shrink());
        container.dispose();
        await db.close();
        final sourcePath = await source.databasePath();
        source = TestDatabase(sourcePath);
        db = await source.database();
        container = ProviderContainer(
          overrides: [appDatabaseProvider.overrideWithValue(source)],
        );
        await mount();
        final context = tester.element(find.byType(Scaffold).first);
        GoRouter.of(context).go('/history/${legacy.invoiceNumber}');
        await tester.pumpAndSettle();
        final receipt = await TransactionLocalDataSource(database: source)
            .getReceiptByInvoice(legacy.invoiceNumber);
        expect(receipt!.items.single.lineSubtotal, oldProduct);
        expect(receipt.items.single.lineTotal, oldProduct);
        expect(await snapshot(db), after);
        expect(await db.rawQuery('PRAGMA integrity_check'), [
          {'integrity_check': 'ok'},
        ]);
        expect(await db.rawQuery('PRAGMA foreign_key_check'), isEmpty);
        await capture('${currency.toLowerCase()}-reopened-history');
        passed(
          '$currency reopened app displays historical snapshots without rewriting rows',
        );
        await tester.pumpWidget(const SizedBox.shrink());
        await db.close();
        await File(sourcePath)
            .copy(p.join(evidence.path, '$currency-verified.sqlite'));
        final restored = await destination.database();
        await restored.close();
        await File(await destination.databasePath())
            .copy(p.join(evidence.path, '$currency-restored.sqlite'));
        results[currency] = {
          'backups': backups,
          'transactions': after['sales_transactions']!.length,
          'stock_weighted': 0,
          'stock_partial': 0,
          'stock_cents': 17,
          'exact_total': 0.3 * factor,
          'mixed_total': mixedTotal,
          'mixed_commission': 0.03 * factor,
          'legacy_invoice': legacy.invoiceNumber,
          'legacy_line_total': oldProduct,
          'void_invoice': invoice,
          'active_expenses': 0,
          'reopen_integrity': 'ok',
        };
      } finally {
        tester.testTextInput.unregister();
        await tester.pumpWidget(const SizedBox.shrink());
        container.dispose();
        await source.reset();
        await destination.reset();
        expect(p.isWithin(cache.path, root.path), isTrue);
        await root.delete(recursive: true);
        debugPrint('PR82_CLEANUP: $currency disposable databases removed');
      }
    }
    await File(p.join(evidence.path, 'result.json')).writeAsString(
      jsonEncode({
        'revision': revision,
        'package': package,
        'status': 'passed',
        'events': events,
        'currencies': results,
        'verified_at_utc': DateTime.now().toUtc().toIso8601String(),
      }),
    );
    debugPrint('PR82_COMPLETE: ${events.length} verified scenarios');
  }, timeout: const Timeout(Duration(minutes: 20)));
}
