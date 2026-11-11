import 'dart:io';

import 'package:flutter/material.dart';

import 'helpers/recovery_password.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:pujangga_pos/app/app.dart';
import 'package:pujangga_pos/core/database/app_database.dart';
import 'package:pujangga_pos/core/services/app_startup_service.dart';
import 'package:pujangga_pos/core/utils/app_date_formatting.dart';
import 'package:pujangga_pos/features/karyawan/data/repositories/employee_repository.dart';
import 'package:pujangga_pos/features/karyawan/presentation/controllers/employee_controller.dart';
import 'package:pujangga_pos/features/karyawan/presentation/pages/karyawan_page.dart';
import 'package:pujangga_pos/features/pengaturan/data/services/app_backup_service.dart';
import 'package:pujangga_pos/features/pengaturan/data/services/backup_file_picker_service.dart';
import 'package:pujangga_pos/features/pengaturan/presentation/controllers/pengaturan_restore_controller.dart';
import 'package:pujangga_pos/features/pengaturan/presentation/pages/pengaturan_page.dart';
import 'package:pujangga_pos/features/setup_usaha/presentation/pages/setup_usaha_page.dart';
import 'package:pujangga_pos/features/transaksi/presentation/controllers/transaksi_controller.dart';
import 'package:pujangga_pos/features/transaksi/presentation/pages/transaksi_berhasil_page.dart';

class _DisposableDatabase extends AppDatabase {
  _DisposableDatabase(this.filePath);
  final String filePath;
  @override
  Future<String> databasePath() async => filePath;
}

