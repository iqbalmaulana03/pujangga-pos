import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as path;
import 'package:pujangga_pos/core/database/app_database.dart';
import 'package:pujangga_pos/features/pengaturan/data/services/app_backup_service.dart';
import 'package:pujangga_pos/features/pengaturan/data/services/app_restore_service.dart';
import 'package:pujangga_pos/features/transaksi/data/datasources/transaction_local_data_source.dart';
import 'package:pujangga_pos/features/transaksi/domain/entities/transaksi_cart_item.dart';
import 'package:pujangga_pos/features/transaksi/domain/entities/transaksi_item.dart';
import 'package:pujangga_pos/features/transaksi/domain/entities/transaksi_submit_request.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Directory temporary;
  late AppDatabase source;
  late AppDatabase destination;
  late Database db;
  late int itemId;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    temporary = await Directory.systemTemp.createTemp('pujangga_backup_47_');
    source = _PathDatabase(path.join(temporary.path, 'source.sqlite'));
    destination = _PathDatabase(path.join(temporary.path, 'restored.sqlite'));
    // Both effective paths are explicitly inside this test's disposable folder.
    for (final database in [source, destination]) {
      expect(path.dirname(await database.databasePath()), temporary.path);
    }
    db = await source.database();
    final now = DateTime.now().toIso8601String();
    itemId = await db.insert('items', {
      'name': 'Barang sintetis',
      'item_type': 'product',
      'sale_price': 10000,
      'stock_qty': 10,
      'created_at': now,
      'updated_at': now,
    });
    await db.insert('stock_movements', {
      'item_id': itemId,
      'movement_type': 'initial',
      'qty_change': 10,
      'qty_before': 0,
      'qty_after': 10,
      'reference_type': 'item',
      'reference_id': itemId,
      'created_at': now,
    });
  });

  tearDown(() async {
    await source.reset();
    await destination.reset();
    await temporary.delete(recursive: true);
  });

  Future<void> verifyRestored(String filePath, {required bool sold}) async {
    final restore = AppRestoreService(
      database: destination,
      logger: Logger('backup-test'),
    );
    final candidate = await restore.inspectBackupFile(filePath);
    await restore.restoreBackup(candidate);
    final restored = await destination.database();
    final stock = (await restored.query('items')).single['stock_qty'];
    final movements = await restored.query('stock_movements', orderBy: 'id');
    expect(stock, sold ? 9 : 10);
    expect(stock, movements.last['qty_after']);
    expect(
      stock,
      movements.fold<num>(0, (sum, row) => sum + (row['qty_change'] as num)),
    );
    final headers = await restored.query('sales_transactions');
    final lines = await restored.query('sales_transaction_items');
    expect(headers, hasLength(sold ? 1 : 0));
    expect(lines, hasLength(sold ? 1 : 0));
    if (sold) {
      expect(lines.single['transaction_id'], headers.single['id']);
      expect(lines.single['qty'], 1);
      expect(movements.last['reference_id'], headers.single['id']);
    }
    expect(await restored.rawQuery('PRAGMA foreign_key_check'), isEmpty);
  }

  test('concurrent sale cannot split the backup snapshot; both states restore', () async {
    final itemsRead = Completer<void>();
    final resumeReads = Completer<void>();
    final saleRequested = Completer<void>();
    var transactionFinished = false;
    var fileNumber = 0;
    final observed = _ObservedDatabase(
      db,
      afterQuery: (table) async {
        if (table == 'items') {
          itemsRead.complete();
          await resumeReads.future;
        }
      },
      onTransactionFinished: () => transactionFinished = true,
    );
    final service = AppBackupService(
      database: _FixedDatabase(observed),
      logger: Logger('backup-test'),
      backupDirectoryProvider: () async {
        // A database operation here would deadlock if file work ran in txn.
        await db.query('items');
        return Directory(path.join(temporary.path, 'backup-${fileNumber++}'));
      },
    );
    final backup = service.createBackup();
    await itemsRead.future;
    final writer = _ObservedDatabase(
      db,
      onTransactionRequested: () => saleRequested.complete(),
    );
    final sale = TransactionLocalDataSource(database: _FixedDatabase(writer))
        .saveTransaction(
          TransaksiSubmitRequest(
            items: [
              TransaksiCartItem(
                item: TransaksiItem(
                  id: '$itemId',
                  name: 'Barang sintetis',
                  category: '',
                  itemType: 'barang',
                  sellingPrice: 10000,
                  isActive: true,
                  stockQuantity: 10,
                ),
                quantity: 1,
                itemDiscountAmount: 0,
              ),
            ],
            orderDiscountAmount: 0,
            taxAmount: 0,
            paymentMethod: 'tunai',
            cashPaidAmount: 10000,
          ),
        );
    // The write has reached SQLite's transaction queue while backup is paused.
    // No timer or scheduler-dependent sleep is used to arrange this interleave.
    await saleRequested.future;
    resumeReads.complete();
    final before = await backup;
    await sale;
    expect((await db.query('items')).single['stock_qty'], 9);
    await verifyRestored(before.filePath, sold: false);
    expect(transactionFinished, isTrue);

    final after = await AppBackupService(
      database: source,
      logger: Logger('backup-test'),
      backupDirectoryProvider: () async =>
          Directory(path.join(temporary.path, 'after-sale')),
    ).createBackup();
    await verifyRestored(after.filePath, sold: true);
  });

  test(
    'failed table read propagates without exporting a successful file',
    () async {
      var directoryRequested = false;
      final records = <LogRecord>[];
      final subscription = Logger.root.onRecord.listen(records.add);
      addTearDown(subscription.cancel);
      final failure = StateError('synthetic read failure');
      final observed = _ObservedDatabase(
        db,
        afterQuery: (table) async {
          if (table == 'sales_transaction_items') throw failure;
        },
      );
      final service = AppBackupService(
        database: _FixedDatabase(observed),
        logger: Logger('backup-test'),
        backupDirectoryProvider: () async {
          directoryRequested = true;
          return Directory(path.join(temporary.path, 'failed-backup'));
        },
      );
      await expectLater(service.createBackup(), throwsA(same(failure)));
      expect(directoryRequested, isFalse);
      expect(
        await temporary.list().where((f) => f.path.endsWith('.json')).toList(),
        isEmpty,
      );
      expect(
        records.where((r) => r.message.startsWith('Backup exported')),
        isEmpty,
      );
      // The failed transaction releases the connection for subsequent work.
      await db.transaction((txn) => txn.query('items'));
    },
  );
}

