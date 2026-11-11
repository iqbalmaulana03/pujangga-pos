import 'dart:convert';
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
import 'package:pujangga_pos/core/services/business_logo_service.dart';
import 'package:pujangga_pos/core/utils/app_date_formatting.dart';
import 'package:pujangga_pos/features/pengaturan/data/services/app_backup_service.dart';
import 'package:pujangga_pos/features/pengaturan/data/services/backup_file_picker_service.dart';
import 'package:pujangga_pos/features/pengaturan/data/services/backup_input_limits.dart';
import 'package:pujangga_pos/features/pengaturan/presentation/controllers/pengaturan_backup_controller.dart';
import 'package:pujangga_pos/features/pengaturan/presentation/controllers/pengaturan_restore_controller.dart';
import 'package:pujangga_pos/features/pengaturan/presentation/pages/pengaturan_page.dart';
import 'package:pujangga_pos/features/pengaturan/presentation/widgets/backup_password_dialog.dart';
import 'package:pujangga_pos/features/transaksi/presentation/pages/transaksi_berhasil_page.dart';

const password = 'PR65 synthetic password';

class _Database extends AppDatabase {
  _Database(this.filePath);
  final String filePath;
  @override
  Future<String> databasePath() async => filePath;
}

class _Picker extends BackupFilePickerService {
  String? selected;
  bool native = false;
  @override
  Future<String?> pickBackupFile() =>
      native ? super.pickBackupFile() : Future.value(selected);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Android encrypted export, native share/picker, restore and reopen',
    (tester) async {
      initializeAppDateFormatting();
      final cache = await getTemporaryDirectory();
      expect(cache.path, contains('/com.pujanggapos.pujangga_pos.pr65e2e/'));
      final directory = await Directory(
        path.join(
          cache.path,
          'encryption-e2e-${DateTime.now().microsecondsSinceEpoch}',
        ),
      ).create();
      var database = _Database(path.join(directory.path, 'source.sqlite'));
      final destination = _Database(
        path.join(directory.path, 'destination.sqlite'),
      );
      for (final db in [database, destination]) {
        expect(path.isWithin(directory.path, await db.databasePath()), isTrue);
      }
      debugPrint('E2E_ISOLATION: ${directory.path}');
      var db = await database.database();
      final stamp = DateTime.now().toIso8601String();
      final categories = db.batch();
      for (var i = 0; i < 500; i++) {
        categories.insert('categories', {
          'name': 'PR65 Synthetic Category $i',
          'item_type': 'product',
          'created_at': stamp,
          'updated_at': stamp,
        });
      }
      await categories.commit(noResult: true);
      await db.insert('business_profile', {
        'business_name': 'PR65 Synthetic Shop',
        'business_type': 'retail',
        'created_at': stamp,
        'updated_at': stamp,
      });
      final item = await db.insert('items', {
        'name': 'PR65 Synthetic Coffee',
        'item_type': 'product',
        'unit': 'Pcs',
        'sale_price': 10000,
        'harga_modal': 4321,
        'stock_qty': 10,
        'created_at': stamp,
        'updated_at': stamp,
      });
      await db.insert('stock_movements', {
        'item_id': item,
        'movement_type': 'initial',
        'qty_change': 10,
        'qty_before': 0,
        'qty_after': 10,
        'reference_type': 'item',
        'reference_id': item,
        'created_at': stamp,
      });
      await db.insert('employees', {
        'name': 'PR65 Synthetic Employee',
        'compensation_type': 'monthly_salary',
        'monthly_salary': 7654321,
        'effective_from': stamp,
        'created_at': stamp,
        'updated_at': stamp,
      });
      final picker = _Picker();
      final logs = <LogRecord>[];
      final subscription = Logger.root.onRecord.listen(logs.add);
      final logos = BusinessLogoService(
        supportDirectory: () async => directory,
        temporaryDirectory: () async => directory,
      );
      ProviderContainer containerFor(AppDatabase target) => ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(target),
          businessLogoServiceProvider.overrideWithValue(logos),
          backupFilePickerServiceProvider.overrideWithValue(picker),
          appBackupServiceProvider.overrideWithValue(
            AppBackupService(
              database: target,
              logger: Logger('PR65'),
              logoService: logos,
              backupDirectoryProvider: () async => directory,
            ),
          ),
        ],
      );
      var container = containerFor(database);
      addTearDown(() async {
        container.dispose();
        await subscription.cancel();
        await database.reset();
        await destination.reset();
        expect(path.isWithin(cache.path, directory.path), isTrue);
        await directory.delete(recursive: true);
        debugPrint('E2E_CLEANUP: temporary databases removed');
      });

      Future<void> waitFor(bool Function() condition, String reason) async {
        final deadline = DateTime.now().add(const Duration(seconds: 90));
        while (!condition() && DateTime.now().isBefore(deadline)) {
          await tester.pump(const Duration(milliseconds: 100));
          await Future<void>.delayed(const Duration(milliseconds: 50));
        }
        expect(condition(), isTrue, reason: reason);
      }

      Future<void> shot(String label) async {
        debugPrint('E2E_SCREENSHOT: $label');
        await Future<void>.delayed(const Duration(seconds: 1));
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

      Future<void> settings() async {
        if (find.byType(PengaturanPage).evaluate().isEmpty) {
          await tester.tap(find.byIcon(Icons.menu).first);
          await tester.pumpAndSettle();
        }
        await tester.scrollUntilVisible(
          find.text('Cadangkan Data'),
          350,
          scrollable: find
              .descendant(
                of: find.byType(PengaturanPage),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        await tester.pumpAndSettle();
      }

      Future<void> enterPassword(String value, {bool creating = false}) async {
        // The restore controller remains loading while requesting a password.
        // Its background spinner intentionally never settles until submission.
        await tester.pump(const Duration(milliseconds: 350));
        final fields = find.descendant(
          of: find.byType(BackupPasswordDialog),
          matching: find.byType(TextFormField),
        );
        await tester.enterText(fields.first, value);
        if (creating) await tester.enterText(fields.last, value);
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pump(const Duration(milliseconds: 350));
      }

      Future<void> shareClosed(String label) async {
        debugPrint('E2E_SHARE_OPEN: $label');
        await Future<void>.delayed(const Duration(seconds: 4));
        await tester.pumpAndSettle();
      }

      Future<String> exportUI({required bool encrypted}) async {
        final previous = container
            .read(pengaturanBackupControllerProvider)
            .asData
            ?.value
            ?.filePath;
        await settings();
        await tester.tap(find.text('Cadangkan Data'));
        await tester.pumpAndSettle();
        expect(
          tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
          isTrue,
        );
        if (encrypted) {
          await tester.tap(find.text('Cadangkan Terenkripsi'));
          await tester.pumpAndSettle();
          expect(find.text('Masukkan kata sandi.'), findsOneWidget);
          await enterPassword(password, creating: true);
          await shot('encrypted-password-dialog');
          await tester.tap(find.text('Cadangkan Terenkripsi'));
        } else {
          await tester.tap(find.byType(SwitchListTile));
          await tester.pumpAndSettle();
          expect(find.textContaining('gaji karyawan'), findsOneWidget);
          await shot('plaintext-warning');
          await tester.tap(find.text('Cadangkan Tanpa Enkripsi'));
        }
        await waitFor(() {
          final state = container.read(pengaturanBackupControllerProvider);
          return !state.isLoading &&
              state.asData?.value != null &&
              state.asData!.value!.filePath != previous;
        }, 'backup UI creates a new file');
        await shareClosed(encrypted ? 'encrypted' : 'plaintext');
        return container
            .read(pengaturanBackupControllerProvider)
            .requireValue!
            .filePath;
      }

      Future<Map<String, List<Map<String, Object?>>>> snapshot() async => {
        for (final table in AppBackupService.backupTables)
          table: await db.query(table),
      };
      Future<void> pick(String file) async {
        await settings();
        picker.selected = file;
        await tester.tap(find.text('Pulihkan Data').first);
        await waitFor(
          () =>
              find.byType(BackupPasswordDialog).evaluate().isNotEmpty ||
              find.text('Pulihkan Data?').evaluate().isNotEmpty ||
              container.read(pengaturanRestoreControllerProvider).hasError,
          'password, preview, or restore inspection error',
        );
        await tester.pump(const Duration(milliseconds: 350));
      }

      Future<void> confirmRestore() async {
        await waitFor(
          () => find.text('Pulihkan Data?').evaluate().isNotEmpty,
          'restore preview',
        );
        await tester.pumpAndSettle();
        await shot('restore-confirmation');
        await tester.tap(find.widgetWithText(FilledButton, 'Pulihkan Data'));
        await confirmRecoverySnapshot(tester);
        await waitFor(
          () => find.byType(PengaturanPage).evaluate().isEmpty,
          'restore navigation',
        );
        await tester.pumpAndSettle();
      }

      await mount();
      await tester.tap(find.text('Transaksi').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('PR65 Synthetic Coffee').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Keranjang'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('QRIS'));
      await tester.tap(find.text('QRIS'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Proses Pembayaran'));
      await tester.tap(find.text('Proses Pembayaran'));
      await waitFor(
        () => find.byType(TransaksiBerhasilPage).evaluate().isNotEmpty,
        'real UI sale',
      );
      await tester.pumpAndSettle();
      expect((await db.query('items')).single['stock_qty'], 9);
      expect(await db.query('sales_transactions'), hasLength(1));
      await tester.tap(find.text('Transaksi Baru'));
      await tester.pumpAndSettle();
      final expected = await snapshot();
      final encrypted = await exportUI(encrypted: true);
      final raw = await File(encrypted).readAsString();
      expect(
        (jsonDecode(raw)['ciphertext'] as String).length,
        greaterThan(BackupInputLimits.maxStringLength),
      );
      for (final value in [
        'PR65 Synthetic Shop',
        'PR65 Synthetic Employee',
        '7654321',
        '4321',
        password,
        'tables',
      ]) {
        expect(raw, isNot(contains(value)));
      }
      debugPrint(
        'E2E_PASS: UI checkout, encrypted export, sensitive plaintext absent',
      );

      // Host decrypts with Python cryptography and independently re-encrypts.
      // Android later imports this envelope through the real document picker.
      debugPrint('E2E_EXPORT: $encrypted');
      final hostReady = File(path.join(directory.path, 'host-ready'));
      final deadline = DateTime.now().add(const Duration(seconds: 60));
      while (!await hostReady.exists() && DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
      expect(
        await hostReady.exists(),
        isTrue,
        reason: 'independent host verification',
      );

      await pick(encrypted);
      await tester.tap(find.text('Batal'));
      await tester.pumpAndSettle();
      expect(await snapshot(), expected);
      await pick(encrypted);
      await enterPassword('wrong synthetic password');
      await tester.tap(find.widgetWithText(FilledButton, 'Buka Cadangan'));
      await waitFor(
        () => container.read(pengaturanRestoreControllerProvider).hasError,
        'wrong password rejected',
      );
      await tester.pumpAndSettle();
      expect(
        find.textContaining(
          'Kata sandi salah atau file cadangan telah berubah.',
        ),
        findsOneWidget,
      );
      expect(await snapshot(), expected);
      await shot('wrong-password-rejected');
      final envelope = jsonDecode(raw) as Map<String, dynamic>;
      final bytes = base64Decode(envelope['ciphertext'] as String);
      bytes[0] ^= 1;
      final tampered = File(path.join(directory.path, 'tampered.json'));
      await tampered.writeAsString(
        jsonEncode({...envelope, 'ciphertext': base64Encode(bytes)}),
      );
      await pick(tampered.path);
      await enterPassword(password);
      await tester.tap(find.widgetWithText(FilledButton, 'Buka Cadangan'));
      await waitFor(
        () => container.read(pengaturanRestoreControllerProvider).hasError,
        'tamper rejected',
      );
      await tester.pumpAndSettle();
      expect(await snapshot(), expected);
      expect(find.text('Pulihkan Data?'), findsNothing);
      debugPrint(
        'E2E_PASS: password cancel, wrong password, tamper; all tables unchanged',
      );

      // Fresh native SQLite destination, new provider tree, same physical device.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      container.dispose();
      db = await destination.database();
      container = containerFor(destination);
      await mount();
      // No business profile means setup is shown. Seed a synthetic destination
      // profile solely to access Settings, then verify the restore replaces it.
      await db.insert('business_profile', {
        'business_name': 'PR65 Destination Sentinel',
        'business_type': 'retail',
        'created_at': stamp,
        'updated_at': stamp,
      });
      container.invalidate(appStartupProvider);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      container.dispose();
      container = containerFor(destination);
      await mount();
      picker.native = true;
      await settings();
      debugPrint('E2E_PICK_NATIVE');
      await tester.tap(find.text('Pulihkan Data').first);
      await waitFor(
        () => find.byType(BackupPasswordDialog).evaluate().isNotEmpty,
        'native picker returns encrypted file',
      );
      await enterPassword(password);
      await tester.tap(find.widgetWithText(FilledButton, 'Buka Cadangan'));
      await confirmRestore();
      expect(await snapshot(), expected);
      debugPrint(
        'E2E_PASS: Python re-encrypted backup imported through native Android picker; all tables identical',
      );

      picker.native = false;
      await pick(encrypted);
      await enterPassword(password);
      await tester.tap(find.widgetWithText(FilledButton, 'Buka Cadangan'));
      await waitFor(
        () => find.text('Pulihkan Data?').evaluate().isNotEmpty,
        'preview before cancellation',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Batal'));
      await tester.pumpAndSettle();
      expect(await snapshot(), expected);
      final legacy = await exportUI(encrypted: false);
      expect(
        await File(legacy).readAsString(),
        contains('PR65 Synthetic Employee'),
      );
      await db.update('business_profile', {
        'business_name': 'PR65 Changed Sentinel',
      });
      await pick(legacy);
      expect(find.byType(BackupPasswordDialog), findsNothing);
      await confirmRestore();
      expect(await snapshot(), expected);
      debugPrint(
        'E2E_PASS: cancel restore preview; explicit plaintext export and legacy restore',
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      container.dispose();
      await db.close();
      final reopened = _Database(await destination.databasePath());
      db = await reopened.database();
      container = containerFor(reopened);
      await mount();
      expect(await snapshot(), expected);
      expect(await db.rawQuery('PRAGMA integrity_check'), [
        {'integrity_check': 'ok'},
      ]);
      expect(await db.rawQuery('PRAGMA foreign_key_check'), isEmpty);
      expect(
        logs.map((record) => record.message).join(),
        isNot(contains(password)),
      );
      await tester.tap(find.text('Stok').last);
      await tester.pumpAndSettle();
      expect(find.text('PR65 Synthetic Coffee'), findsWidgets);
      await shot('restored-after-reopen');
      debugPrint(
        'E2E_PASS: reopen persists every table; integrity ok; FK clean; no password in logs',
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await db.close();
    },
    timeout: const Timeout(Duration(minutes: 12)),
  );
}
