import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:pujangga_pos/core/database/app_database.dart';
import 'package:pujangga_pos/core/errors/app_exception.dart';
import 'package:pujangga_pos/core/services/app_startup_service.dart';
import 'package:pujangga_pos/core/utils/currency_formatter.dart';
import 'package:pujangga_pos/features/laporan/data/datasources/report_local_data_source.dart';
import 'package:pujangga_pos/features/pengaturan/data/datasources/app_settings_local_data_source.dart';
import 'package:pujangga_pos/features/pengaturan/data/models/app_settings_db_model.dart';
import 'package:pujangga_pos/features/pengaturan/domain/entities/app_settings.dart';
import 'package:pujangga_pos/features/pengaturan/presentation/controllers/app_recovery_provider.dart';
import 'package:pujangga_pos/features/pengaturan/presentation/controllers/pengaturan_settings_controller.dart';
import 'package:pujangga_pos/features/pengaturan/presentation/pages/pengaturan_page.dart';
import 'package:pujangga_pos/features/transaksi/domain/entities/transaksi_receipt.dart';
import 'package:pujangga_pos/features/transaksi/domain/services/receipt_text_formatter.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

// Use the real application schema, but never resolve a device database path.
class _MemoryDatabase extends AppDatabase {
  @override
  Future<String> databasePath() async => inMemoryDatabasePath;
}

AppSettings _settings(String code, {double tax = 0}) => AppSettings(
  currencyCode: code,
  currencySymbol: switch (code) {
    'USD' => r'$',
    'SGD' => r'S$',
    _ => 'Rp',
  },
  defaultTaxPercent: tax,
  stockAllowNegative: tax != 0,
  autoPrintReceipt: tax == 0,
  receiptHeader: tax == 0 ? null : 'Header baru',
  receiptFooter: tax == 0 ? null : 'Footer baru',
);

