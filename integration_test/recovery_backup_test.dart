import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pujangga_pos/app/app.dart';
import 'package:pujangga_pos/core/database/app_database.dart';
import 'package:pujangga_pos/core/services/app_startup_service.dart';
import 'package:pujangga_pos/core/utils/app_date_formatting.dart';
import 'package:pujangga_pos/features/pengaturan/data/services/app_backup_service.dart';
import 'package:pujangga_pos/features/pengaturan/data/services/backup_file_picker_service.dart';
import 'package:pujangga_pos/features/pengaturan/presentation/controllers/app_recovery_provider.dart';
import 'package:pujangga_pos/features/pengaturan/presentation/controllers/pengaturan_restore_controller.dart';
import 'package:pujangga_pos/features/pengaturan/presentation/pages/pengaturan_page.dart';
import 'package:pujangga_pos/features/setup_usaha/presentation/pages/setup_usaha_page.dart';
import 'package:pujangga_pos/features/transaksi/data/datasources/transaction_local_data_source.dart';
import 'package:pujangga_pos/features/transaksi/domain/entities/transaksi_cart_item.dart';
import 'package:pujangga_pos/features/transaksi/domain/entities/transaksi_item.dart';
import 'package:pujangga_pos/features/transaksi/domain/entities/transaksi_submit_request.dart';

import 'helpers/recovery_password.dart';

class _DisposableDatabase extends AppDatabase {
  _DisposableDatabase(this.file);
  final String file;
  @override
  Future<String> databasePath() async => file;
}