// Replace only file selection. File parsing, validation, restore, data providers,
// checkout and reset all use production implementations and native SQLite.
class _FixturePicker extends BackupFilePickerService {
  String? selected;
  @override
  Future<String?> pickBackupFile() async => selected;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  WidgetController.hitTestWarningShouldBeFatal = true;
  testWidgets(
    'PR61 restores employee caches and resets drafts without restart',
    (tester) async {
      initializeAppDateFormatting();
      final root = await getTemporaryDirectory();
      // Stop before any mutation if the APK is not our dedicated test package.
      expect(root.path, contains('/com.pujanggapos.pujangga_pos.pr61e2e/'));
      final directory = await Directory(
        path.join(
          root.path,
          'dataset-e2e-${DateTime.now().microsecondsSinceEpoch}',
        ),
      ).create();
      final active = _DisposableDatabase(
        path.join(directory.path, 'active.db'),
      );
      final fixture = _DisposableDatabase(
        path.join(directory.path, 'fixture.db'),
      );
      for (final database in [active, fixture]) {
        expect(
          path.isWithin(directory.path, await database.databasePath()),
          isTrue,
        );
      }
      debugPrint('E2E_ISOLATION: ${directory.path}');
      Future<void> seed(
        AppDatabase database,
        String name,
        double percent,
      ) async {
        final db = await database.database();
        final stamp = DateTime.now().toIso8601String();
        await db.insert('business_profile', {
          'business_name': 'PR61 $name Shop',
          'business_type': 'retail',
          'created_at': stamp,
          'updated_at': stamp,
        });
        await db.insert('items', {
          'name': 'PR61 Jasa',
          'item_type': 'service',
          'sale_price': 100000,
          'harga_modal': 0,
          'stock_qty': 0,
          'is_active': 1,
          'created_at': stamp,
          'updated_at': stamp,
        });
        await EmployeeRepository(database: database).save(
          name: name,
          isActive: true,
          compensationType: 'commission',
          commissionPercent: percent,
          effectiveFrom: DateTime(2026),
        );
      }

      await seed(active, 'Andi', 10);
      await seed(fixture, 'Budi', 20);
      final backup = AppBackupService(
        database: fixture,
        logger: Logger('PR61'),
        backupDirectoryProvider: () async =>
            Directory(path.join(directory.path, 'b')),
      );
      final datasetB = await backup.createBackup(password: null);
      final fixtureDb = await fixture.database();
      await fixtureDb.delete('employee_compensation_periods');
      await fixtureDb.delete('employees');
      final emptyBackup = AppBackupService(
        database: fixture,
        logger: Logger('PR61'),
        backupDirectoryProvider: () async =>
            Directory(path.join(directory.path, 'empty')),
      );
      final datasetEmpty = await emptyBackup.createBackup(password: null);
      final picker = _FixturePicker();
      late ProviderContainer container;
      addTearDown(() async {
        await active.reset();
        await fixture.reset();
        await directory.delete(recursive: true);
        debugPrint(
          'E2E_CLEANUP: disposable databases and backup files removed',
        );
      });
      Future<void> waitFor(bool Function() condition, String reason) async {
        final deadline = DateTime.now().add(const Duration(seconds: 30));
        while (!condition() && DateTime.now().isBefore(deadline)) {
          await tester.pump(const Duration(milliseconds: 100));
          await Future<void>.delayed(const Duration(milliseconds: 50));
        }
        expect(condition(), isTrue, reason: reason);
        await tester.pumpAndSettle();
      }

      Future<void> screenshot(String label) async {
        debugPrint('E2E_SCREENSHOT: $label');
        await Future<void>.delayed(const Duration(seconds: 2));
      }

      Future<void> tapText(String label) async {
        // Notification duration outlives its entrance animation and can cover
        // the cart CTA. Wait for it as a user would before the next action.
        if (find.byType(SnackBar).evaluate().isNotEmpty) {
          await waitFor(
            () => find.byType(SnackBar).evaluate().isEmpty,
            'notification dismissed before $label',
          );
        }
        final finder = find.text(label).last;
        await tester.ensureVisible(finder);
        await tester.tap(finder);
        await tester.pumpAndSettle();
      }

      Future<void> openSettings() async {
        await tester.tap(find.byIcon(Icons.menu).first);
        await tester.pumpAndSettle();
        expect(find.byType(PengaturanPage), findsOneWidget);
      }

      Future<void> scrollSettings(String label) async {
        await tester.scrollUntilVisible(
          find.text(label),
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

      Future<void> restore(String file) async {
        picker.selected = file;
        await openSettings();
        await scrollSettings('Pulihkan Data');
        await tapText('Pulihkan Data');
        await waitFor(
          () => find.text('Pulihkan Data?').evaluate().isNotEmpty,
          'restore confirmation',
        );
        await tester.tap(find.widgetWithText(FilledButton, 'Pulihkan Data'));
        await confirmRecoverySnapshot(tester);
        await waitFor(
          () => find.byType(PengaturanPage).evaluate().isEmpty,
          'restore navigation',
        );
        expect(
          find.textContaining('berhasil dipulihkan ke aplikasi.'),
          findsOneWidget,
        );
      }

      Future<void> cart() async {
        await tapText('Transaksi');
        await tapText('PR61 Jasa');
        await tapText('Keranjang');
        await tester.ensureVisible(find.byType(DropdownButtonFormField<int?>));
        await tester.pumpAndSettle();
      }

      Future<void> selectEmployee(String name) async {
        await tester.tap(find.byType(DropdownButtonFormField<int?>));
        await tester.pumpAndSettle();
        expect(find.textContaining(name), findsWidgets);
        await tester.tap(find.textContaining(name).last);
        await tester.pumpAndSettle();
        expect(
          container.read(transaksiControllerProvider).requireValue.employeeId,
          1,
        );
      }

      Future<void> closeCart() async {
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.text('Keranjang Transaksi'), findsNothing);
      }

      Future<void> checkDraftCleared() async {
        // Observe the draft through its screen. An unobserved autoDispose
        // provider on Home is intentionally allowed to disappear between frames.
        await tapText('Transaksi');
        await waitFor(
          () => container.read(transaksiControllerProvider).hasValue,
          'fresh draft',
        );
        final draft = container.read(transaksiControllerProvider).requireValue;
        expect(draft.cartItems, isEmpty);
        expect(draft.employeeId, isNull);
      }

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(active),
            backupFilePickerServiceProvider.overrideWithValue(picker),
          ],
          child: const PujanggaPosApp(),
        ),
      );
      container = ProviderScope.containerOf(
        tester.element(find.byType(PujanggaPosApp)),
      );
      await tester.pumpAndSettle();
      await cart();
      await selectEmployee('Andi');
      expect(
        (await container.read(activeEmployeesProvider.future))
            .single
            .commissionPercent,
        10,
      );
      expect(
        (await container.read(employeesProvider.future)).single.name,
        'Andi',
      );
      await screenshot('01-andi-selected');
      await closeCart();

