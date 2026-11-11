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
import 'package:pujangga_pos/core/constants/app_constants.dart';
import 'package:pujangga_pos/core/database/app_database.dart';
import 'package:pujangga_pos/core/services/app_startup_service.dart';
import 'package:pujangga_pos/core/utils/app_date_formatting.dart';
import 'package:pujangga_pos/features/beranda/presentation/pages/beranda_page.dart';
import 'package:pujangga_pos/features/laporan/presentation/controllers/laporan_controller.dart';
import 'package:pujangga_pos/features/laporan/presentation/pages/laporan_page.dart';
import 'package:pujangga_pos/features/pengaturan/data/services/app_backup_service.dart';
import 'package:pujangga_pos/features/pengaturan/data/services/backup_file_picker_service.dart';
import 'package:pujangga_pos/features/pengaturan/presentation/controllers/pengaturan_restore_controller.dart';
import 'package:pujangga_pos/features/pengaturan/presentation/pages/pengaturan_page.dart';
import 'package:pujangga_pos/features/riwayat/presentation/controllers/riwayat_controller.dart';
import 'package:pujangga_pos/features/riwayat/presentation/pages/detail_transaksi_page.dart';
import 'package:pujangga_pos/features/riwayat/presentation/pages/riwayat_page.dart';
import 'package:pujangga_pos/features/transaksi/presentation/pages/transaksi_berhasil_page.dart';

class _DisposableDatabase extends AppDatabase {
  _DisposableDatabase(this.filePath);
  final String filePath;
  @override
  Future<String> databasePath() async => filePath;
}

