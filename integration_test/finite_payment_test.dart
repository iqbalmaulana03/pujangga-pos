import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:pujangga_pos/app/app.dart';
import 'package:pujangga_pos/core/database/app_database.dart';
import 'package:pujangga_pos/core/errors/app_exception.dart';
import 'package:pujangga_pos/core/services/app_startup_service.dart';
import 'package:pujangga_pos/core/utils/app_date_formatting.dart';
import 'package:pujangga_pos/features/pengaturan/data/services/app_backup_service.dart';
import 'package:pujangga_pos/features/pengaturan/data/services/app_restore_service.dart';
import 'package:pujangga_pos/features/pengaturan/data/services/backup_encryption.dart';
import 'package:pujangga_pos/features/transaksi/data/datasources/transaction_local_data_source.dart';
import 'package:pujangga_pos/features/transaksi/domain/entities/transaksi_cart_item.dart';
import 'package:pujangga_pos/features/transaksi/domain/entities/transaksi_item.dart';
import 'package:pujangga_pos/features/transaksi/domain/entities/transaksi_submit_request.dart';
import 'package:pujangga_pos/features/transaksi/presentation/controllers/transaksi_controller.dart';
import 'package:pujangga_pos/features/transaksi/presentation/models/transaksi_state.dart';
import 'package:pujangga_pos/features/transaksi/presentation/pages/transaksi_berhasil_page.dart';
import 'package:sqflite/sqflite.dart';

