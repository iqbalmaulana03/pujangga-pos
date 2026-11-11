import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

import 'helpers/recovery_password.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:pujangga_pos/app/app.dart';
import 'package:pujangga_pos/core/database/app_database.dart';
import 'package:pujangga_pos/core/services/app_startup_service.dart';
import 'package:pujangga_pos/core/utils/app_date_formatting.dart';
import 'package:pujangga_pos/features/pengaturan/data/services/app_backup_service.dart';
import 'package:pujangga_pos/features/pengaturan/data/services/app_restore_service.dart';
import 'package:pujangga_pos/features/pengaturan/data/services/backup_file_picker_service.dart';
import 'package:pujangga_pos/features/pengaturan/presentation/controllers/pengaturan_backup_controller.dart';
import 'package:pujangga_pos/features/pengaturan/presentation/controllers/pengaturan_restore_controller.dart';
import 'package:pujangga_pos/features/pengaturan/presentation/pages/pengaturan_page.dart';
import 'package:pujangga_pos/features/transaksi/presentation/pages/transaksi_berhasil_page.dart';
import 'package:sqflite/sqflite.dart';

class _DisposableDatabase extends AppDatabase {
  _DisposableDatabase(this.filePath);
  final String filePath;
  @override
  Future<String> databasePath() async => filePath;
}

