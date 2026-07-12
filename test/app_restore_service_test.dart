import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:pujangga_pos/core/constants/app_constants.dart';
import 'package:pujangga_pos/core/database/app_database.dart';
import 'package:pujangga_pos/core/errors/app_exception.dart';
import 'package:pujangga_pos/features/pengaturan/data/services/app_backup_payload_builder.dart';
import 'package:pujangga_pos/features/pengaturan/data/services/app_restore_service.dart';

void main() {
  group('AppRestoreService inspectBackupFile', () {
    late Directory tempDir;
    late AppRestoreService service;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('pujangga_restore_test');
      service = AppRestoreService(
        database: AppDatabase.instance,
        logger: Logger.root,
      );
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test(
      'membaca file backup valid dan menghasilkan kandidat restore',
      () async {
        final file = File('${tempDir.path}\\backup.json');
        final payload = const AppBackupPayloadBuilder().build(
          generatedAt: DateTime.utc(2026, 7, 12, 10, 0, 0),
          tables: {
            'business_profile': [
              {'id': 1, 'business_name': 'Kedai Pujangga'},
            ],
            'app_settings': [
              {'id': 1, 'currency_code': 'IDR'},
            ],
            'categories': const [],
            'items': const [],
            'sales_transactions': const [],
            'sales_transaction_items': const [],
            'stock_movements': const [],
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
      final file = File('${tempDir.path}\\invalid.json');
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
