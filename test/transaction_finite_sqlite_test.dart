import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as path;
import 'package:pujangga_pos/core/database/app_database.dart';
import 'package:pujangga_pos/core/errors/app_exception.dart';
import 'package:pujangga_pos/features/pengaturan/data/services/app_backup_service.dart';
import 'package:pujangga_pos/features/pengaturan/data/services/backup_encryption.dart';
import 'package:pujangga_pos/features/transaksi/data/datasources/transaction_local_data_source.dart';
import 'package:pujangga_pos/features/transaksi/domain/entities/transaksi_cart_item.dart';
import 'package:pujangga_pos/features/transaksi/domain/entities/transaksi_item.dart';
import 'package:pujangga_pos/features/transaksi/domain/entities/transaksi_submit_request.dart';
import 'package:pujangga_pos/features/transaksi/presentation/models/transaksi_state.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _TestDatabase extends AppDatabase {
  _TestDatabase(this.filePath);
  final String filePath;
  @override
  Future<String> databasePath() async => filePath;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory temporary;
  late AppDatabase database;
  late Database db;
  late TransactionLocalDataSource source;
  late int productId;
  late int serviceId;
  late int employeeId;
  final invalid = isA<AppException>().having(
    (e) => e.code,
    'code',
    'validation_error',
  );

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });
  setUp(() async {
    temporary = await Directory.systemTemp.createTemp('pujangga_issue70_');
    database = _TestDatabase(path.join(temporary.path, 'checkout.sqlite'));
    expect(path.dirname(await database.databasePath()), temporary.path);
    db = await database.database();
    // Verify SQLite's actual open file before seeding or executing sales.
    final main = (await db.rawQuery('PRAGMA database_list'))
        .singleWhere((r) => r['name'] == 'main');
    expect(
      path.equals(main['file'] as String, await database.databasePath()),
      isTrue,
    );
    final now = DateTime(2026).toIso8601String();
    Future<int> item(String type) => db.insert('items', {
      'name': 'Sintetis $type',
      'item_type': type,
      'sale_price': 10000,
      'stock_qty': 10,
      'harga_modal': 1000,
      'biaya_dasar': 1000,
      'created_at': now,
      'updated_at': now,
    });
    productId = await item('product');
    serviceId = await item('service');
    employeeId = await db.insert('employees', {
      'name': 'Sintetis',
      'is_active': 1,
      'compensation_type': 'commission',
      'commission_percent': 10,
      'effective_from': now,
      'created_at': now,
      'updated_at': now,
    });
    source = TransactionLocalDataSource(database: database);
  });
  tearDown(() async {
    await database.reset();
    await temporary.delete(recursive: true);
  });

  TransaksiCartItem line({
    double price = 10000,
    double quantity = 1,
    double discount = 0,
    bool service = false,
  }) => TransaksiCartItem(
    item: TransaksiItem(
      id: '${service ? serviceId : productId}',
      name: 'Sintetis',
      category: 'Sintetis',
      itemType: service ? 'jasa' : 'barang',
      sellingPrice: price,
      isActive: true,
    ),
    quantity: quantity,
    itemDiscountAmount: discount,
  );
  TransaksiSubmitRequest request({
    double? paid = 20000,
    List<TransaksiCartItem>? items,
    double discount = 0,
    double tax = 0,
    String method = 'tunai',
    String? checkoutId,
  }) => TransaksiSubmitRequest(
    items: items ?? [line()],
    orderDiscountAmount: discount,
    taxAmount: tax,
    paymentMethod: method,
    cashPaidAmount: paid,
    employeeId: employeeId,
    checkoutId: checkoutId,
  );
  Future<Map<String, Object?>> snapshot() async => {
    for (final table in AppBackupService.backupTables)
      table: await db.query(table, orderBy: 'id'),
  };

  for (final paid in <double?>[
    double.infinity,
    double.negativeInfinity,
    double.nan,
    double.parse('1e309'),
    -1,
    null,
    9999,
  ]) {
    test('reject cash $paid without changing any persisted rows', () async {
      final before = await snapshot();
      await expectLater(
        source.saveTransaction(request(paid: paid)),
        throwsA(invalid),
      );
      expect(await snapshot(), before);
    });
  }

  test(
    'reject malformed and overflowing calculations for every payment route',
    () async {
      for (final method in ['tunai', 'qris', 'transfer', 'ewallet', 'kartu']) {
        final cases = [
          request(method: method, items: []),
          request(
            method: method,
            items: [line(price: double.infinity)],
          ),
          request(method: method, items: [line(price: -1)]),
          request(
            method: method,
            items: [line(quantity: double.nan)],
          ),
          request(method: method, items: [line(quantity: 0)]),
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
          request(method: method, items: [line(discount: 10001)]),
          request(method: method, discount: double.infinity),
          request(method: method, discount: -1),
          request(method: method, tax: double.nan),
          request(method: method, tax: -1),
        ];
        final before = await snapshot();
        for (final sale in cases) {
          expect(
            TransaksiState(
              cartItems: sale.items,
              paymentMethod: method,
              cashPaidAmount: sale.cashPaidAmount,
              orderDiscountAmount: sale.orderDiscountAmount,
              taxAmount: sale.taxAmount,
            ).canSubmit,
            isFalse,
          );
          await expectLater(source.saveTransaction(sale), throwsA(invalid));
          expect(await snapshot(), before);
        }
      }
    },
  );

  test('commission arithmetic overflow is rejected before writes', () async {
    final before = await snapshot();
    // The sale itself is finite, but multiplying its commission base by 10 overflows.
    await expectLater(
      source.saveTransaction(
        request(method: 'qris', items: [line(price: 1e308, service: true)]),
      ),
      throwsA(invalid),
    );
    expect(await snapshot(), before);
  });

  test(
    'zero total requires explicit cash zero; exact and excess cash work',
    () async {
      await expectLater(
        source.saveTransaction(request(paid: null, discount: 10000)),
        throwsA(invalid),
      );
      final zero = await source.saveTransaction(
        request(paid: 0, discount: 10000),
      );
      expect(zero.totalAmount, 0);
      expect(zero.changeAmount, 0);
      final exact = await source.saveTransaction(request(paid: 10000));
      expect(exact.changeAmount, 0);
      final over = await source.saveTransaction(request(paid: 15000));
      expect(over.changeAmount, 5000);
    },
  );

  test('noncash discards extraneous nonfinite paid amount', () async {
    final receipt = await source.saveTransaction(
      request(method: 'qris', paid: double.infinity),
    );
    expect(receipt.cashPaidAmount, isNull);
    final header = (await db.query('sales_transactions')).single;
    expect(header['paid_amount'], 0);
    expect(header['change_amount'], 0);
  });

  test('normal mixed sale, retry, plaintext and encrypted backup remain consistent', () async {
    final sale = request(
      items: [line(discount: 1000), line(service: true)],
      discount: 1000,
      tax: 2000,
      paid: 25000,
    );
    final receipt = await source.saveTransaction(sale);
    expect(receipt.totalAmount, 20000);
    expect(receipt.changeAmount, 5000);
    expect(receipt.commissionAmount, 1800);
    final before = await snapshot();
    final retry = await source.saveTransaction(
      request(checkoutId: sale.checkoutId, paid: double.nan),
    );
    expect(retry.invoiceNumber, receipt.invoiceNumber);
    expect(await snapshot(), before);
    expect(
      (await db.query(
        'items',
        where: 'id = ?',
        whereArgs: [productId],
      )).single['stock_qty'],
      9,
    );
    expect((await db.query('expenses')).single['amount'], 1800);
    final backup = AppBackupService(
      database: database,
      logger: Logger('issue70'),
      backupDirectoryProvider: () async => temporary,
    );
    for (final password in <String?>[null, 'Sintetis-70-password']) {
      final file = await backup.createBackup(password: password);
      final content = await File(file.filePath).readAsString();
      final plaintext = password == null
          ? content
          : await BackupEncryption.decrypt(
              jsonDecode(content) as Map<String, dynamic>,
              password,
            );
      final payload = jsonDecode(plaintext) as Map<String, dynamic>;
      final tables = payload['tables'] as Map<String, dynamic>;
      expect(tables['sales_transactions'], before['sales_transactions']);
      expect(
        tables['sales_transaction_items'],
        before['sales_transaction_items'],
      );
      expect(tables['expenses'], before['expenses']);
    }
  });
}
