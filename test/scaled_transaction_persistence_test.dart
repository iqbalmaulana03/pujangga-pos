import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:pujangga_pos/core/database/app_database.dart';
import 'package:pujangga_pos/core/errors/app_exception.dart';
import 'package:pujangga_pos/features/katalog/data/datasources/catalog_local_data_source.dart';
import 'package:pujangga_pos/features/katalog/domain/entities/catalog_item_draft.dart';
import 'package:pujangga_pos/features/karyawan/data/repositories/employee_repository.dart';
import 'package:pujangga_pos/features/pengaturan/data/services/app_backup_service.dart';
import 'package:pujangga_pos/features/pengaturan/data/services/app_restore_service.dart';
import 'package:pujangga_pos/features/riwayat/data/datasources/riwayat_local_data_source.dart';
import 'package:pujangga_pos/features/stok/data/datasources/stock_local_data_source.dart';
import 'package:pujangga_pos/features/stok/domain/entities/stock_adjustment_request.dart';
import 'package:pujangga_pos/features/transaksi/data/datasources/transaction_local_data_source.dart';
import 'package:pujangga_pos/features/transaksi/domain/entities/transaksi_cart_item.dart';
import 'package:pujangga_pos/features/transaksi/domain/entities/transaksi_item.dart';
import 'package:pujangga_pos/features/transaksi/domain/entities/transaksi_submit_request.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _Database extends AppDatabase {
  _Database(this.file);
  final String file;
  @override
  Future<String> databasePath() async => file;
}