      await restore(datasetB.filePath);
      await checkDraftCleared();
      expect(
        (await container.read(activeEmployeesProvider.future)).single.name,
        'Budi',
      );
      expect(
        (await container.read(activeEmployeesProvider.future))
            .single
            .commissionPercent,
        20,
      );
      expect(
        (await container.read(employeesProvider.future)).single.name,
        'Budi',
      );
      await cart();
      expect(find.text('Tanpa karyawan'), findsWidgets);
      await tester.tap(find.byType(DropdownButtonFormField<int?>));
      await tester.pumpAndSettle();
      expect(find.textContaining('Andi'), findsNothing);
      expect(find.textContaining('Budi'), findsWidgets);
      await screenshot('02-restored-budi-options');
      await tester.tap(find.textContaining('Budi').last);
      await tester.pumpAndSettle();
      await tapText('QRIS');
      await tapText('Proses Pembayaran');
      await waitFor(
        () => find.byType(TransaksiBerhasilPage).evaluate().isNotEmpty,
        'checkout receipt',
      );
      final db = await active.database();
      final sale = (await db.query('sales_transactions')).single;
      expect(sale['employee_id'], 1);
      expect(sale['employee_name_snapshot'], 'Budi');
      expect(sale['commission_percent_snapshot'], 20);
      expect(sale['commission_amount'], 20000);
      final expense = (await db.query(
        'expenses',
        where: 'source_type = ?',
        whereArgs: ['commission'],
      )).single;
      expect(expense['employee_id'], 1);
      expect(expense['amount'], 20000);
      debugPrint(
        'E2E_PASS: native SQLite sale=Budi id=1 percent=20 commission=20000 expense=20000',
      );
      await screenshot('03-budi-receipt');
      await tapText('Transaksi Baru');
      await restore(datasetEmpty.filePath);
      await checkDraftCleared();
      expect(await container.read(activeEmployeesProvider.future), isEmpty);
      expect(await container.read(employeesProvider.future), isEmpty);
      await cart();
      await tester.tap(find.byType(DropdownButtonFormField<int?>));
      await tester.pumpAndSettle();
      expect(find.textContaining('Budi'), findsNothing);
      expect(find.textContaining('Andi'), findsNothing);
      await screenshot('04-restore-no-employees');
      await tester.tap(find.text('Tanpa karyawan').last);
      await tester.pumpAndSettle();
      await closeCart();
      debugPrint(
        'E2E_PASS: restore without employees removed all cached options',
      );

      await restore(datasetB.filePath);
      await cart();
      await selectEmployee('Budi');
      await closeCart();
      await openSettings();
      await scrollSettings('Reset Data Aplikasi');
      await tapText('Reset Data Aplikasi');
      expect(find.text('Reset Data Aplikasi?'), findsOneWidget);
      await tapText('Reset Semua Data');
      await waitFor(
        () => find.byType(SetupUsahaPage).evaluate().isNotEmpty,
        'setup after reset',
      );
      expect(await container.read(activeEmployeesProvider.future), isEmpty);
      expect(await container.read(employeesProvider.future), isEmpty);
      await tester.enterText(
        find.byType(TextFormField).first,
        'PR61 Usaha Baru',
      );
      await tapText('Toko Kelontong');
      final submit = find.byType(FilledButton).first;
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await waitFor(
        () => find.byType(SetupUsahaPage).evaluate().isEmpty,
        'new business setup',
      );
      await checkDraftCleared();
      await openSettings();
      await scrollSettings('Karyawan');
      await tapText('Karyawan');
      expect(find.byType(KaryawanPage), findsOneWidget);
      expect(find.text('Belum ada data karyawan.'), findsOneWidget);
      expect(find.textContaining('Andi'), findsNothing);
      expect(find.textContaining('Budi'), findsNothing);
      await screenshot('05-reset-new-business-employees');
      final resetDb = await active.database();
      expect(await resetDb.query('employees'), isEmpty);
      expect(await resetDb.query('sales_transactions'), isEmpty);
      expect(
        (await resetDb.query('business_profile')).single['business_name'],
        'PR61 Usaha Baru',
      );
      expect(await resetDb.rawQuery('PRAGMA integrity_check'), [
        {'integrity_check': 'ok'},
      ]);
      expect(await resetDb.rawQuery('PRAGMA foreign_key_check'), isEmpty);
      debugPrint(
        'E2E_PASS: reset + UI setup preserved same ProviderContainer, employees/sales empty, integrity OK',
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );
}
