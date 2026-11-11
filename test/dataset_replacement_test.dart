@Timeout(Duration(minutes: 2))
library;

import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:pujangga_pos/core/constants/app_constants.dart';
import 'package:pujangga_pos/core/database/app_database.dart';
import 'package:pujangga_pos/core/services/app_startup_service.dart';
import 'package:pujangga_pos/core/services/business_logo_service.dart';
import 'package:pujangga_pos/features/karyawan/data/repositories/employee_repository.dart';
import 'package:pujangga_pos/features/karyawan/presentation/controllers/employee_controller.dart';
import 'package:pujangga_pos/features/katalog/presentation/controllers/katalog_controller.dart';
import 'package:pujangga_pos/features/pengaturan/data/services/app_backup_service.dart';
import 'package:pujangga_pos/features/pengaturan/data/services/app_recovery_service.dart';
import 'package:pujangga_pos/features/pengaturan/presentation/controllers/app_recovery_provider.dart';
import 'package:pujangga_pos/features/pengaturan/presentation/controllers/pengaturan_backup_controller.dart';
import 'package:pujangga_pos/features/pengaturan/domain/entities/app_backup_restore_candidate.dart';
import 'package:pujangga_pos/features/pengaturan/presentation/controllers/pengaturan_reset_controller.dart';
import 'package:pujangga_pos/features/pengaturan/presentation/controllers/pengaturan_restore_controller.dart';
import 'package:pujangga_pos/features/setup_usaha/domain/entities/business_profile.dart';
import 'package:pujangga_pos/features/setup_usaha/presentation/controllers/setup_usaha_controller.dart';
import 'package:pujangga_pos/features/transaksi/presentation/controllers/transaksi_controller.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Directory directory;
  late AppDatabase database;
  late ProviderContainer container;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    // All services share this disposable database and isolated asset directory.
    directory = await Directory.systemTemp.createTemp('pujangga_dataset_');
    await databaseFactory.setDatabasesPath(directory.path);
    database = AppDatabase();
    expect(await database.databasePath(), startsWith(directory.path));
    container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        appRecoveryServiceProvider.overrideWith(
          (ref) => AppRecoveryService(
            backup: ref.watch(appBackupServiceProvider),
            restore: ref.watch(appRestoreServiceProvider),
            reset: ref.watch(appResetServiceProvider),
            directoryProvider: () async =>
                Directory('${directory.path}/recovery'),
            exportDirectoryProvider: () async =>
                Directory('${directory.path}/exports'),
            temporaryDirectoryProvider: () async =>
                Directory('${directory.path}/cache'),
          ),
        ),
        appLoggerProvider.overrideWithValue(Logger('DatasetReplacementTest')),
        businessLogoServiceProvider.overrideWithValue(
          BusinessLogoService(
            supportDirectory: () async => directory,
            temporaryDirectory: () async => directory,
          ),
        ),
      ],
    );
    await container
        .read(employeeRepositoryProvider)
        .save(
          name: 'Andi',
          isActive: true,
          compensationType: 'commission',
          commissionPercent: 10,
          effectiveFrom: DateTime(2026),
        );
    final db = await database.database();
    final stamp = DateTime.now().toIso8601String();
    final category = await db.insert('categories', {
      'name': 'Jasa',
      'item_type': 'service',
      'created_at': stamp,
      'updated_at': stamp,
    });
    await db.insert('items', {
      'category_id': category,
      'name': 'Layanan A',
      'item_type': 'service',
      'sale_price': 100000,
      'stock_qty': 0,
      'is_active': 1,
      'created_at': stamp,
      'updated_at': stamp,
    });
    // Keep caches/drafts alive across restore/reset, as a live ProviderScope does.
    container.listen(activeEmployeesProvider, (_, _) {});
    container.listen(employeesProvider, (_, _) {});
    container.listen(transaksiControllerProvider, (_, _) {});
    container.listen(katalogControllerProvider, (_, _) {});
    await container.read(employeesProvider.future);
    final ready = await container.read(transaksiControllerProvider.future);
    await container.read(katalogControllerProvider.future);
    expect(
      (await container.read(activeEmployeesProvider.future)).single.name,
      'Andi',
    );
    final controller = container.read(transaksiControllerProvider.notifier);
    controller.addItem(ready.catalogItems.single);
    controller.updateEmployee(1);
    controller.updatePaymentMethod('qris');
  });

  tearDown(() async {
    container.dispose();
    await database.reset();
    // Only the directory created by this test is removed.
    await directory.delete(recursive: true);
  });

  Future<AppBackupRestoreCandidate> replacement({
    bool includeEmployee = true,
  }) async {
    final db = await database.database();
    final tables = <String, List<Map<String, Object?>>>{};
    for (final table in AppBackupService.backupTables) {
      tables[table] = [
        for (final row in await db.query(table)) {...row},
      ];
    }
    if (includeEmployee) {
      tables['employees']!.single['name'] = 'Budi';
      tables['employees']!.single['commission_percent'] = 20.0;
      tables['employee_compensation_periods']!.single['employee_name'] = 'Budi';
    } else {
      tables['employees'] = [];
      tables['employee_compensation_periods'] = [];
    }
    tables['items']!.single['name'] = 'Layanan B';
    return AppBackupRestoreCandidate(
      filePath: 'disposable-backup.json',
      fileName: 'disposable-backup.json',
      generatedAt: DateTime.now(),
      schemaVersion: AppConstants.databaseVersion,
      recordCounts: {
        for (final entry in tables.entries) entry.key: entry.value.length,
      },
      tables: tables,
    );
  }

  test(
    'restore replaces cached identity and commission, and clears old checkout',
    () async {
      final candidate = await replacement();
      await container
          .read(pengaturanRestoreControllerProvider.notifier)
          .restoreBackup(candidate, recoveryPassword: 'synthetic password 56');
      expect(
        container.read(pengaturanRestoreControllerProvider).hasError,
        isFalse,
      );
      final active = await container.read(activeEmployeesProvider.future);
      expect(active.single.id, 1);
      expect(active.single.name, 'Budi');
      expect(active.single.commissionPercent, 20);
      expect(
        (await container.read(employeesProvider.future)).single.name,
        'Budi',
      );
      final cart = await container.read(transaksiControllerProvider.future);
      expect(cart.employeeId, isNull);
      expect(cart.cartItems, isEmpty);
      expect(cart.catalogItems.single.name, 'Layanan B');
      expect(
        (await container.read(katalogControllerProvider.future))
            .allItems
            .single
            .name,
        'Layanan B',
      );
      final controller = container.read(transaksiControllerProvider.notifier);
      controller.addItem(cart.catalogItems.single);
      controller.updatePaymentMethod('qris');
      final unassigned = await controller.submit();
      expect(unassigned.employeeName, isNull);
      controller.addItem(cart.catalogItems.single);
      controller.updatePaymentMethod('qris');
      controller.updateEmployee(active.single.id);
      final receipt = await controller.submit();
      expect(receipt.employeeName, 'Budi');
      expect(receipt.commissionPercent, 20);
      expect(receipt.commissionAmount, 20000);
    },
  );

  test(
    'restore without employees removes stale choices and selection',
    () async {
      await container
          .read(pengaturanRestoreControllerProvider.notifier)
          .restoreBackup(
            await replacement(includeEmployee: false),
            recoveryPassword: 'synthetic password 56',
          );
      expect(
        container.read(pengaturanRestoreControllerProvider).hasError,
        isFalse,
      );
      expect(await container.read(activeEmployeesProvider.future), isEmpty);
      expect(await container.read(employeesProvider.future), isEmpty);
      expect(
        (await container.read(transaksiControllerProvider.future)).employeeId,
        isNull,
      );
    },
  );

  test(
    'reset and setup in the same container leave no previous employee',
    () async {
      await container
          .read(pengaturanResetControllerProvider.notifier)
          .resetAppData();
      expect(
        container.read(pengaturanResetControllerProvider).hasError,
        isFalse,
      );
      await container
          .read(setupUsahaControllerProvider.notifier)
          .submit(
            businessProfile: const BusinessProfile(
              businessName: 'Usaha Baru',
              businessType: 'retail',
            ),
          );
      expect(
        (await container.read(appStartupProvider.future)).hasBusinessProfile,
        isTrue,
      );
      expect(await container.read(activeEmployeesProvider.future), isEmpty);
      expect(await container.read(employeesProvider.future), isEmpty);
      final cart = await container.read(transaksiControllerProvider.future);
      expect(cart.employeeId, isNull);
      expect(cart.cartItems, isEmpty);
      expect(cart.catalogItems, isEmpty);
      expect(
        (await container.read(katalogControllerProvider.future)).allItems,
        isEmpty,
      );
    },
  );
}