// Deterministic fixtures cover each corruption. The host runner also exercises
// the native Android file picker for the invalid-date and current-schema files.
class _FixturePicker extends BackupFilePickerService {
  String? selected;
  bool native = false;
  @override
  Future<String?> pickBackupFile() async {
    if (native) {
      debugPrint('E2E_NATIVE_PICKER: $selected');
      return super.pickBackupFile();
    }
    return selected;
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  WidgetController.hitTestWarningShouldBeFatal = true;
  testWidgets('PR62 rejects corrupt restore and preserves readable business data', (
    tester,
  ) async {
    initializeAppDateFormatting();
    final root = await getTemporaryDirectory();
    // Abort before opening or changing any DB unless this is the test-only APK.
    expect(root.path, contains('/com.pujanggapos.pujangga_pos.pr62e2e/'));
    final directory = await Directory(
      path.join(
        root.path,
        'restore-validation-${DateTime.now().microsecondsSinceEpoch}',
      ),
    ).create();
    var active = _DisposableDatabase(path.join(directory.path, 'active.db'));
    expect(path.isWithin(directory.path, await active.databasePath()), isTrue);
    var db = await active.database();
    final nativePath =
        (await db.rawQuery('PRAGMA database_list'))
                .singleWhere((row) => row['name'] == 'main')['file']
            as String;
    expect(path.isWithin(directory.path, nativePath), isTrue);
    debugPrint('E2E_ISOLATION: native SQLite $nativePath');
    final now = DateTime.now().toIso8601String();
    await db.insert('business_profile', {
      'business_name': 'PR62 Synthetic Shop',
      'business_type': 'retail',
      'created_at': now,
      'updated_at': now,
    });
    await db.insert('items', {
      'name': 'PR62 Kopi',
      'item_type': 'product',
      'sale_price': 10000,
      'harga_modal': 4000,
      'stock_qty': 10,
      'unit': 'Pcs',
      'created_at': now,
      'updated_at': now,
    });
    final picker = _FixturePicker();
    ProviderContainer makeContainer() => ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(active),
        backupFilePickerServiceProvider.overrideWithValue(picker),
      ],
    );
    var container = makeContainer();
    addTearDown(() async {
      container.dispose();
      await active.reset();
      await directory.delete(recursive: true);
      debugPrint('E2E_CLEANUP: test databases and fixtures removed');
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

    Future<void> mount() async {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const PujanggaPosApp(),
        ),
      );
      await tester.pumpAndSettle();
    }

    Future<void> tapText(String label) async {
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

    Future<void> screenshot(String label) async {
      debugPrint('E2E_SCREENSHOT: $label');
      await Future<void>.delayed(const Duration(seconds: 5));
    }

    Future<Map<String, Object?>> snapshot() async => {
      for (final table in [...AppBackupService.backupTables, 'sqlite_sequence'])
        table: await db.query(
          table,
          orderBy: table == 'sqlite_sequence' ? 'name' : 'id',
        ),
    };

    Future<void> settings() async {
      if (find.byType(PengaturanPage).evaluate().isEmpty) {
        await tester.tap(find.byIcon(Icons.menu).first);
        await tester.pumpAndSettle();
      }
      await tester.scrollUntilVisible(
        find.text('Pulihkan Data').first,
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

    Future<void> pick(String file, {bool valid = true}) async {
      picker.selected = file;
      picker.native =
          const bool.fromEnvironment('PR62_NATIVE_PICKER') &&
          (file.endsWith('/invalid-date.json') ||
              file.endsWith('/valid-schema-16.json'));
      await settings();
      await tapText('Pulihkan Data');
      await waitFor(
        () => !container.read(pengaturanRestoreControllerProvider).isLoading,
        'backup inspection completes',
      );
      expect(
        find.text('Pulihkan Data?'),
        valid ? findsOneWidget : findsNothing,
      );
      if (!valid) {
        expect(
          container.read(pengaturanRestoreControllerProvider).hasError,
          isTrue,
        );
        expect(
          find.textContaining('Gagal membaca file backup:'),
          findsOneWidget,
        );
      }
    }

    Future<void> confirm() async {
      await tester.tap(find.widgetWithText(FilledButton, 'Pulihkan Data'));
      await confirmRecoverySnapshot(tester);
      await waitFor(
        () => !container.read(pengaturanRestoreControllerProvider).isLoading,
        'restore completes',
      );
    }

    Future<void> goHomeFromSettings() async {
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(PengaturanPage), findsNothing);
    }

    late String invoice;
    Future<void> historyAndReports() async {
      // Follow the actual home shortcut, then open the transaction detail.
      await waitFor(
        () => find
            .descendant(
              of: find.byType(BerandaPage),
              matching: find.byType(Scrollable),
            )
            .evaluate()
            .isNotEmpty,
        'home data loaded before scrolling',
      );
      await tester.scrollUntilVisible(
        find.text('Lihat Semua'),
        400,
        scrollable: find.byType(Scrollable).first,
      );
      await tapText('Lihat Semua');
      expect(find.byType(RiwayatPage), findsOneWidget);
      final history = await container.read(riwayatControllerProvider.future);
      await tester.pumpAndSettle();
      expect(history.allTransactions, hasLength(1));
      expect(history.allTransactions.single.invoiceNumber, invoice);
      expect(find.textContaining(invoice), findsWidgets);
      await tester.tap(find.textContaining(invoice).last);
      await tester.pumpAndSettle();
      expect(find.byType(DetailTransaksiPage), findsOneWidget);
      expect(find.text('PR62 Kopi'), findsWidgets);
      expect(tester.takeException(), isNull);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tapText('Laporan');
      expect(find.byType(LaporanPage), findsOneWidget);
      final report = await container.read(salesReportSnapshotProvider.future);
      await tester.pumpAndSettle();
      expect(report.revenue, 10000);
      expect(report.transactionCount, 1);
      expect(tester.takeException(), isNull);
      await tapText('Beranda');
      debugPrint(
        'E2E_PASS: history + detail + daily report: 1 sale, revenue=10000',
      );
    }

    await mount();
    // A real UI checkout supplies the backup's transaction, detail and stock.
    await tapText('Transaksi');
    await tapText('PR62 Kopi');
    await tapText('Keranjang');
    await tapText('QRIS');
    await tapText('Proses Pembayaran');
    await waitFor(
      () => find.byType(TransaksiBerhasilPage).evaluate().isNotEmpty,
      'UI checkout receipt',
    );
    invoice =
        (await db.query('sales_transactions')).single['invoice_no'] as String;
    expect((await db.query('items')).single['stock_qty'], 9);
    debugPrint(
      'E2E_PASS: UI checkout wrote one native SQLite sale and stock=9',
    );
    await tapText('Transaksi Baru');
    await tapText('Beranda');
    final backup = await AppBackupService(
      database: active,
      logger: Logger('PR62'),
      backupDirectoryProvider: () async =>
          Directory(path.join(directory.path, 'backup')),
    ).createBackup(password: null);
    final raw = await File(backup.filePath).readAsString();
    final originalDate =
        (jsonDecode(raw)['tables']['sales_transactions'] as List)
            .single['transaction_date'];
    final before = await snapshot();
    final corruptions = <String, void Function(Map<String, dynamic>)>{
      'invalid-date': (p) =>
          p['tables']['sales_transactions'][0]['transaction_date'] =
              'bukan-tanggal',
      'calendar-overflow': (p) =>
          p['tables']['sales_transactions'][0]['transaction_date'] =
              '2026-02-30T12:00:00',
      'unknown-payment': (p) =>
          p['tables']['sales_transactions'][0]['payment_method'] = 'unknown',
      'zero-quantity': (p) =>
          p['tables']['sales_transaction_items'][0]['qty'] = 0,
      'inconsistent-total': (p) =>
          p['tables']['sales_transactions'][0]['total_amount'] = 999,
    };
    for (final corruption in corruptions.entries) {
      final payload = jsonDecode(raw) as Map<String, dynamic>;
      corruption.value(payload);
      final file = File(path.join(directory.path, '${corruption.key}.json'));
      await file.writeAsString(jsonEncode(payload));
      await pick(file.path, valid: false);
      expect(
        await snapshot(),
        before,
        reason: 'all tables and sequences unchanged',
      );
      if (corruption.key == 'invalid-date') {
        await screenshot('01-invalid-date-rejected');
      }
      debugPrint(
        'E2E_PASS: ${corruption.key} rejected in UI; all tables + sequences identical',
      );
    }
    await goHomeFromSettings();
    await historyAndReports();

    // Even a candidate changed after successful inspection is revalidated when
    // the real confirmation button invokes restoreBackup.
    await pick(backup.filePath);
    container
            .read(pengaturanRestoreControllerProvider)
            .requireValue!
            .tables['sales_transactions']!
            .single['transaction_date'] =
        'bukan-tanggal';
    await confirm();
    expect(find.byType(PengaturanPage), findsOneWidget);
    expect(find.textContaining('Gagal memulihkan data:'), findsOneWidget);
    expect(await snapshot(), before);
    await screenshot('02-candidate-revalidated');
    debugPrint(
      'E2E_PASS: tampered candidate rejected at confirmation; data unchanged',
    );
    await goHomeFromSettings();

    // Genuine replacement: distinguish the active profile from the backup.
    for (final schema in [AppConstants.databaseVersion, 12, 13, 14, 15]) {
      final payload = jsonDecode(raw) as Map<String, dynamic>;
      if (schema < AppConstants.databaseVersion) _legacy(payload, schema);
      final file = File(path.join(directory.path, 'valid-schema-$schema.json'));
      await file.writeAsString(jsonEncode(payload));
      await db.update('business_profile', {
        'business_name': 'PR62 Changed Active Shop',
      });
      await pick(file.path);
      await confirm();
      expect(find.byType(PengaturanPage), findsNothing);
      expect(
        find.textContaining('berhasil dipulihkan ke aplikasi.'),
        findsOneWidget,
      );
      expect(
        (await db.query('business_profile')).single['business_name'],
        'PR62 Synthetic Shop',
      );
      expect(
        (await db.query('sales_transactions')).single['transaction_date'],
        originalDate,
      );
      expect((await db.query('items')).single['stock_qty'], 9);
      expect(await db.query('sales_transaction_items'), hasLength(1));
      expect(await db.rawQuery('PRAGMA integrity_check'), [
        {'integrity_check': 'ok'},
      ]);
      expect(await db.rawQuery('PRAGMA foreign_key_check'), isEmpty);
      if (schema < 16) {
        expect(
          (await db.query('sales_transactions')).single['checkout_id'],
          isNull,
        );
      }
      debugPrint(
        'E2E_PASS: UI restored schema $schema, original profile/date, stock=9, integrity OK, FK clean',
      );
      await historyAndReports();
    }
    await screenshot('03-restored-home');

    // Recreate the whole provider tree and reopen the on-disk Android database.
    final persisted = await snapshot();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    container.dispose();
    await db.close();
    active = _DisposableDatabase(await active.databasePath());
    db = await active.database();
    container = makeContainer();
    await mount();
    expect(await snapshot(), persisted);
    await historyAndReports();
    await tapText('Laporan');
    await screenshot('04-reopened-report');
    debugPrint(
      'E2E_PASS: app/provider/database reopen preserved every row; history and report healthy',
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  }, timeout: const Timeout(Duration(minutes: 8)));
}

void _legacy(Map<String, dynamic> payload, int schema) {
  payload['format_version'] = 2;
  payload['database']['schema_version'] = schema;
  final tables = payload['tables'] as Map<String, dynamic>;
  for (final row in tables['sales_transactions'] as List) {
    row.remove('checkout_id');
    if (schema < 14) row.remove('commission_scope_snapshot');
    if (schema < 13) {
      for (final key in [
        'employee_id',
        'employee_name_snapshot',
        'compensation_type_snapshot',
        'commission_percent_snapshot',
        'monthly_salary_snapshot',
        'commission_amount',
      ]) {
        row.remove(key);
      }
    }
  }
  if (schema < 15) {
    tables.remove('employee_compensation_periods');
    payload['table_counts'].remove('employee_compensation_periods');
  }
  if (schema < 13) {
    tables.remove('employees');
    payload['table_counts'].remove('employees');
  }
}