void main() {
  late Directory root;
  late AppDatabase source, destination;
  late Database db;
  late TransactionLocalDataSource sales;
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });
  setUp(() async {
    root = await Directory.systemTemp.createTemp('pujangga_72_');
    source = _Database(p.join(root.path, 'source.sqlite'));
    destination = _Database(p.join(root.path, 'restored.sqlite'));
    for (final database in [source, destination]) {
      expect(p.dirname(await database.databasePath()), root.path);
    }
    db = await source.database();
    sales = TransactionLocalDataSource(database: source);
  });
  tearDown(() async {
    await source.reset();
    await destination.reset();
    await root.delete(recursive: true);
  });

  Future<TransaksiCartItem> line({
    double price = 1,
    double stock = 0.3,
    double quantity = 0.1,
    String type = 'product',
    String currency = 'IDR',
  }) async {
    final now = DateTime.now().toIso8601String();
    final id = await db.insert('items', {
      'name': 'Synthetic',
      'item_type': type,
      'sale_price': price,
      'stock_qty': stock,
      'created_at': now,
      'updated_at': now,
    });
    return TransaksiCartItem(
      item: TransaksiItem(
        id: '$id',
        name: 'Synthetic',
        category: '',
        itemType: type == 'product' ? 'barang' : 'jasa',
        sellingPrice: price,
        stockQuantity: stock,
        unitLabel: 'kg',
        isActive: true,
      ),
      quantity: quantity,
      itemDiscountAmount: 0,
      currencyCode: currency,
    );
  }

  TransaksiSubmitRequest request(
    List<TransaksiCartItem> items, {
    String currency = 'IDR',
    double? paid,
    int? employee,
    double discount = 0,
    double tax = 0,
  }) => TransaksiSubmitRequest(
    items: items,
    currencyCode: currency,
    orderDiscountAmount: discount,
    taxAmount: tax,
    paymentMethod: paid == null ? 'qris' : 'tunai',
    cashPaidAmount: paid,
    employeeId: employee,
  );

  test(
    'three fractional sales exhaust stock and repeated void restores it once',
    () async {
      final item = await line(price: 100);
      final invoices = <String>[];
      for (var i = 0; i < 3; i++) {
        invoices.add(
          (await sales.saveTransaction(request([item]))).invoiceNumber,
        );
      }
      expect((await db.query('items')).single['stock_qty'], 0);
      final history = RiwayatLocalDataSource(database: source);
      for (final invoice in invoices) {
        await history.voidTransaction(invoice);
        await history.voidTransaction(invoice);
      }
      expect((await db.query('items')).single['stock_qty'], 0.3);
      final movements = await db.query('stock_movements');
      expect(movements, hasLength(6));
      expect(movements.last['qty_after'], 0.3);
    },
  );

  for (final legacy in [
    (before: 0.3, remaining: 0.1995, quantity: 0.1005, delta: 0.1005),
    (before: 0.3001, remaining: 0.1996, quantity: 0.1005, delta: 0.1004),
  ]) {
    test(
      'restored legacy void rounds once and preserves its ledger (${legacy.remaining})',
      () async {
        final item = await line(price: 100);
        final sale = await sales.saveTransaction(request([item]));
        // A pre-fix sale could persist finer quantities than today's UI accepts.
        final amount = 100 * legacy.quantity;
        await db.update('items', {'stock_qty': legacy.remaining});
        await db.update('sales_transaction_items', {
          'qty': legacy.quantity,
          'line_subtotal': amount,
          'line_total': amount,
        });
        await db.update('sales_transactions', {
          'subtotal_amount': amount,
          'total_amount': amount,
        });
        await db.update('stock_movements', {
          'qty_before': legacy.before,
          'qty_change': -legacy.quantity,
          'qty_after': legacy.remaining,
        });
        final details = await db.query('sales_transaction_items');
        final export = await AppBackupService(
          database: source,
          logger: Logger('legacy-72'),
          backupDirectoryProvider: () async => root,
        ).createBackup(password: null);
        final restore = AppRestoreService(
          database: destination,
          logger: Logger('legacy-72'),
        );
        await restore.restoreBackup(
          await restore.inspectBackupFile(export.filePath),
        );
        final restored = await destination.database();
        final history = RiwayatLocalDataSource(database: destination);
        await history.voidTransaction(sale.invoiceNumber);
        expect((await restored.query('items')).single['stock_qty'], 0.3);
        expect(await restored.query('sales_transaction_items'), details);
        final movements = await restored.query(
          'stock_movements',
          orderBy: 'id',
        );
        expect(movements.last['qty_before'], legacy.remaining);
        expect(movements.last['qty_change'], legacy.delta);
        expect(movements.last['qty_after'], 0.3);
        await history.voidTransaction(sale.invoiceNumber);
        expect(
          await restored.query('stock_movements', orderBy: 'id'),
          movements,
        );
        final secondExport = await AppBackupService(
          database: destination,
          logger: Logger('legacy-72'),
          backupDirectoryProvider: () async => root,
        ).createBackup(password: null);
        final back = AppRestoreService(
          database: source,
          logger: Logger('legacy-72'),
        );
        await back.restoreBackup(
          await back.inspectBackupFile(secondExport.filePath),
        );
        expect((await db.query('items')).single['stock_qty'], 0.3);
        expect(await db.query('stock_movements', orderBy: 'id'), movements);
        expect(await db.query('sales_transaction_items'), details);
      },
    );
  }

  for (final operation in [
    (type: 'catalog', quantity: 0.2, after: 0.2, delta: 0.0005),
    (type: 'catalog', quantity: 0.3, after: 0.3, delta: 0.1005),
    (type: 'sale', quantity: 0.1, after: 0.1, delta: -0.0995),
    (type: 'manual_add', quantity: 0.1, after: 0.3, delta: 0.1005),
    (type: 'manual_reduce', quantity: 0.1, after: 0.1, delta: -0.0995),
    (type: 'set_balance', quantity: 0.2, after: 0.2, delta: 0.0005),
  ]) {
    test('restored legacy ledger stays continuous: $operation', () async {
      final item = await line(price: 100, stock: 0.1995);
      final originalMovement = {
        'item_id': int.parse(item.item.id),
        'movement_type': 'stock_in',
        'qty_before': 0,
        'qty_change': 0.1995,
        'qty_after': 0.1995,
        'reference_type': 'initial_stock',
        'created_at': DateTime.now().toIso8601String(),
      };
      await db.insert('stock_movements', originalMovement);
      final backup = await AppBackupService(
        database: source,
        logger: Logger('legacy-ledger'),
        backupDirectoryProvider: () async => root,
      ).createBackup(password: null);
      final restore = AppRestoreService(
        database: destination,
        logger: Logger('legacy-ledger'),
      );
      await restore.restoreBackup(
        await restore.inspectBackupFile(backup.filePath),
      );
      final restored = await destination.database();
      final before = await restored.query('stock_movements', orderBy: 'id');
      if (operation.type == 'catalog') {
        await CatalogLocalDataSource(database: destination).updateItem(
          item.item.id,
          CatalogItemDraft(
            name: 'Synthetic',
            category: 'Synthetic',
            itemType: 'barang',
            sellingPrice: 100,
            isActive: true,
            stockQuantity: operation.quantity,
            unitLabel: 'kg',
          ),
        );
      } else if (operation.type == 'sale') {
        await TransactionLocalDataSource(database: destination).saveTransaction(
          request([item.copyWith(quantity: operation.quantity)]),
        );
      } else {
        await StockLocalDataSource(database: destination).adjustStock(
          StockAdjustmentRequest(
            itemId: item.item.id,
            adjustmentType: operation.type,
            quantity: operation.quantity,
          ),
        );
      }
      final movements = await restored.query('stock_movements', orderBy: 'id');
      expect(movements, hasLength(2));
      expect(movements.first, before.single);
      expect(movements.last['qty_before'], 0.1995);
      expect(movements.last['qty_change'], operation.delta);
      expect(movements.last['qty_after'], operation.after);
      expect(
        (await restored.query('items')).single['stock_qty'],
        operation.after,
      );
      final exported = await AppBackupService(
        database: destination,
        logger: Logger('legacy-ledger'),
        backupDirectoryProvider: () async => root,
      ).createBackup(password: null);
      final back = AppRestoreService(
        database: source,
        logger: Logger('legacy-ledger'),
      );
      await back.restoreBackup(await back.inspectBackupFile(exported.filePath));
      expect(await db.query('stock_movements', orderBy: 'id'), movements);
      expect((await db.query('items')).single['stock_qty'], operation.after);
    });
  }

  test(
    'legacy fractional stock cannot be rounded up to cover an overdraw',
    () async {
      final item = await line(price: 100, stock: 0.0005, quantity: 0.001);
      await expectLater(
        sales.saveTransaction(request([item])),
        throwsA(isA<AppException>()),
      );
      await expectLater(
        StockLocalDataSource(database: source).adjustStock(
          StockAdjustmentRequest(
            itemId: item.item.id,
            adjustmentType: 'manual_reduce',
            quantity: 0.001,
          ),
        ),
        throwsA(isA<AppException>()),
      );
      expect((await db.query('items')).single['stock_qty'], 0.0005);
      expect(await db.query('stock_movements'), isEmpty);
      expect(await db.query('sales_transactions'), isEmpty);
    },
  );

  test('combined 0.1 increments sell all 0.3 stock', () async {
    final item = await line(price: 100, quantity: 0.1 + 0.1 + 0.1);
    await sales.saveTransaction(request([item]));
    expect((await db.query('items')).single['stock_qty'], 0);
    expect((await db.query('sales_transaction_items')).single['qty'], 0.3);
  });

  test(
    'checkout reads the latest setting and rolls back a partial sale',
    () async {
      final first = await line(price: 100, stock: 1, quantity: 1);
      final second = await line(price: 100, stock: 0, quantity: 1);
      final service = await line(type: 'service', stock: 0);
      final checkout = request([first, second, service]);
      final items = await db.query('items', orderBy: 'id');

      for (final missingSetting in [false, true]) {
        if (missingSetting) await db.delete('app_settings');
        await expectLater(
          sales.saveTransaction(checkout),
          throwsA(
            isA<AppException>().having(
              (e) => e.code,
              'code',
              'insufficient_stock',
            ),
          ),
        );
        expect(await db.query('items', orderBy: 'id'), items);
        for (final table in [
          'stock_movements',
          'sales_transactions',
          'sales_transaction_items',
          'expenses',
        ]) {
          expect(await db.query(table), isEmpty, reason: table);
        }
      }

      final now = DateTime.now().toIso8601String();
      await db.insert('app_settings', {
        'stock_allow_negative': 1,
        'created_at': now,
        'updated_at': now,
      });
      final receipt = await sales.saveTransaction(checkout);
      await db.update('app_settings', {'stock_allow_negative': 0});
      final retry = await sales.saveTransaction(checkout);
      expect(retry.invoiceNumber, receipt.invoiceNumber);
      expect(await db.query('sales_transactions'), hasLength(1));
      expect(
        (await db.query('items', orderBy: 'id')).map((row) => row['stock_qty']),
        [0, -1, 0],
      );
      final movements = await db.query('stock_movements', orderBy: 'id');
      expect(movements, hasLength(2));
      expect(movements.last, containsPair('qty_before', 0));
      expect(movements.last, containsPair('qty_change', -1));
      expect(movements.last, containsPair('qty_after', -1));
    },
  );

  test('adjustments apply the policy to the resulting balance', () async {
    final item = await line(stock: 0);
    final stock = StockLocalDataSource(database: source);
    StockAdjustmentRequest adjustment(String type, double quantity) =>
        StockAdjustmentRequest(
          itemId: item.item.id,
          adjustmentType: type,
          quantity: quantity,
        );
    final reduce = adjustment('manual_reduce', 0.1);
    final set = adjustment('set_balance', -0.3);
    final rejected = throwsA(
      isA<AppException>().having((e) => e.code, 'code', 'validation_error'),
    );

    await expectLater(stock.adjustStock(reduce), rejected);
    await expectLater(stock.adjustStock(set), rejected);
    expect((await db.query('items')).single['stock_qty'], 0);
    expect(await db.query('stock_movements'), isEmpty);

    await db.update('app_settings', {'stock_allow_negative': 1});
    await stock.adjustStock(reduce);
    await stock.adjustStock(set);
    for (final type in ['manual_add', 'manual_reduce']) {
      await expectLater(stock.adjustStock(adjustment(type, -0.1)), rejected);
    }

    await db.update('app_settings', {'stock_allow_negative': 0});
    await expectLater(
      stock.adjustStock(adjustment('manual_add', 0.1)),
      rejected,
    );
    await stock.adjustStock(adjustment('manual_add', 0.3));
    expect((await db.query('items')).single['stock_qty'], 0);

    final movements = await db.query('stock_movements', orderBy: 'id');
    expect(
      movements.map(
        (row) => [row['qty_before'], row['qty_change'], row['qty_after']],
      ),
      [
        [0, -0.1, -0.1],
        [-0.1, -0.2, -0.3],
        [-0.3, 0.3, 0],
      ],
    );
  });

  test(
    'catalog edits preserve the latest balance unless explicitly changed',
    () async {
      final item = await line(stock: 0);
      final catalog = CatalogLocalDataSource(database: source);
      CatalogItemDraft draft(double stock, {bool preserveStock = false}) =>
          CatalogItemDraft(
            name: 'Renamed',
            category: 'Synthetic',
            itemType: 'barang',
            sellingPrice: 100,
            isActive: true,
            stockQuantity: stock,
            preserveStock: preserveStock,
          );
      final id = item.item.id;
      final rejected = throwsA(isA<AppException>());

      await expectLater(catalog.updateItem(id, draft(-0.2)), rejected);
      expect(await db.query('categories'), isEmpty);
      await db.update('app_settings', {'stock_allow_negative': 1});
      await expectLater(catalog.createItem(draft(-1)), rejected);
      await catalog.updateItem(id, draft(-0.2));
      final movements = await db.query('stock_movements');
      expect(movements.single, containsPair('qty_before', 0));
      expect(movements.single, containsPair('qty_change', -0.2));
      expect(movements.single, containsPair('qty_after', -0.2));

      await db.update('app_settings', {'stock_allow_negative': 0});
      await catalog.updateItem(id, draft(0, preserveStock: true));
      await expectLater(catalog.updateItem(id, draft(-0.1)), rejected);
      expect((await db.query('items')).single, containsPair('name', 'Renamed'));
      expect((await db.query('items')).single, containsPair('stock_qty', -0.2));
      expect(await db.query('stock_movements'), movements);
    },
  );

  test(
    'void and backup round trip retain a deficit after the option is disabled',
    () async {
      final item = await line(price: 100, stock: 0, quantity: 0.1);
      await db.update('app_settings', {'stock_allow_negative': 1});
      final first = await sales.saveTransaction(request([item]));
      await sales.saveTransaction(request([item.copyWith(quantity: 0.2)]));
      await db.update('app_settings', {'stock_allow_negative': 0});

      final history = RiwayatLocalDataSource(database: source);
      await history.voidTransaction(first.invoiceNumber);
      await history.voidTransaction(first.invoiceNumber);

      final movements = await db.query('stock_movements', orderBy: 'id');
      expect(movements, hasLength(3));
      expect(movements.last, containsPair('movement_type', 'void'));
      expect(movements.last, containsPair('qty_before', -0.3));
      expect(movements.last, containsPair('qty_change', 0.1));
      expect(movements.last, containsPair('qty_after', -0.2));
      expect((await db.query('items')).single['stock_qty'], -0.2);

      final backup = await AppBackupService(
        database: source,
        logger: Logger('negative-stock-test'),
        backupDirectoryProvider: () async => root,
      ).createBackup(password: null);
      final restore = AppRestoreService(
        database: destination,
        logger: Logger('negative-stock-test'),
      );
      await restore.restoreBackup(
        await restore.inspectBackupFile(backup.filePath),
      );
      final restored = await destination.database();
      for (final table in [
        'app_settings',
        'items',
        'stock_movements',
        'sales_transactions',
        'sales_transaction_items',
      ]) {
        expect(
          await restored.query(table, orderBy: 'id'),
          await db.query(table, orderBy: 'id'),
          reason: table,
        );
      }
      expect(await restored.rawQuery('PRAGMA foreign_key_check'), isEmpty);
    },
  );

  for (final currency in ['USD', 'SGD']) {
    test(
      '$currency exact payment, retry, snapshots and insufficient payment',
      () async {
        await db.update('app_settings', {'currency_code': currency});
        final item = await line(
          price: 0.1,
          stock: 10,
          quantity: 3,
          currency: currency,
        );
        final checkout = request([item], currency: currency, paid: 0.3);
        final receipt = await sales.saveTransaction(checkout);
        expect(receipt.totalAmount, 0.3);
        expect(receipt.changeAmount, 0);
        final file = await source.databasePath();
        await db.close();
        source = _Database(file);
        expect(p.dirname(await source.databasePath()), root.path);
        db = await source.database();
        sales = TransactionLocalDataSource(database: source);
        expect(
          (await sales.saveTransaction(checkout)).invoiceNumber,
          receipt.invoiceNumber,
        );
        final reloaded = (await sales.getReceiptByInvoice(
          receipt.invoiceNumber,
        ))!;
        expect(reloaded.items.single.lineSubtotal, 0.3);
        expect(reloaded.items.single.lineTotal, 0.3);
        expect(await db.query('sales_transactions'), hasLength(1));
        expect((await db.query('items')).single['stock_qty'], 7);
        await expectLater(
          sales.saveTransaction(
            request([item], currency: currency, paid: 0.29),
          ),
          throwsA(isA<AppException>()),
        );
        expect(await db.query('sales_transactions'), hasLength(1));
        expect((await db.query('items')).single['stock_qty'], 7);
      },
    );
  }

  test(
    'manual stock changes preserve thousandths and reject overdraw',
    () async {
      final item = await line(stock: 1);
      final stock = StockLocalDataSource(database: source);
      for (var i = 0; i < 10; i++) {
        await stock.adjustStock(
          StockAdjustmentRequest(
            itemId: item.item.id,
            adjustmentType: 'manual_reduce',
            quantity: 0.1,
          ),
        );
      }
      expect((await db.query('items')).single['stock_qty'], 0);
      await expectLater(
        stock.adjustStock(
          StockAdjustmentRequest(
            itemId: item.item.id,
            adjustmentType: 'manual_reduce',
            quantity: 0.001,
          ),
        ),
        throwsA(isA<AppException>()),
      );
      await stock.adjustStock(
        StockAdjustmentRequest(
          itemId: item.item.id,
          adjustmentType: 'set_balance',
          quantity: 0.2,
        ),
      );
      await stock.adjustStock(
        StockAdjustmentRequest(
          itemId: item.item.id,
          adjustmentType: 'manual_add',
          quantity: 0.1,
        ),
      );
      expect((await db.query('items')).single['stock_qty'], 0.3);
    },
  );

  test(
    'commission allocation rounds only final result and matches expense',
    () async {
      await db.update('app_settings', {'currency_code': 'USD'});
      final employees = EmployeeRepository(database: source);
      await employees.save(
        name: 'Synthetic Employee',
        isActive: true,
        compensationType: 'commission',
        commissionPercent: 10,
        commissionScope: 'service',
        effectiveFrom: DateTime.now(),
      );
      final id = (await employees.getEmployees()).single.id;
      final product = await line(
        price: 0.1,
        quantity: 3,
        stock: 3,
        currency: 'USD',
      );
      final service = await line(
        price: 0.1,
        quantity: 3,
        type: 'service',
        currency: 'USD',
      );
      final receipt = await sales.saveTransaction(
        request(
          [product, service],
          currency: 'USD',
          employee: id,
          discount: 0.1,
          tax: 0.05,
          paid: 0.55,
        ),
      );
      // 0.30 * (0.50 / 0.60) * 10% = 0.025 -> 0.03.
      expect(receipt.commissionAmount, 0.03);
      expect(receipt.totalAmount, 0.55);
      expect(receipt.changeAmount, 0);
      expect((await db.query('expenses')).single['amount'], 0.03);
      await RiwayatLocalDataSource(database: source)
          .voidTransaction(receipt.invoiceNumber);
      expect(await db.query('expenses'), isEmpty);
      expect(
        (await db.query(
          'items',
          where: 'id = ?',
          whereArgs: [int.parse(product.item.id)],
        )).single['stock_qty'],
        3,
      );
    },
  );

  test(
    'invalid decimals, nonfinite and unsafe amounts leave no effects',
    () async {
      final item = await line(price: 100);
      for (final quantity in [0.0001, 0.1234, double.nan, double.infinity]) {
        await expectLater(
          sales.saveTransaction(request([item.copyWith(quantity: quantity)])),
          throwsA(isA<AppException>()),
        );
      }
      for (final value in [double.nan, double.infinity, 1e100]) {
        await expectLater(
          sales.saveTransaction(request([item], paid: value)),
          throwsA(isA<AppException>()),
        );
      }
      expect(await db.query('sales_transactions'), isEmpty);
      expect(await db.query('stock_movements'), isEmpty);
      expect((await db.query('items')).single['stock_qty'], 0.3);
    },
  );

  test('catalog stock edit records a normalized delta', () async {
    final catalog = CatalogLocalDataSource(database: source);
    CatalogItemDraft draft(double stock) => CatalogItemDraft(
      name: 'Synthetic',
      category: 'Synthetic',
      itemType: 'barang',
      sellingPrice: 100,
      isActive: true,
      stockQuantity: stock,
      unitLabel: 'kg',
    );
    await catalog.createItem(draft(0.1));
    final id = '${(await db.query('items')).single['id']}';
    await catalog.updateItem(id, draft(0.1 + 0.1 + 0.1));
    final movements = await db.query('stock_movements', orderBy: 'id');
    expect(movements.last['qty_before'], 0.1);
    expect(movements.last['qty_change'], 0.2);
    expect(movements.last['qty_after'], 0.3);
    await expectLater(
      catalog.updateItem(id, draft(0.1234)),
      throwsFormatException,
    );
    expect((await db.query('items')).single['stock_qty'], 0.3);
  });

  test(
    'request snapshot overrides cannot change a new checkout total',
    () async {
      final item = await line(price: 100, quantity: 0.1);
      final fake = TransaksiCartItem(
        item: item.item,
        quantity: 0.1,
        itemDiscountAmount: 0,
        savedLineSubtotal: 999,
        savedLineTotal: 999,
      );
      final receipt = await sales.saveTransaction(request([fake]));
      expect(receipt.totalAmount, 10);
      expect(
        (await db.query('sales_transaction_items')).single['line_total'],
        10,
      );
    },
  );

  test(
    'mixed legacy and rounded rows survive backup restore unchanged',
    () async {
      await db.update('app_settings', {'currency_code': 'USD'});
      final legacy = await line(
        price: 0.03,
        quantity: 0.5,
        type: 'service',
        currency: 'USD',
      );
      final older = await sales.saveTransaction(
        request([legacy], currency: 'USD'),
      );
      // Represent an existing pre-fix row with an unrounded product.
      await db.update('sales_transaction_items', {
        'line_subtotal': 0.015,
        'line_total': 0.015,
      });
      await db.update('sales_transactions', {
        'subtotal_amount': 0.015,
        'total_amount': 0.015,
      });
      final newer = await sales.saveTransaction(
        request([legacy], currency: 'USD', paid: 0.02),
      );
      expect(newer.totalAmount, 0.02);
      final oldReceipt = (await sales.getReceiptByInvoice(
        older.invoiceNumber,
      ))!;
      expect(oldReceipt.items.single.lineTotal, 0.015);
      // Settings changes cannot reinterpret historical line snapshots.
      await db.update('app_settings', {'currency_code': 'IDR'});
      final rowsBefore = await db.query(
        'sales_transaction_items',
        orderBy: 'id',
      );
      final headersBefore = await db.query('sales_transactions', orderBy: 'id');
      final file = await AppBackupService(
        database: source,
        logger: Logger('72'),
        backupDirectoryProvider: () async => root,
      ).createBackup(password: null);
      final restore = AppRestoreService(
        database: destination,
        logger: Logger('72'),
      );
      final candidate = await restore.inspectBackupFile(file.filePath);
      await restore.restoreBackup(candidate);
      final restored = await destination.database();
      expect(
        await restored.query('sales_transaction_items', orderBy: 'id'),
        rowsBefore,
      );
      expect(
        await restored.query('sales_transactions', orderBy: 'id'),
        headersBefore,
      );
      final read = await TransactionLocalDataSource(database: destination)
          .getReceiptByInvoice(older.invoiceNumber);
      expect(read!.items.single.lineTotal, 0.015);
      expect(await restored.rawQuery('PRAGMA foreign_key_check'), isEmpty);
      final corruptLine = candidate.tables['sales_transaction_items']!.last;
      corruptLine['line_subtotal'] = 0.024;
      corruptLine['line_total'] = 0.024;
      final corruptHeader = candidate.tables['sales_transactions']!.last;
      corruptHeader['subtotal_amount'] = 0.024;
      corruptHeader['total_amount'] = 0.024;
      corruptHeader['paid_amount'] = 0.024;
      await expectLater(
        restore.restoreBackup(candidate),
        throwsA(isA<AppException>()),
      );
      expect(
        await restored.query('sales_transactions', orderBy: 'id'),
        headersBefore,
      );
    },
  );
}
