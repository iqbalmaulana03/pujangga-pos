import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sqflite/sqflite.dart';
import 'package:pujangga_pos/app/app.dart';
import 'package:pujangga_pos/core/database/app_database.dart';
import 'package:pujangga_pos/core/services/app_startup_service.dart';
import 'package:pujangga_pos/core/utils/app_date_formatting.dart';
import 'package:pujangga_pos/core/utils/currency_formatter.dart';
import 'package:pujangga_pos/features/laporan/presentation/controllers/laporan_controller.dart';
import 'package:pujangga_pos/features/laporan/presentation/pages/laporan_page.dart';
import 'package:pujangga_pos/features/pengaturan/presentation/controllers/pengaturan_settings_controller.dart';
import 'package:pujangga_pos/features/pengaturan/presentation/pages/pengaturan_page.dart';
import 'package:pujangga_pos/features/riwayat/presentation/pages/detail_transaksi_page.dart';
import 'package:pujangga_pos/features/transaksi/domain/services/receipt_text_formatter.dart';
import 'package:pujangga_pos/features/transaksi/presentation/controllers/receipt_share_controller.dart';
import 'package:pujangga_pos/features/transaksi/presentation/controllers/transaksi_controller.dart';
import 'package:pujangga_pos/features/transaksi/presentation/pages/transaksi_berhasil_page.dart';

const _locked = 'Mata uang tidak dapat diubah setelah data usaha tercatat.';
const _success = 'Preferensi operasional berhasil diperbarui.';

class _DisposableDatabase extends AppDatabase {
  _DisposableDatabase(this.file);
  final String file;
  @override
  Future<String> databasePath() async => file;
}

class _Harness {
  _Harness(this.tester, this.directory, this.database, this.db);
  final WidgetTester tester;
  final Directory directory;
  _DisposableDatabase database;
  Database db;
  late ProviderContainer container;
  String? sharedText;