class _Picker extends BackupFilePickerService {
  _Picker(this.file);
  final String file;
  @override
  Future<String?> pickBackupFile() async => file;
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'recover newer sale after old restore and explicitly reset local backups',
    (tester) async {
      initializeAppDateFormatting();
      final temporary = await getTemporaryDirectory();
      // Must run in a separately installed disposable Android package.
      expect(
        temporary.path,
        contains('/com.pujanggapos.pujangga_pos.issue56e2e/'),
      );
      final root = await Directory(
        p.join(
          temporary.path,
          'recovery-${DateTime.now().microsecondsSinceEpoch}',
        ),
      ).create();
      final database = _DisposableDatabase(p.join(root.path, 'active.sqlite'));
      expect(p.isWithin(root.path, await database.databasePath()), isTrue);
      final db = await database.database();
      final stamp = DateTime.now().toIso8601String();
      await db.insert('business_profile', {
        'business_name': 'Issue 56 Synthetic',
        'business_type': 'retail',
        'created_at': stamp,
        'updated_at': stamp,
      });
      final itemId = await db.insert('items', {
        'name': 'Synthetic Coffee',
        'item_type': 'product',
        'sale_price': 10000,
        'stock_qty': 10,
        'created_at': stamp,
        'updated_at': stamp,
      });
      await db.insert('stock_movements', {
        'item_id': itemId,
        'movement_type': 'initial',
        'qty_change': 10,
        'qty_before': 0,
        'qty_after': 10,
        'reference_type': 'item',
        'reference_id': itemId,
        'created_at': stamp,
      });
      final old = await AppBackupService(
        database: database,
        logger: Logger('e2e'),
        backupDirectoryProvider: () async => root,
      ).createBackup(password: null);
      await TransactionLocalDataSource(database: database).saveTransaction(
        TransaksiSubmitRequest(
          items: [
            TransaksiCartItem(
              item: TransaksiItem(
                id: '$itemId',
                name: 'Synthetic Coffee',
                category: '',
                itemType: 'barang',
                sellingPrice: 10000,
                stockQuantity: 10,
                isActive: true,
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
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          backupFilePickerServiceProvider.overrideWithValue(
            _Picker(old.filePath),
          ),
        ],
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const PujanggaPosApp(),
        ),
      );
      await binding.convertFlutterSurfaceToImage();
      Future<void> screenshot(String name) async {
        await tester.pumpAndSettle();
        await File(p.join(temporary.path, 'issue56-$name.png'))
            .writeAsBytes(await binding.takeScreenshot(name));
      }

      Future<void> waitFor(bool Function() ready) async {
        final until = DateTime.now().add(const Duration(seconds: 90));
        while (!ready() && DateTime.now().isBefore(until)) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(ready(), isTrue);
        await tester.pumpAndSettle();
      }

      Future<void> settings() async {
        await tester.tap(find.byTooltip('Pengaturan'));
        await waitFor(
          () => find
              .descendant(
                of: find.byType(PengaturanPage),
                matching: find.byType(Scrollable),
              )
              .evaluate()
              .isNotEmpty,
        );
      }

      Future<void> scrollTo(String label) async {
        await tester.scrollUntilVisible(
          find.text(label),
          300,
          scrollable: find
              .descendant(
                of: find.byType(PengaturanPage),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        await tester.ensureVisible(find.text(label).first);
        await tester.pumpAndSettle();
      }

      Future<void> confirmRestore() async {
        await tester.tap(find.widgetWithText(FilledButton, 'Pulihkan Data'));
        await confirmRecoverySnapshot(tester);
        await waitFor(() => find.byType(PengaturanPage).evaluate().isEmpty);
      }

      await waitFor(() => find.byTooltip('Pengaturan').evaluate().isNotEmpty);
      await settings();
      await scrollTo('Pulihkan Data');
      await tester.tap(find.text('Pulihkan Data').first);
      await waitFor(() => find.text('Pulihkan Data?').evaluate().isNotEmpty);
      await confirmRestore();
      expect(await db.query('sales_transactions'), isEmpty);
      expect((await db.query('items')).single['stock_qty'], 10);

      // Discover persisted files using a new provider container (restart behavior).
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      container.dispose();
      final reopened = ProviderContainer(
        overrides: [appDatabaseProvider.overrideWithValue(database)],
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: reopened,
          child: const PujanggaPosApp(),
        ),
      );
      await waitFor(() => find.byTooltip('Pengaturan').evaluate().isNotEmpty);
      expect(
        await reopened.read(appRecoveryServiceProvider).snapshots(),
        hasLength(1),
      );
      await settings();
      await scrollTo('Cadangan Pemulihan');
      await screenshot('settings');
      await tester.tap(find.text('Cadangan Pemulihan'));
      await waitFor(
        () => find.textContaining('Sebelum restore:').evaluate().isNotEmpty,
      );
      await tester.tap(find.textContaining('Sebelum restore:').first);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextFormField),
        'Synthetic recovery 56',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Buka Cadangan'));
      await waitFor(() => find.text('Pulihkan Data?').evaluate().isNotEmpty);
      await confirmRestore();
      expect(await db.query('sales_transactions'), hasLength(1));
      expect(await db.query('sales_transaction_items'), hasLength(1));
      expect((await db.query('items')).single['stock_qty'], 9);
      expect(
        (await db.query('stock_movements', orderBy: 'id')).last['qty_after'],
        9,
      );
      expect(await db.rawQuery('PRAGMA foreign_key_check'), isEmpty);

      await settings();
      await scrollTo('Reset Data Aplikasi');
      await tester.tap(find.text('Reset Data Aplikasi'));
      await tester.pumpAndSettle();
      await screenshot('reset');
      expect(find.text('Cadangkan dan Ekspor Dulu'), findsOneWidget);
      await tester.tap(find.text('Batal'));
      await tester.pumpAndSettle();
      expect(await db.query('sales_transactions'), hasLength(1));
      await tester.tap(find.text('Reset Data Aplikasi'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cadangkan dan Ekspor Dulu'));
      await tester.pumpAndSettle();
      expect(find.text('Lindungi Cadangan'), findsOneWidget);
      await tester.tap(find.text('Batal'));
      await tester.pumpAndSettle();
      expect(await db.query('sales_transactions'), hasLength(1));
      await tester.tap(find.text('Reset Data Aplikasi'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reset Semua Data'));
      await waitFor(() => find.byType(SetupUsahaPage).evaluate().isNotEmpty);
      expect(
        await reopened.read(appRecoveryServiceProvider).snapshots(),
        isEmpty,
      );
      expect(
        await (await database.database()).query('sales_transactions'),
        isEmpty,
      );
      debugPrint('ISSUE56_E2E_PASS: sale, stock, restart, recovery, reset');
      await tester.pumpWidget(const SizedBox.shrink());
      reopened.dispose();
      await database.reset();
      expect(p.isWithin(temporary.path, root.path), isTrue);
      await root.delete(recursive: true);
    },
    timeout: const Timeout(Duration(minutes: 8)),
  );
}
