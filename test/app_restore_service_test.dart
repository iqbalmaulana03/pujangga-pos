import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as path;
import 'package:pujangga_pos/core/constants/app_constants.dart';
import 'package:pujangga_pos/core/database/app_database.dart';
import 'package:pujangga_pos/core/errors/app_exception.dart';
import 'package:pujangga_pos/features/pengaturan/data/services/app_backup_payload_builder.dart';
import 'package:pujangga_pos/features/pengaturan/data/services/app_backup_service.dart';
import 'package:pujangga_pos/features/pengaturan/data/services/app_restore_service.dart';
import 'package:pujangga_pos/features/pengaturan/data/services/backup_input_limits.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('AppRestoreService inspectBackupFile', () {
    late Directory tempDir;
    late AppDatabase database;
    late AppRestoreService service;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('pujangga_restore_test');
      await databaseFactory.setDatabasesPath(tempDir.path);
      database = AppDatabase();
      // All SQLite calls (including service validation and tearDown reset)
      // resolve through the FFI factory to this newly created directory.
      expect(path.dirname(await database.databasePath()), tempDir.path);
      service = AppRestoreService(database: database, logger: Logger.root);
    });

    tearDown(() async {
      await database.reset();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test(
      'resource-limit rejections leave every live table unchanged',
      () async {
        final db = await database.database();
        await db.update('app_settings', {'receipt_footer': 'Data tetap utuh'});
        Future<Map<String, Object>> snapshot() async => {
          for (final table in AppBackupService.backupTables)
            table: await db.query(table),
        };
        final before = await snapshot();
        final inputs = [
          '{"x":${'[' * 1000}0${']' * 1000}}',
          jsonEncode({'x': 'a' * (BackupInputLimits.maxStringLength + 1)}),
          jsonEncode({
            'tables': {'items': List.filled(BackupInputLimits.maxRows + 1, {})},
          }),
          ' ' * (BackupInputLimits.maxBytes + 1),
        ];
        final file = File(path.join(tempDir.path, 'oversized.json'));
        for (final input in inputs) {
          await file.writeAsString(input);
          await expectLater(
            service.inspectBackupFile(file.path),
            throwsA(
              isA<AppException>().having(
                (e) => e.code,
                'code',
                'backup_limit_exceeded',
              ),
            ),
          );
          expect(await snapshot(), before);
        }
      },
    );

    test(
      'main event loop continues while worker inspects a 20 MiB file',
      () async {
        final file = File(path.join(tempDir.path, 'large.json'));
        await file.writeAsString('{}${' ' * (BackupInputLimits.maxBytes - 2)}');
        var ticks = 0;
        var maxGap = Duration.zero;
        final watch = Stopwatch()..start();
        var previous = Duration.zero;
        final timer = Timer.periodic(const Duration(milliseconds: 1), (_) {
          final now = watch.elapsed;
          final gap = now - previous;
          if (gap > maxGap) maxGap = gap;
          previous = now;
          ticks++;
        });
        try {
          await expectLater(
            service.inspectBackupFile(file.path),
            throwsA(
              isA<AppException>().having(
                (e) => e.code,
                'code',
                'backup_incompatible',
              ),
            ),
          );
        } finally {
          timer.cancel();
        }
        expect(ticks, greaterThan(3));
        // A coarse regression guard for the host event loop, not a device FPS benchmark.
        expect(maxGap, lessThan(const Duration(milliseconds: 250)));
      },
    );

    test(
      'membaca file backup valid dan menghasilkan kandidat restore',
      () async {
        final file = File(path.join(tempDir.path, 'backup.json'));
        final payload = const AppBackupPayloadBuilder().build(
          generatedAt: DateTime.utc(2026, 7, 12, 10, 0, 0),
          tables: {
            'business_profile': [
              {
                'id': 1,
                'business_name': 'Kedai Pujangga',
                'business_type': 'retail',
                'owner_name': null,
                'phone': null,
                'address': null,
                'logo_path': null,
                'modal_awal_usaha': null,
                'created_at': '2026-07-12T10:00:00.000Z',
                'updated_at': '2026-07-12T10:00:00.000Z',
              },
            ],
            'app_settings': [
              {
                'id': 1,
                'currency_code': 'IDR',
                'currency_symbol': 'Rp',
                'receipt_header': null,
                'receipt_footer': null,
                'default_tax_percent': 0,
                'stock_allow_negative': 0,
                'auto_print_receipt': 1,
                'created_at': '2026-07-12T10:00:00.000Z',
                'updated_at': '2026-07-12T10:00:00.000Z',
              },
            ],
            'categories': const [],
            'items': const [],
            'sales_transactions': const [],
            'sales_transaction_items': const [],
            'stock_movements': const [],
            'expenses': const [],
            'capital_history': const [],
            'employees': const [],
            'employee_compensation_periods': const [],
          },
        );

        await file.writeAsString(
          const JsonEncoder.withIndent('  ').convert(payload),
        );

        final candidate = await service.inspectBackupFile(file.path);

        expect(candidate.fileName, 'backup.json');
        expect(candidate.schemaVersion, AppConstants.databaseVersion);
        expect(candidate.recordCounts['business_profile'], 1);
        expect(candidate.totalRecords, 2);
        expect(candidate.hasBusinessProfile, isTrue);
      },
    );

    test('menolak file backup dengan format yang tidak kompatibel', () async {
      final file = File(path.join(tempDir.path, 'invalid.json'));
      await file.writeAsString(
        jsonEncode({
          'format': 'unknown',
          'format_version': 1,
          'generated_at': DateTime.now().toIso8601String(),
          'database': {
            'name': AppConstants.databaseName,
            'schema_version': AppConstants.databaseVersion,
          },
          'tables': {
            for (final table in const [
              'business_profile',
              'app_settings',
              'categories',
              'items',
              'sales_transactions',
              'sales_transaction_items',
              'stock_movements',
              'expenses',
              'capital_history',
            ])
              table: [],
          },
        }),
      );

      expect(
        () => service.inspectBackupFile(file.path),
        throwsA(
          isA<AppException>().having(
            (error) => error.code,
            'code',
            'backup_incompatible',
          ),
        ),
      );
    });
  });
}