  static Future<_Harness> create(WidgetTester tester, String name) async {
    initializeAppDateFormatting();
    final temporary = await getTemporaryDirectory();
    expect(temporary.path, contains('/com.pujanggapos.pujangga_pos.pr83e2e/'));
    final directory = Directory(
      path.join(
        temporary.path,
        'currency-lock-$name-${DateTime.now().microsecondsSinceEpoch}',
      ),
    );
    expect(path.isWithin(temporary.path, directory.path), isTrue);
    await directory.create();
    final database = _DisposableDatabase(
      path.join(directory.path, 'isolated.db'),
    );
    expect(
      path.isWithin(directory.path, await database.databasePath()),
      isTrue,
    );
    debugPrint('E2E_ISOLATION: $name ${await database.databasePath()}');
    final db = await database.database();
    final harness = _Harness(tester, directory, database, db);
    harness.newContainer();
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      harness.container.dispose();
      await harness.db.close();
      expect(path.isWithin(temporary.path, directory.path), isTrue);
      await directory.delete(recursive: true);
      debugPrint('E2E_CLEANUP: $name isolated directory removed');
    });
    final stamp = DateTime.now().toIso8601String();
    await db.insert('business_profile', {
      'business_name': 'PR83 Usaha Sintetis',
      'business_type': 'retail',
      'modal_awal_usaha': 0,
      'created_at': stamp,
      'updated_at': stamp,
    });
    return harness;
  }

  void newContainer() {
    container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        // Observe payload while retaining the actual native Android share plugin.
        receiptShareLauncherProvider.overrideWithValue((params) {
          sharedText = params.text;
          return SharePlus.instance.share(params);
        }),
      ],
    );
  }

  Future<void> mount({bool settingsOnly = true}) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: settingsOnly
            ? const MaterialApp(home: PengaturanPage())
            : const PujanggaPosApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> waitUntil(bool Function() condition) async {
    for (var i = 0; i < 100 && !condition(); i++) {
      await tester.pump(const Duration(milliseconds: 100));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    expect(
      condition(),
      isTrue,
      reason: 'Timed out waiting for Android operation',
    );
  }

  Future<void> clearNotification() async {
    ScaffoldMessenger.of(tester.element(find.byType(Scaffold).last))
        .removeCurrentSnackBar();
    await tester.pumpAndSettle();
  }

  Future<void> tap(String label) async {
    await tester.pumpAndSettle();
    final finder = find.text(label).last;
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> currency(String code, {required bool allowed}) async {
    await clearNotification();
    await tester.scrollUntilVisible(
      find.text('Mata Uang'),
      300,
      scrollable: find
          .descendant(
            of: find.byType(PengaturanPage),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tap('Mata Uang');
    await tap(switch (code) {
      'USD' => r'US Dollar (USD) - $',
      'SGD' => r'Singapore Dollar (SGD) - S$',
      _ => 'Rupiah (IDR) - Rp',
    });
    await waitUntil(
      () => find.text(allowed ? _success : _locked).evaluate().isNotEmpty,
    );
    expect(find.text(allowed ? _locked : _success), findsNothing);
  }

  Future<void> tax() async {
    await clearNotification();
    await tap('Pajak Default');
    await tester.enterText(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextFormField),
      ),
      '11',
    );
    await tap('Simpan');
    await waitUntil(() => find.text(_success).evaluate().isNotEmpty);
    expect((await db.query('app_settings')).single['default_tax_percent'], 11);
    expect(find.text(_locked), findsNothing);
  }

  Future<List<Object>> snapshot() async {
    final tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' ORDER BY name",
    );
    return [
      for (final row in tables)
        await db.query(row['name']! as String, orderBy: 'rowid'),
    ];
  }

  Future<void> screenshot(String label) async {
    debugPrint('E2E_SCREENSHOT: $label');
    await Future<void>.delayed(const Duration(seconds: 2));
  }

  Future<void> reopen({bool settingsOnly = true}) async {
    final file = await database.databasePath();
    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
    await db.close();
    database = _DisposableDatabase(file);
    db = await database.database();
    newContainer();
    await mount(settingsOnly: settingsOnly);
    expect(
      (await db.rawQuery('PRAGMA integrity_check')).single.values.single,
      'ok',
    );
    expect(await db.rawQuery('PRAGMA foreign_key_check'), isEmpty);
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'empty financial dataset selects USD SGD IDR through settings and reopens',
    (tester) async {
      final h = await _Harness.create(tester, 'empty');
      await h.mount();
      for (final code in ['USD', 'SGD', 'IDR']) {
        await h.currency(code, allowed: true);
        expect(
          (await h.db.query('app_settings')).single['currency_code'],
          code,
        );
        expect(
          (await h.container.read(appSettingsProvider.future)).currencyCode,
          code,
        );
      }
      await h.currency('USD', allowed: true);
      await h.screenshot('01-empty-usd-success');
      await h.reopen();
      expect((await h.db.query('app_settings')).single['currency_code'], 'USD');
      expect(CurrencyFormatter.symbol, r'$');
      await h.tax();
      expect((await h.db.query('app_settings')).single['currency_code'], 'USD');
      debugPrint(
        'E2E_PASS: empty dataset currency selection persisted across reopen; tax allowed',
      );
    },
  );

  for (final blocker in [
    'inactive-item',
    'sale-only',
    'expense-only',
    'capital-history',
    'initial-capital',
  ]) {
    testWidgets('$blocker independently rejects currency and allows tax', (
      tester,
    ) async {
      final h = await _Harness.create(tester, blocker);
      final stamp = DateTime.now().toIso8601String();
      switch (blocker) {
        case 'inactive-item':
          await h.db.insert('items', {
            'name': 'PR83 Nonaktif',
            'item_type': 'service',
            'sale_price': 0,
            'is_active': 0,
            'created_at': stamp,
            'updated_at': stamp,
          });
        case 'sale-only':
          await h.db.insert('sales_transactions', {
            'invoice_no': 'PR83-VOID',
            'transaction_date': stamp,
            'total_amount': 100000,
            'payment_method': 'tunai',
            'status': 'voided',
            'created_at': stamp,
            'updated_at': stamp,
          });
        case 'expense-only':
          await h.db.insert('expenses', {
            'amount': 5000,
            'category': 'Operasional',
            'expense_date': stamp,
            'created_at': stamp,
            'updated_at': stamp,
          });
        case 'capital-history':
          await h.db.insert('capital_history', {
            'amount': 100000,
            'created_at': stamp,
          });
        case 'initial-capital':
          await h.db.update('business_profile', {'modal_awal_usaha': 100000});
      }
      await h.mount();
      final before = await h.snapshot();
      await h.currency('USD', allowed: false);
      expect(await h.snapshot(), before);
      expect(CurrencyFormatter.symbol, 'Rp');
      await h.screenshot('02-$blocker-locked');
      await h.tax();
      expect((await h.db.query('app_settings')).single['currency_code'], 'IDR');
      await h.reopen();
      await h.currency('SGD', allowed: false);
      expect(
        (await h.db.query('app_settings')).single['default_tax_percent'],
        11,
      );
      debugPrint(
        'E2E_PASS: $blocker independently locked; all tables unchanged on rejection; tax saved; lock survives reopen',
      );
    });
  }

  testWidgets(
    'IDR 100000 checkout history reports native receipt share and reopen retain denomination',
    (tester) async {
      final h = await _Harness.create(tester, 'historical-sale');
      final stamp = DateTime.now().toIso8601String();
      await h.db.insert('items', {
        'name': 'PR83 Jasa Uji',
        'item_type': 'service',
        'sale_price': 100000,
        'biaya_dasar': 40000,
        'created_at': stamp,
        'updated_at': stamp,
      });
      await h.mount(settingsOnly: false);
      await h.tap('Transaksi');
      await h.tap('PR83 Jasa Uji');
      await h.tap('Keranjang');
      expect(
        h.container.read(transaksiControllerProvider).requireValue.totalAmount,
        100000,
      );
      await h.tap('QRIS');
      await h.tap('Proses Pembayaran');
      await h.waitUntil(
        () => find.byType(TransaksiBerhasilPage).evaluate().isNotEmpty,
      );
      final sales = await h.db.query('sales_transactions');
      expect(sales, hasLength(1));
      expect(sales.single['total_amount'], 100000);
      final invoice = sales.single['invoice_no']! as String;
      final receipt = (await h.container
          .read(transactionRepositoryProvider)
          .getReceiptByInvoice(invoice))!;
      final profile = await h.container.read(businessProfileProvider.future);
      final receiptBefore = const ReceiptTextFormatter().format(
        receipt,
        profile,
      );
      expect(receiptBefore, contains('Rp'));
      final money = CurrencyFormatter.format(100000);
      expect(find.text(money), findsWidgets);
      await h.screenshot('03-checkout-idr100000');
      await h.tap('Transaksi Baru');
      await h.tap('Laporan');
      await h.waitUntil(
        () => find.text('Total Pendapatan').evaluate().isNotEmpty,
      );
      final reportBefore = await h.container.read(
        salesReportSnapshotProvider.future,
      );
      expect(reportBefore.revenue, 100000);
      expect(find.text(money), findsWidgets);
      await h.screenshot('04-report-before');
      await tester.tap(find.byIcon(Icons.menu).first);
      await tester.pumpAndSettle();
      final before = await h.snapshot();
      await h.currency('USD', allowed: false);
      expect(await h.snapshot(), before);
      expect(CurrencyFormatter.symbol, 'Rp');
      await h.screenshot('05-historical-currency-rejected');
      await h.tax();
      await h.clearNotification();
      GoRouter.of(tester.element(find.byType(PengaturanPage)))
          .go('/history/$invoice');
      await tester.pumpAndSettle();
      expect(find.byType(DetailTransaksiPage), findsOneWidget);
      expect(find.text(money), findsWidgets);
      await h.screenshot('06-history-detail-idr');
      GoRouter.of(tester.element(find.byType(DetailTransaksiPage)))
          .go('/reports');
      await tester.pumpAndSettle();
      final reportAfter = await h.container.read(
        salesReportSnapshotProvider.future,
      );
      expect(reportAfter.revenue, reportBefore.revenue);
      expect(reportAfter.margin, reportBefore.margin);
      expect(find.text(money), findsWidgets);
      await h.screenshot('07-report-after');
      GoRouter.of(tester.element(find.byType(LaporanPage)))
          .go('/transaction/success/$invoice');
      await tester.pumpAndSettle();
      final shareBefore = await h.snapshot();
      await h.tap('Bagikan Struk');
      debugPrint('E2E_SHARE_OPEN');
      await h.waitUntil(
        () => !h.container.read(receiptShareControllerProvider),
      );
      expect(h.sharedText, receiptBefore);
      expect(h.sharedText, isNot(contains(r'$')));
      expect(await h.snapshot(), shareBefore);
      await h.screenshot('08-native-share-cancelled');
      await h.reopen(settingsOnly: false);
      expect(
        (await h.container.read(appSettingsProvider.future)).currencyCode,
        'IDR',
      );
      expect(
        (await h.db.query('app_settings')).single['default_tax_percent'],
        11,
      );
      expect(await h.db.query('sales_transactions'), sales);
      final reopenedReceipt = (await h.container
          .read(transactionRepositoryProvider)
          .getReceiptByInvoice(invoice))!;
      expect(
        const ReceiptTextFormatter().format(
          reopenedReceipt,
          await h.container.read(businessProfileProvider.future),
        ),
        receiptBefore,
      );
      await h.tap('Laporan');
      expect(
        (await h.container.read(salesReportSnapshotProvider.future)).revenue,
        100000,
      );
      expect(find.text(money), findsWidgets);
      await h.screenshot('09-reopened-report-idr');
      expect(tester.takeException(), isNull);
      debugPrint(
        'E2E_PASS: real IDR 100000 checkout; failed USD change; unchanged history/report/shared payload; native Sharesheet cancelled; reopen persistence and SQLite integrity verified',
      );
    },
  );
}