class _PathDatabase extends AppDatabase {
  _PathDatabase(this.filePath);
  final String filePath;
  @override
  Future<String> databasePath() async => filePath;
}

class _FixedDatabase extends AppDatabase {
  _FixedDatabase(this.db);
  final Database db;
  @override
  Future<Database> database() async => db;
}

// Observe real SQLite reads without adding test hooks to the production service.
class _ObservedExecutor implements DatabaseExecutor {
  _ObservedExecutor(this.delegate, this.afterQuery);
  final DatabaseExecutor delegate;
  final Future<void> Function(String)? afterQuery;

  @override
  Future<List<Map<String, Object?>>> query(
    String table, {
    bool? distinct,
    List<String>? columns,
    String? where,
    List<Object?>? whereArgs,
    String? groupBy,
    String? having,
    String? orderBy,
    int? limit,
    int? offset,
  }) async {
    final rows = await delegate.query(
      table,
      distinct: distinct,
      columns: columns,
      where: where,
      whereArgs: whereArgs,
      groupBy: groupBy,
      having: having,
      orderBy: orderBy,
      limit: limit,
      offset: offset,
    );
    await afterQuery?.call(table);
    return rows;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ObservedTransaction extends _ObservedExecutor implements Transaction {
  _ObservedTransaction(super.delegate, super.afterQuery);
}

class _ObservedDatabase extends _ObservedExecutor implements Database {
  _ObservedDatabase(
    Database delegate, {
    Future<void> Function(String)? afterQuery,
    this.onTransactionRequested,
    this.onTransactionFinished,
  }) : super(delegate, afterQuery);
  final void Function()? onTransactionRequested;
  final void Function()? onTransactionFinished;

  @override
  Future<T> transaction<T>(
    Future<T> Function(Transaction txn) action, {
    bool? exclusive,
  }) async {
    onTransactionRequested?.call();
    try {
      return await (delegate as Database).transaction(
        (txn) => action(
          afterQuery == null ? txn : _ObservedTransaction(txn, afterQuery),
        ),
        exclusive: exclusive,
      );
    } finally {
      onTransactionFinished?.call();
    }
  }
}