class _Database extends AppDatabase {
  _Database(this.file);
  final String file;
  @override
  Future<String> databasePath() async => file;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('PR80 finite cash, atomic rejection, real checkout and portable backups', (
    tester,
  ) async {
    initializeAppDateFormatting();
    final cache = await getTemporaryDirectory();
    expect(cache.path, contains('/com.pujanggapos.pujangga_pos.pr80e2e/'));
    final root = await Directory(
      path.join(cache.path, 'finite-${DateTime.now().microsecondsSinceEpoch}'),
    ).create();
    final source = _Database(path.join(root.path, 'source.sqlite'));
    final destination = _Database(path.join(root.path, 'restored.sqlite'));
    for (final database in [source, destination]) {
      expect(path.isWithin(root.path, await database.databasePath()), isTrue);
    }
    final db = await source.database();
    final actual = (await db.rawQuery('PRAGMA database_list'))
        .singleWhere((row) => row['name'] == 'main');
    expect(actual['file'], await source.databasePath());
    debugPrint('E2E_ISOLATION: ${actual['file']}');
    final restoredConnection = await destination.database();
    final restoredPath = (await restoredConnection.rawQuery(
      'PRAGMA database_list',
    )).singleWhere((row) => row['name'] == 'main');
    expect(restoredPath['file'], await destination.databasePath());
    final stamp = DateTime.now().toIso8601String();
    await db.insert('business_profile', {
      'business_name': 'PR80 Synthetic POS',
      'business_type': 'retail',
      'created_at': stamp,
      'updated_at': stamp,
    });
    await db.update('app_settings', {'default_tax_percent': 10});
    Future<int> seedItem(String type, String name) => db.insert('items', {
      'name': name,
      'item_type': type,
      'sale_price': 10000,
      'unit': 'Pcs',
      'harga_modal': type == 'product' ? 4000 : null,
      'biaya_dasar': type == 'service' ? 2000 : null,
      'stock_qty': type == 'product' ? 10 : 0,
      'created_at': stamp,
      'updated_at': stamp,
    });
    final productId = await seedItem('product', 'PR80 Kopi');
    final serviceId = await seedItem('service', 'PR80 Jasa');
    await db.insert('stock_movements', {
      'item_id': productId,
      'movement_type': 'initial',
      'qty_change': 10,
      'qty_before': 0,
      'qty_after': 10,
      'reference_type': 'item',
      'reference_id': productId,
      'created_at': stamp,
    });
    final employeeId = await db.insert('employees', {
      'name': 'PR80 Komisi',
      'is_active': 1,
      'compensation_type': 'commission',
      'commission_percent': 10,
      'effective_from': stamp,
      'created_at': stamp,
      'updated_at': stamp,
    });
    final container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(source)],
    );
    addTearDown(() async {
      container.dispose();
      await source.reset();
      await destination.reset();
      expect(path.isWithin(cache.path, root.path), isTrue);
      await root.delete(recursive: true);
      debugPrint(
        'E2E_CLEANUP: disposable source and restored databases removed',
      );
    });
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const PujanggaPosApp(),
      ),
    );
    await tester.pumpAndSettle();
    Future<void> tap(Finder finder) async {
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await tester.ensureVisible(finder);
      await tester.tap(finder);
      await tester.pumpAndSettle();
    }

    Future<void> capture(String label) async {
      debugPrint('E2E_CAPTURE: $label');
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(seconds: 3)),
      );
    }

    Future<Map<String, Object?>> snapshot(Database connection) async => {
      for (final table in AppBackupService.backupTables)
        table: await connection.query(table, orderBy: 'id'),
    };
    TransaksiState current() =>
        container.read(transaksiControllerProvider).requireValue;
    TransaksiController controller() =>
        container.read(transaksiControllerProvider.notifier);
    await tap(find.text('Transaksi').last);
    await tap(find.text('PR80 Kopi').first);
    await tap(find.text('PR80 Jasa').first);
    await tap(find.text('Keranjang'));
    await tap(find.byType(DropdownButtonFormField<int?>));
    await tap(find.textContaining('PR80 Komisi').last);
    expect(current().employeeId, employeeId);
    final cash = find.byWidgetPredicate(
      (w) => w is TextField && w.textAlign == TextAlign.right,
    );
    final submit = find.widgetWithText(FilledButton, 'Proses Pembayaran');
    final before = await snapshot(db);
    // Inject pasted strings with a registered test IME. Flutter documents that
    // injecting editing values alongside a real Android IME can desynchronize it.
    tester.testTextInput.register();
    addTearDown(tester.testTextInput.unregister);
    for (final value in [
      'Infinity',
      '-Infinity',
      'NaN',
      '1e309',
      '-1',
      '',
      '19999',
    ]) {
      await tester.ensureVisible(cash);
      await tester.enterText(cash, value);
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      expect(current().canSubmit, isFalse);
      expect(tester.widget<FilledButton>(submit).onPressed, isNull);
      await expectLater(
        controller().submit(),
        throwsA(
          isA<AppException>().having((e) => e.code, 'code', 'validation_error'),
        ),
      );
      expect(await snapshot(db), before);
      expect(tester.takeException(), isNull);
      debugPrint(
        'E2E_PASS: UI/controller rejects ${value.isEmpty ? 'empty' : value}; all rows unchanged',
      );
      if (value == 'Infinity') await capture('invalid-infinity');
    }
    final dataSource = TransactionLocalDataSource(database: source);
    TransaksiCartItem line({
      double price = 10000,
      double quantity = 1,
      double discount = 0,
      bool service = false,
    }) => TransaksiCartItem(
      item: TransaksiItem(
        id: '${service ? serviceId : productId}',
        name: 'PR80 Synthetic',
        category: '',
        itemType: service ? 'jasa' : 'barang',
        sellingPrice: price,
        isActive: true,
      ),
      quantity: quantity,
      itemDiscountAmount: discount,
    );
    TransaksiSubmitRequest request({
      double? paid = 30000,
      List<TransaksiCartItem>? items,
      double discount = 0,
      double tax = 0,
      String method = 'tunai',
    }) => TransaksiSubmitRequest(
      items: items ?? [line()],
      orderDiscountAmount: discount,
      taxAmount: tax,
      paymentMethod: method,
      cashPaidAmount: paid,
      employeeId: employeeId,
    );
    final bad = <TransaksiSubmitRequest>[
      for (final paid in <double?>[
        double.infinity,
        double.negativeInfinity,
        double.nan,
        double.parse('1e309'),
        -1,
        null,
        9999,
      ])
        request(paid: paid),
      request(paid: null, discount: 10000),
      for (final method in ['tunai', 'qris']) ...[
        request(method: method, items: [line(price: 1e308, quantity: 2)]),
        request(
          method: method,
          items: [line(price: 1e308), line(price: 1e308)],
        ),
        request(method: method, items: [line(price: 1e308)], tax: 1e308),
        request(
          method: method,
          items: [line(discount: double.nan)],
        ),
        request(method: method, discount: double.infinity),
        request(method: method, tax: double.infinity),
      ],
      request(method: 'qris', items: [line(price: 1e308, service: true)]),
    ];
    for (final invalid in bad) {
      await expectLater(
        dataSource.saveTransaction(invalid),
        throwsA(
          isA<AppException>().having((e) => e.code, 'code', 'validation_error'),
        ),
      );
      expect(await snapshot(db), before);
    }
    debugPrint(
      'E2E_PASS: ${bad.length} native SQLite rejection cases; header/detail/stock/commission unchanged',
    );
    // Exercise overflow through the live app's calculation/rounding/rendering path.
    controller().setQuantity('$productId', 1e308);
    await tester.pumpAndSettle();
    expect(current().canSubmit, isFalse);
    expect(tester.takeException(), isNull);
    expect(await snapshot(db), before);
    controller().setQuantity('$productId', 1);
    controller().updateItemDiscount('$productId', 1000);
    controller().updateOrderDiscount(1000);
    await tester.pumpAndSettle();
    expect(current().subtotalAmount, 20000);
    expect(current().taxAmount, 1800);
    expect(current().totalAmount, 19800);
    // Input, save, navigation, receipt, stock and commissions all use the real app.
    await tester.ensureVisible(cash);
    await tester.enterText(cash, '');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    tester.testTextInput.unregister();
    await tester.tap(cash);
    await tester.pumpAndSettle();
    debugPrint('E2E_ADB_INPUT: 25000');
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(seconds: 5)),
    );
    await tester.pumpAndSettle();
    debugPrint(
      'E2E_DIAGNOSTIC: paid=${current().cashPaidAmount} total=${current().totalAmount} error=${current().validationError} submitting=${current().isSubmitting}',
    );
    expect(current().cashPaidAmount, 25000);
    expect(current().canSubmit, isTrue);
    await tap(submit);
    expect(find.byType(TransaksiBerhasilPage), findsOneWidget);
    expect(tester.takeException(), isNull);
    final saved = (await db.query('sales_transactions')).single;
    expect(saved['subtotal_amount'], 20000);
    expect(saved['discount_amount'], 2000);
    expect(saved['tax_amount'], 1800);
    expect(saved['total_amount'], 19800);
    expect(saved['paid_amount'], 25000);
    expect(saved['change_amount'], 5200);
    expect(saved['commission_amount'], 1800);
    expect(await db.query('sales_transaction_items'), hasLength(2));
    expect(
      (await db.query(
        'items',
        where: 'id = ?',
        whereArgs: [productId],
      )).single['stock_qty'],
      9,
    );
    expect(
      (await db.query(
        'items',
        where: 'id = ?',
        whereArgs: [serviceId],
      )).single['stock_qty'],
      0,
    );
    expect((await db.query('expenses')).single['amount'], 1800);
    debugPrint(
      'E2E_PASS: real cash checkout receipt; total=19800 paid=25000 change=5200 stock=9 commission=1800',
    );
    await capture('normal-receipt');
    final evidence = await Directory(path.join(cache.path, 'pr80-evidence'))
        .create();
    final backup = AppBackupService(
      database: source,
      logger: Logger('PR80-E2E'),
      backupDirectoryProvider: () async => evidence,
    );
    final after = await snapshot(db);
    final backupFiles = <String>[];
    for (final password in <String?>[null, 'PR80 synthetic backup password']) {
      final file = await tester.runAsync(
        () => backup.createBackup(password: password),
      );
      expect(file, isNotNull);
      backupFiles.add(file!.fileName);
      final content = await File(file.filePath).readAsString();
      final plain = password == null
          ? content
          : await tester.runAsync(
              () => BackupEncryption.decrypt(
                jsonDecode(content) as Map<String, dynamic>,
                password,
              ),
            );
      expect((jsonDecode(plain!) as Map<String, dynamic>)['tables'], after);
      final restore = AppRestoreService(
        database: destination,
        logger: Logger('PR80-E2E'),
      );
      final candidate = await tester.runAsync(
        () => restore.inspectBackupFile(file.filePath, password: password),
      );
      await tester.runAsync(() => restore.restoreBackup(candidate!));
      expect(await snapshot(await destination.database()), after);
      debugPrint(
        'E2E_PASS: ${password == null ? 'plaintext' : 'encrypted'} backup serialized, inspected, restored and reconciled',
      );
    }
    // Native SQLite reopen proves persisted values, not only in-memory receipts.
    await tester.pumpWidget(const SizedBox.shrink());
    await db.close();
    final reopened = await openDatabase(
      await source.databasePath(),
      readOnly: true,
    );
    expect(await snapshot(reopened), after);
    expect(await reopened.rawQuery('PRAGMA integrity_check'), [
      {'integrity_check': 'ok'},
    ]);
    await reopened.close();
    await File(await source.databasePath())
        .copy(path.join(evidence.path, 'verified.sqlite'));
    await File(path.join(evidence.path, 'result.json')).writeAsString(
      jsonEncode({
        'revision': const String.fromEnvironment('E2E_SOURCE_REVISION'),
        'package': 'com.pujanggapos.pujangga_pos.pr80e2e',
        'ui_rejections': 7,
        'sqlite_rejections': bad.length,
        'normal_total': 19800,
        'paid': 25000,
        'change': 5200,
        'stock': 9,
        'commission': 1800,
        'backup_files': backupFiles,
        'reopen_integrity': 'ok',
        'status': 'passed',
      }),
    );
    debugPrint('E2E_PASS: reopen and integrity_check verified');
    debugPrint('E2E_EVIDENCE: ${evidence.path}');
  }, timeout: const Timeout(Duration(minutes: 12)));
}
