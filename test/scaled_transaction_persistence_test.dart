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

  test('combined 0.1 increments sell all 0.3 stock', () async {
    final item = await line(price: 100, quantity: 0.1 + 0.1 + 0.1);
    await sales.saveTransaction(request([item]));
    expect((await db.query('items')).single['stock_qty'], 0);
    expect((await db.query('sales_transaction_items')).single['qty'], 0.3);
  });

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