void main() {
  late _MemoryDatabase database;
  late Database db;
  late AppSettingsLocalDataSource source;
  const stamp = '2026-11-18T12:00:00.000';
  const lockedMessage =
      'Mata uang tidak dapat diubah setelah data usaha tercatat.';
  final locked = isA<AppException>().having(
    (error) => error.code,
    'code',
    'currency_locked',
  );

  Future<void> save(String code, {double tax = 0}) => source.saveSettings(
    AppSettingsDbModel.fromEntity(_settings(code, tax: tax)),
  );

  Future<void> addProfile(num? capital) async {
    await db.insert('business_profile', {
      'business_name': 'Usaha uji',
      'business_type': 'Toko',
      'modal_awal_usaha': capital,
      'created_at': stamp,
      'updated_at': stamp,
    });
  }

  Future<void> addSale({String status = 'completed'}) async {
    await db.insert('sales_transactions', {
      'invoice_no': 'LOCK-TEST',
      'transaction_date': stamp,
      'subtotal_amount': 100000,
      'total_amount': 100000,
      'payment_method': 'tunai',
      'status': status,
      'created_at': stamp,
      'updated_at': stamp,
    });
  }

  ProviderContainer container() {
    final result = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(database)],
    );
    addTearDown(result.dispose);
    return result;
  }

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    await initializeDateFormatting('id_ID');
  });

  setUp(() async {
    database = _MemoryDatabase();
    expect(await database.databasePath(), inMemoryDatabasePath);
    db = await database.database();
    expect(db.path, inMemoryDatabasePath);
    source = AppSettingsLocalDataSource(database: database);
    CurrencyFormatter.configure(currencyCode: 'IDR', currencySymbol: 'Rp');
  });

  tearDown(() async {
    await db.close();
    CurrencyFormatter.configure(currencyCode: 'IDR', currencySymbol: 'Rp');
  });

  test('empty dataset permits all supported currencies', () async {
    for (final code in ['USD', 'SGD', 'IDR']) {
      await save(code);
      expect((await source.getSettings())!.currencyCode, code);
    }
  });

  for (final capital in [null, 0]) {
    test('profile with capital $capital does not lock currency', () async {
      await addProfile(capital);
      await save('USD');
      expect((await source.getSettings())!.currencyCode, 'USD');
    });
  }

  final blockers = <String, Future<void> Function()>{
    'inactive item': () async {
      await db.insert('items', {
        'name': 'Item nonaktif',
        'item_type': 'service',
        'sale_price': 0,
        'is_active': 0,
        'created_at': stamp,
        'updated_at': stamp,
      });
    },
    'completed sale': () => addSale(),
    'voided sale': () => addSale(status: 'voided'),
    'expense': () async {
      await db.insert('expenses', {
        'amount': 0,
        'category': 'Operasional',
        'expense_date': stamp,
        'created_at': stamp,
        'updated_at': stamp,
      });
    },
    'capital history with zero current capital': () async {
      await addProfile(0);
      await db.insert('capital_history', {'amount': 0, 'created_at': stamp});
    },
    'initial capital': () => addProfile(100000),
    'negative legacy capital': () => addProfile(-1),
  };
  for (final blocker in blockers.entries) {
    test('${blocker.key} locks currency and preserves all settings', () async {
      await blocker.value();
      final before = await db.query('app_settings');
      await expectLater(save('USD', tax: 11), throwsA(locked));
      expect(await db.query('app_settings'), before);
      // Same-code updates must still save every unrelated preference.
      await save('IDR', tax: 11);
      final stored = (await source.getSettings())!;
      expect(stored.currencyCode, 'IDR');
      expect(stored.defaultTaxPercent, 11);
      expect(stored.stockAllowNegative, isTrue);
      expect(stored.autoPrintReceipt, isFalse);
      expect(stored.receiptHeader, 'Header baru');
      expect(stored.receiptFooter, 'Footer baru');
    });
  }

  test('missing settings uses IDR default and guards inserts', () async {
    await db.delete('app_settings');
    await save('USD');
    expect((await source.getSettings())!.currencyCode, 'USD');
    await db.delete('app_settings');
    await addSale();
    await expectLater(save('USD'), throwsA(locked));
    expect(await db.query('app_settings'), isEmpty);
    await save('IDR', tax: 11);
    expect((await source.getSettings())!.defaultTaxPercent, 11);
  });

  test('lock also protects datasets originally recorded in USD', () async {
    await save('USD');
    await addSale();
    await expectLater(save('IDR'), throwsA(locked));
    await expectLater(save('SGD'), throwsA(locked));
    await save('USD', tax: 11);
    expect((await source.getSettings())!.currencyCode, 'USD');
  });

  test(
    'controller propagates failure without changing historical output',
    () async {
      await addSale();
      final ref = container();
      await ref.read(appSettingsProvider.future);
      await ref.read(pengaturanSettingsControllerProvider.future);
      final controller = ref.read(
        pengaturanSettingsControllerProvider.notifier,
      );
      final receipt = TransaksiReceipt(
        invoiceNumber: 'LOCK-TEST',
        createdAt: DateTime.parse(stamp),
        paymentMethod: 'tunai',
        subtotalAmount: 100000,
        itemDiscountAmount: 0,
        orderDiscountAmount: 0,
        taxAmount: 0,
        totalAmount: 100000,
        changeAmount: 0,
        items: const [],
      );
      const formatter = ReceiptTextFormatter();
      final receiptBefore = formatter.format(receipt, null);
      final reports = ReportLocalDataSource(database: database);
      final start = DateTime(2026, 11, 18);
      final end = start.add(const Duration(days: 1));
      final revenueBefore = await reports.getRevenueForRange(start, end);
      expect(revenueBefore, 100000);
      final reportBefore = CurrencyFormatter.format(revenueBefore);

      await expectLater(controller.save(_settings('USD')), throwsA(locked));
      expect(ref.read(pengaturanSettingsControllerProvider).hasError, isTrue);
      expect((await ref.read(appSettingsProvider.future)).currencyCode, 'IDR');
      expect(CurrencyFormatter.symbol, 'Rp');
      expect(formatter.format(receipt, null), receiptBefore);
      final revenueAfter = await reports.getRevenueForRange(start, end);
      expect(revenueAfter, revenueBefore);
      expect(CurrencyFormatter.format(revenueAfter), reportBefore);

      await controller.save(_settings('IDR', tax: 11));
      expect(ref.read(pengaturanSettingsControllerProvider).hasError, isFalse);
      expect(
        (await ref.read(appSettingsProvider.future)).defaultTaxPercent,
        11,
      );
    },
  );

  test('successful controller save persists and refreshes currency', () async {
    final ref = container();
    await ref.read(appSettingsProvider.future);
    await ref.read(pengaturanSettingsControllerProvider.future);
    await ref
        .read(pengaturanSettingsControllerProvider.notifier)
        .save(_settings('SGD'));
    expect(ref.read(pengaturanSettingsControllerProvider).hasError, isFalse);
    expect((await ref.read(appSettingsProvider.future)).currencyCode, 'SGD');
    expect(CurrencyFormatter.symbol, r'S$');
    expect((await source.getSettings())!.currencyCode, 'SGD');
  });

  for (final hasData in [true, false]) {
    testWidgets(
      'currency dialog reports ${hasData ? 'failure' : 'success'} honestly',
      (tester) async {
        if (hasData) {
          // FFI runs outside the widget fake clock.
          await tester.runAsync(() => addSale());
        }
        final ref = container();
        await tester.runAsync(() async {
          await ref.read(appSettingsProvider.future);
          await ref.read(pengaturanSettingsControllerProvider.future);
        });
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: ref,
            child: ProviderScope(
              overrides: [
                businessProfileProvider.overrideWith((ref) async => null),
                recoverySnapshotsProvider.overrideWith((ref) async => []),
              ],
              child: const MaterialApp(home: PengaturanPage()),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(find.text('Mata Uang'), 300);
        await tester.tap(find.text('Mata Uang'));
        await tester.pumpAndSettle();
        await tester.runAsync(() async {
          await tester.tap(find.text(r'US Dollar (USD) - $'));
          // Wait on the actual controller operation rather than a timer.
          await ref
              .read(pengaturanSettingsControllerProvider.future)
              .catchError((Object _) {});
        });
        await tester.pumpAndSettle();
        const success = 'Preferensi operasional berhasil diperbarui.';
        expect(
          find.text(lockedMessage),
          hasData ? findsOneWidget : findsNothing,
        );
        expect(find.text(success), hasData ? findsNothing : findsOneWidget);
        expect(
          (await tester.runAsync(source.getSettings))!.currencyCode,
          hasData ? 'IDR' : 'USD',
        );
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
