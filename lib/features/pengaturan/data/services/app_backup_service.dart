import 'dart:convert';
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../../../../core/database/app_database.dart';
import '../../domain/entities/app_backup_file.dart';
import 'app_backup_payload_builder.dart';

typedef BackupDirectoryProvider = Future<Directory> Function();

class AppBackupService {
  AppBackupService({
    required this.database,
    required this.logger,
    AppBackupPayloadBuilder? payloadBuilder,
    this._backupDirectoryProvider,
  }) : _payloadBuilder = payloadBuilder ?? const AppBackupPayloadBuilder();

  final AppDatabase database;
  final Logger logger;
  final AppBackupPayloadBuilder _payloadBuilder;
  final BackupDirectoryProvider? _backupDirectoryProvider;

  static const List<String> backupTables = [
    'business_profile',
    'app_settings',
    'categories',
    'items',
    'sales_transactions',
    'sales_transaction_items',
    'stock_movements',
    'expenses',
    'capital_history',
  ];

  Future<AppBackupFile> createBackup() async {
    final db = await database.database();
    final generatedAt = DateTime.now();
    final tables = <String, List<Map<String, Object?>>>{};

    for (final table in backupTables) {
      final rows = await db.query(table);
      tables[table] = rows
          .map((row) => Map<String, Object?>.from(row))
          .toList(growable: false);
    }

    final payload = _payloadBuilder.build(
      generatedAt: generatedAt,
      tables: tables,
    );

    final targetDirectory =
        await (_backupDirectoryProvider?.call() ??
            getApplicationDocumentsDirectory());
    await targetDirectory.create(recursive: true);

    final fileName =
        'pujangga_pos_backup_${_formatTimestamp(generatedAt)}.json';
    final file = File(path.join(targetDirectory.path, fileName));

    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(payload),
    );

    logger.info('Backup exported to ${file.path}');

    return AppBackupFile(
      filePath: file.path,
      fileName: fileName,
      generatedAt: generatedAt,
      recordCounts: {
        for (final entry in tables.entries) entry.key: entry.value.length,
      },
    );
  }

  String _formatTimestamp(DateTime value) {
    final year = value.year.toString().padLeft(4, '0');
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    final second = value.second.toString().padLeft(2, '0');
    return '$year$month$day$hour$minute$second';
  }
}