// The only replaced platform boundary: deterministic selection of our own file.
// Parsing, validation, confirmation UI and restore use the real implementations.
class _FixturePicker extends BackupFilePickerService {
  String? selected;
  @override
  Future<String?> pickBackupFile() async => selected;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Android backup snapshot, UI checkout, restore and reopen', (
    tester,
  ) async {
    initializeAppDateFormatting();
    final root = await getTemporaryDirectory();
    expect(root.path, contains('/com.pujanggapos.pujangga_pos.pr60e2e/'));
    final directory = await Directory(
      path.join(
        root.path,
        'backup-e2e-${DateTime.now().microsecondsSinceEpoch}',
      ),
    ).create();
    final source = _DisposableDatabase(path.join(directory.path, 'source.db'));
    final restored = _DisposableDatabase(
      path.join(directory.path, 'restored.db'),
    );
    for (final database in [source, restored]) {
      expect(
        path.isWithin(directory.path, await database.databasePath()),
        isTrue,
      );
    }
    debugPrint('E2E_ISOLATION: ${directory.path}');
    final db = await source.database();
    final stamp = DateTime.now().toIso8601String();
    await db.insert('business_profile', {
      'business_name': 'PR60 Synthetic Shop',
      'business_type': 'retail',
      'created_at': stamp,
      'updated_at': stamp,
    });
    final id = await db.insert('items', {
      'name': 'PR60 Kopi',
      'item_type': 'product',
      'sale_price': 10000,
      'harga_modal': 4000,
      'stock_qty': 10,
      'unit': 'Pcs',
      'created_at': stamp,
      'updated_at': stamp,
    });
    await db.insert('stock_movements', {
      'item_id': id,
      'movement_type': 'initial',
      'qty_change': 10,
      'qty_before': 0,
      'qty_after': 10,
      'reference_type': 'item',
      'reference_id': id,
      'created_at': stamp,
    });
    final readReached = Completer<void>();
    final releaseRead = Completer<void>();
    final saleRequested = Completer<void>();
    var armSale = false;
    var failedRead = false;
    var pauseRead = true;
    var fileNumber = 0;
    final backupDb = _ObservedDatabase(
      db,
      afterQuery: (table) async {
        if (failedRead && table == 'sales_transaction_items') {
          throw StateError('PR60 synthetic read failure');
        }
        if (pauseRead && table == 'items') {
          readReached.complete();
          await releaseRead.future;
        }
      },
    );
    final saleDb = _ObservedDatabase(
      db,
      onTransactionRequested: () {
        if (armSale && !saleRequested.isCompleted) saleRequested.complete();
      },
    );
    final backupService = AppBackupService(
      database: _FixedDatabase(backupDb),
      logger: Logger('PR60'),
      backupDirectoryProvider: () async =>
          Directory(path.join(directory.path, 'backup-${fileNumber++}')),
    );
    final picker = _FixturePicker();
    ProviderContainer makeContainer() => ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(_FixedDatabase(saleDb)),
        appBackupServiceProvider.overrideWithValue(backupService),
        backupFilePickerServiceProvider.overrideWithValue(picker),
      ],
    );
    var container = makeContainer();
    addTearDown(() async {
      if (!releaseRead.isCompleted) releaseRead.complete();
      container.dispose();
      await source.reset();
      await restored.reset();
      await directory.delete(recursive: true);
      debugPrint('E2E_CLEANUP: ${directory.path} removed');
    });

    Future<void> waitFor(bool Function() condition, String reason) async {
      final deadline = DateTime.now().add(const Duration(seconds: 30));
      while (!condition() && DateTime.now().isBefore(deadline)) {
        await tester.pump(const Duration(milliseconds: 100));
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
      expect(condition(), isTrue, reason: reason);
    }

    Future<void> mount() async {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const PujanggaPosApp(),
        ),
      );
      await tester.pumpAndSettle();
    }

    Future<void> ledger(Database database, int sales) async {
      final item = (await database.query('items')).single;
      final movements = await database.query('stock_movements', orderBy: 'id');
      expect(item['stock_qty'], 10 - sales);
      expect(item['stock_qty'], movements.last['qty_after']);
      expect(
        item['stock_qty'],
        movements.fold<num>(0, (sum, row) => sum + (row['qty_change'] as num)),
      );
      expect(await database.query('sales_transactions'), hasLength(sales));
      expect(await database.query('sales_transaction_items'), hasLength(sales));
      expect(await database.rawQuery('PRAGMA integrity_check'), [
        {'integrity_check': 'ok'},
      ]);
      expect(await database.rawQuery('PRAGMA foreign_key_check'), isEmpty);
    }

    Future<void> openSettings() async {
      await tester.tap(find.byIcon(Icons.menu).first);
      await tester.pumpAndSettle();
      expect(find.byType(PengaturanPage), findsOneWidget);
    }

    Future<void> scrollTo(String label) async {
      await tester.scrollUntilVisible(
        find.text(label).first,
        400,
        scrollable: find
            .descendant(
              of: find.byType(PengaturanPage),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pumpAndSettle();
    }

    Future<void> restoreUI(String file) async {
      picker.selected = file;
      await openSettings();
      await scrollTo('Pulihkan Data');
      await tester.tap(find.text('Pulihkan Data').first);
      await waitFor(
        () => find.text('Pulihkan Data?').evaluate().isNotEmpty,
        'restore confirmation',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Pulihkan Data'));
      await confirmRecoverySnapshot(tester);
      await waitFor(
        () => find.byType(PengaturanPage).evaluate().isEmpty,
        'restore returns to home',
      );
      await tester.pumpAndSettle();
      expect(
        find.textContaining('berhasil dipulihkan ke aplikasi.'),
        findsOneWidget,
      );
    }

    await mount();
    await tester.tap(find.text('Transaksi').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('PR60 Kopi').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Keranjang'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('QRIS'));
    await tester.tap(find.text('QRIS'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Proses Pembayaran'));

    // Real backup controller/service + native Android SQLite. Pause only reads
    // so a real checkout from the UI reaches the SQLite queue between tables.
    final concurrentBackup = container
        .read(pengaturanBackupControllerProvider.notifier)
        .createBackup(password: null);
    await waitFor(() => readReached.isCompleted, 'backup read items');
    armSale = true;
    await tester.tap(find.text('Proses Pembayaran'));
    await waitFor(
      () => saleRequested.isCompleted,
      'UI sale queued during snapshot',
    );
    releaseRead.complete();
    final beforeSale = await concurrentBackup;
    pauseRead = false;
    await waitFor(
      () => find.byType(TransaksiBerhasilPage).evaluate().isNotEmpty,
      'receipt after concurrent backup',
    );
    await tester.pumpAndSettle();
    await ledger(db, 1);
    final restoreService = AppRestoreService(
      database: restored,
      logger: Logger('PR60'),
    );
    await restoreService.restoreBackup(
      await restoreService.inspectBackupFile(beforeSale.filePath),
    );
    await ledger(await restored.database(), 0);
    debugPrint(
      'E2E_PASS: concurrent backup restored stock=10, no sale; live stock=9, one sale',
    );
    debugPrint('E2E_SCREENSHOT: receipt');
    await Future<void>.delayed(const Duration(seconds: 2));

    await tester.tap(find.text('Transaksi Baru'));
    await tester.pumpAndSettle();
    await openSettings();
    await scrollTo('Cadangkan Data');
    await tester.tap(find.text('Cadangkan Data'));
    await waitFor(() {
      final state = container.read(pengaturanBackupControllerProvider);
      return !state.isLoading &&
          state.asData?.value != null &&
          state.asData!.value!.filePath != beforeSale.filePath;
    }, 'backup UI completes');
    final afterSale = container
        .read(pengaturanBackupControllerProvider)
        .requireValue!;
    expect(afterSale.recordCounts['sales_transactions'], 1);
    expect(await File(afterSale.filePath).exists(), isTrue);
    debugPrint('E2E_SHARE_OPEN');
    // Host confirms the native chooser then sends Android Back. No share target
    // is selected; synthetic backup stays in this test's private directory.
    await Future<void>.delayed(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    final payload =
        jsonDecode(await File(afterSale.filePath).readAsString()) as Map;
    expect(
      (payload['tables'] as Map).keys.toSet(),
      AppBackupService.backupTables.toSet(),
    );
    await restoreService.restoreBackup(
      await restoreService.inspectBackupFile(afterSale.filePath),
    );
    await ledger(await restored.database(), 1);

    // Failure is injected after a real table read; exercise the real error UI.
    failedRead = true;
    await tester.tap(find.text('Cadangkan Data'));
    await waitFor(
      () => container.read(pengaturanBackupControllerProvider).hasError,
      'read failure surfaces',
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Gagal mencadangkan data:'), findsOneWidget);
    expect(fileNumber, 2);
    await ledger(db, 1);
    failedRead = false;
    GoRouter.of(tester.element(find.byType(PengaturanPage))).pop();
    await tester.pumpAndSettle();
    debugPrint(
      'E2E_PASS: native share opened; after-sale backup restores; read failure has no export',
    );

    await restoreUI(beforeSale.filePath);
    await ledger(db, 0);
    await tester.tap(find.text('Stok').last);
    await tester.pumpAndSettle();
    expect(find.text('PR60 Kopi'), findsWidgets);
    debugPrint('E2E_SCREENSHOT: restored-before-sale');
    await Future<void>.delayed(const Duration(seconds: 2));
    await restoreUI(afterSale.filePath);
    await ledger(db, 1);

    // Rebuild the whole app/provider tree and reopen the persisted Android DB.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    container.dispose();
    await db.close();
    final reopened = _DisposableDatabase(await source.databasePath());
    final persisted = await reopened.database();
    saleDb.delegate = persisted;
    container = makeContainer();
    await mount();
    await ledger(persisted, 1);
    await tester.tap(find.text('Stok').last);
    await tester.pumpAndSettle();
    expect(find.text('PR60 Kopi'), findsWidgets);
    debugPrint('E2E_SCREENSHOT: restored-after-reopen');
    await Future<void>.delayed(const Duration(seconds: 2));
    debugPrint(
      'E2E_PASS: UI restore before/after sale and app/database reopen; stock=9; integrity ok; FK clean',
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await persisted.close();
  }, timeout: const Timeout(Duration(minutes: 6)));
}

class _FixedDatabase extends AppDatabase {
  _FixedDatabase(this.db);
  final Database db;
  @override
  Future<Database> database() async => db;
}

class _ObservedExecutor implements DatabaseExecutor {
  _ObservedExecutor(this.delegate, this.afterQuery);
  DatabaseExecutor delegate;
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
  Future<List<Map<String, Object?>>> rawQuery(
    String sql, [
    List<Object?>? arguments,
  ]) => delegate.rawQuery(sql, arguments);
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
  }) : super(delegate, afterQuery);
  final void Function()? onTransactionRequested;
  @override
  Future<T> transaction<T>(
    Future<T> Function(Transaction) action, {
    bool? exclusive,
  }) {
    onTransactionRequested?.call();
    return (delegate as Database).transaction(
      (txn) => action(
        afterQuery == null ? txn : _ObservedTransaction(txn, afterQuery),
      ),
      exclusive: exclusive,
    );
  }
}
