import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:pujangga_pos/app/app.dart';
import 'package:pujangga_pos/core/errors/app_exception.dart';
import 'package:pujangga_pos/core/database/app_database.dart';
import 'package:pujangga_pos/core/services/app_startup_service.dart';
import 'package:pujangga_pos/core/utils/app_date_formatting.dart';
import 'package:pujangga_pos/features/beranda/presentation/pages/beranda_page.dart';
import 'package:pujangga_pos/features/laporan/presentation/controllers/laporan_controller.dart';
import 'package:pujangga_pos/features/laporan/presentation/pages/laporan_page.dart';
import 'package:pujangga_pos/features/pengaturan/data/services/app_backup_service.dart';
import 'package:pujangga_pos/features/pengaturan/data/services/backup_input_limits.dart';
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

// Native Android selection covers the oversized input and exact-limit valid
// control. Other adversarial fixtures use the same UI with a deterministic picker.
class _FixturePicker extends BackupFilePickerService {
  String? selected;
  bool native = false;
  void Function()? onPicked;
  @override
  Future<String?> pickBackupFile() async {
    if (native) {
      debugPrint('E2E_NATIVE_PICKER: $selected');
      final result = await super.pickBackupFile();
      onPicked?.call();
      return result;
    }
    onPicked?.call();
    return selected;
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  WidgetController.hitTestWarningShouldBeFatal = true;
  testWidgets(
    'PR64 enforces restore budgets without blocking Android UI or changing data',
    (tester) async {
      initializeAppDateFormatting();
      final root = await getTemporaryDirectory();
      // Abort before opening or changing any DB unless this is the test-only APK.
      expect(root.path, contains('/com.pujanggapos.pujangga_pos.pr64e2e/'));
      final directory = await Directory(
        path.join(
          root.path,
          'restore-limits-${DateTime.now().microsecondsSinceEpoch}',
        ),
      ).create();
      var active = _DisposableDatabase(path.join(directory.path, 'active.db'));
      expect(
        path.isWithin(directory.path, await active.databasePath()),
        isTrue,
      );
      var db = await active.database();
      final nativePath =
          (await db.rawQuery('PRAGMA database_list'))
                  .singleWhere((row) => row['name'] == 'main')['file']
              as String;
      expect(path.isWithin(directory.path, nativePath), isTrue);
      debugPrint('E2E_ISOLATION: native SQLite $nativePath');
      final now = DateTime.now().toIso8601String();
      await db.insert('business_profile', {
        'business_name': 'PR64 Synthetic Shop',
        'business_type': 'retail',
        'created_at': now,
        'updated_at': now,
      });
      await db.insert('items', {
        'name': 'PR64 Kopi',
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
        for (final table in [
          ...AppBackupService.backupTables,
          'sqlite_sequence',
        ])
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
            const bool.fromEnvironment('PR64_NATIVE_PICKER') &&
            (file.endsWith('/limit-bytes.json') ||
                file.endsWith('/valid-large.json'));
        await settings();
        final probe = _InspectionProbe();
        picker.onPicked = probe.start;
        final subscription = container.listen(
          pengaturanRestoreControllerProvider,
          (_, next) {
            if (probe.running && !next.isLoading) probe.stop();
          },
        );
        debugPrint('E2E_MEASURE_START: ${path.basename(file)}');
        try {
          await tapText('Pulihkan Data');
          await waitFor(
            () =>
                !container.read(pengaturanRestoreControllerProvider).isLoading,
            'backup inspection completes',
          );
        } finally {
          probe.stop();
          subscription.close();
          picker.onPicked = null;
        }
        debugPrint(
          'E2E_METRICS: ${jsonEncode({'file': path.basename(file), ...probe.metrics})}',
        );
        // Check real main-isolate timer continuity during the service operation,
        // excluding native picker interaction and database restore.
        expect(probe.maxGap.inMilliseconds, lessThan(250));
        if (file.endsWith('/valid-large.json')) {
          expect(probe.ticks, greaterThan(3));
          expect(probe.frameCount, greaterThan(0));
        }
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
        expect(find.text('PR64 Kopi'), findsWidgets);
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
      await tapText('PR64 Kopi');
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
        logger: Logger('PR64'),
        backupDirectoryProvider: () async =>
            Directory(path.join(directory.path, 'backup')),
      ).createBackup();
      final raw = await File(backup.filePath).readAsString();
      final originalDate =
          (jsonDecode(raw)['tables']['sales_transactions'] as List)
              .single['transaction_date'];
      final before = await snapshot();
      final fixtures = <String, String>{
        'limit-bytes': '{}${' ' * (BackupInputLimits.maxBytes - 1)}',
        'limit-depth': '{"x":${'[' * 100000}0${']' * 100000}}',
        'limit-string': jsonEncode({
          'x': 'a' * (BackupInputLimits.maxStringLength + 1),
        }),
        'limit-rows':
            '{"tables":{"a":[${'{},' * BackupInputLimits.maxRows}{}]}}',
        'limit-complexity':
            '{"x":[${'0,' * (BackupInputLimits.maxTokens ~/ 2)}0]}',
      };
      for (final fixture in fixtures.entries) {
        final file = File(path.join(directory.path, '${fixture.key}.json'));
        await file.writeAsString(fixture.value);
        await pick(file.path, valid: false);
        final error = container.read(pengaturanRestoreControllerProvider).error;
        expect(
          error,
          isA<AppException>().having(
            (e) => e.code,
            'code',
            'backup_limit_exceeded',
          ),
        );
        expect(
          await snapshot(),
          before,
          reason: 'all tables and sequences unchanged',
        );
        expect(find.textContaining('melebihi batas'), findsOneWidget);
        if (fixture.key == 'limit-bytes') {
          await screenshot('01-byte-limit-rejected');
        }
        debugPrint(
          'E2E_PASS: ${fixture.key} rejected in UI; all tables + sequences identical; bytes=${await file.length()}',
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

      // A substantial valid dataset plus bounded metadata fills the exact byte
      // budget. This exercises decoding, 5,001 row normalizations and validation,
      // not only whitespace scanning. Metadata is ignored by the backup format.
      final payload = jsonDecode(raw) as Map<String, dynamic>;
      final items = payload['tables']['items'] as List;
      final original = Map<String, dynamic>.from(items.single as Map);
      for (var i = 2; i <= 5001; i++) {
        items.add({
          ...original,
          'id': i,
          'name': 'PR64 Synthetic Item $i',
          'stock_qty': 0,
        });
      }
      payload['table_counts']['items'] = items.length;
      payload['e2e_metadata'] = List.filled(240, 'a' * 65536);
      final largeRaw = jsonEncode(payload);
      final padding = BackupInputLimits.maxBytes - utf8.encode(largeRaw).length;
      expect(padding, greaterThanOrEqualTo(0));
      final largeFile = File(path.join(directory.path, 'valid-large.json'));
      await largeFile.writeAsString('$largeRaw${' ' * padding}');
      expect(await largeFile.length(), BackupInputLimits.maxBytes);
      await db.update('business_profile', {
        'business_name': 'PR64 Changed Active Shop',
      });
      await pick(largeFile.path);
      expect(await db.query('items'), hasLength(1));
      expect(
        (await db.query('business_profile')).single['business_name'],
        'PR64 Changed Active Shop',
      );
      await screenshot('02-valid-large-confirmation');
      await confirm();
      expect(find.byType(PengaturanPage), findsNothing);
      expect(
        (await db.query('business_profile')).single['business_name'],
        'PR64 Synthetic Shop',
      );
      expect(
        (await db.query('sales_transactions')).single['transaction_date'],
        originalDate,
      );
      expect(await db.query('items'), hasLength(5001));
      expect((await db.query('items', where: 'id = 1')).single['stock_qty'], 9);
      expect(await db.rawQuery('PRAGMA integrity_check'), [
        {'integrity_check': 'ok'},
      ]);
      expect(await db.rawQuery('PRAGMA foreign_key_check'), isEmpty);
      debugPrint(
        'E2E_PASS: exact 20 MiB backup restored through UI: 5001 items, 1 sale, integrity OK, FK clean',
      );
      await historyAndReports();
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
    },
    timeout: const Timeout(Duration(minutes: 8)),
  );
}

class _InspectionProbe {
  bool running = false;
  int ticks = 0;
  int frameCount = 0;
  int worstBuildMicros = 0;
  int worstRasterMicros = 0;
  Duration maxGap = Duration.zero;
  Duration previous = Duration.zero;
  final watch = Stopwatch();
  Timer? timer;

  void _timings(List<ui.FrameTiming> timings) {
    for (final frame in timings) {
      frameCount++;
      if (frame.buildDuration.inMicroseconds > worstBuildMicros) {
        worstBuildMicros = frame.buildDuration.inMicroseconds;
      }
      if (frame.rasterDuration.inMicroseconds > worstRasterMicros) {
        worstRasterMicros = frame.rasterDuration.inMicroseconds;
      }
    }
  }

  void start() {
    running = true;
    watch.start();
    SchedulerBinding.instance.addTimingsCallback(_timings);
    timer = Timer.periodic(const Duration(milliseconds: 10), (_) {
      final now = watch.elapsed;
      final gap = now - previous;
      if (gap > maxGap) maxGap = gap;
      previous = now;
      ticks++;
    });
  }

  void stop() {
    if (!running) return;
    final gap = watch.elapsed - previous;
    if (gap > maxGap) maxGap = gap;
    running = false;
    watch.stop();
    timer?.cancel();
    SchedulerBinding.instance.removeTimingsCallback(_timings);
  }

  Map<String, Object> get metrics => {
    'elapsed_ms': watch.elapsedMilliseconds,
    'timer_ticks': ticks,
    'max_timer_gap_ms': maxGap.inMilliseconds,
    'frame_count': frameCount,
    'worst_build_us': worstBuildMicros,
    'worst_raster_us': worstRasterMicros,
  };
}
