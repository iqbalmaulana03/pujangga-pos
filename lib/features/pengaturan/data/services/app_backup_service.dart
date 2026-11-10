import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:logging/logging.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/services/business_logo_service.dart';
import '../../domain/entities/app_backup_file.dart';
import 'app_backup_payload_builder.dart';
import 'backup_encryption.dart';

typedef BackupDirectoryProvider = Future<Directory> Function();

class AppBackupService {
  AppBackupService({
    required this.database,
    required this.logger,
    AppBackupPayloadBuilder? payloadBuilder,
    this.backupDirectoryProvider,
    this.logoService,
  }) : _payloadBuilder = payloadBuilder ?? const AppBackupPayloadBuilder();

  final AppDatabase database;
  final Logger logger;
  final AppBackupPayloadBuilder _payloadBuilder;
  final BackupDirectoryProvider? backupDirectoryProvider;
  final BusinessLogoService? logoService;

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
    'employees',
    'employee_compensation_periods',
  ];

  // A null password is an explicit request for a legacy plaintext export.
  Future<AppBackupFile> createBackup({required String? password}) =>
      (logoService ?? BusinessLogoService()).synchronized(
        () => _createBackup(password),
      );

  Future<AppBackupFile> _createBackup(String? password) async {
    final db = await database.database();
    final generatedAt = DateTime.now();
    final tables = await db.transaction((txn) async {
      final snapshot = <String, List<Map<String, Object?>>>{};
      for (final table in backupTables) {
        final rows = await txn.query(table);
        snapshot[table] = rows
            .map((row) => Map<String, Object?>.from(row))
            .toList(growable: false);
      }
      return snapshot;
    });

    // Keep logo processing, serialization, and file I/O outside the snapshot
    // transaction so sales can resume as soon as the table reads finish.
    Uint8List? logoBytes;
    final warnings = <String>[];
    final profiles = tables['business_profile']!;
    final logoPath = profiles.isEmpty
        ? null
        : profiles.first['logo_path'] as String?;
    if (logoPath != null && logoPath.isNotEmpty) {
      try {
        final logos = logoService ?? BusinessLogoService();
        logoBytes = await logos.normalize(await logos.readSource(logoPath));
      } catch (_) {
        warnings.add(
          'Logo tidak dapat dibaca dan tidak disertakan dalam cadangan.',
        );
      }
    }
    final payload = _payloadBuilder.build(
      generatedAt: generatedAt,
      tables: tables,
      businessLogoBytes: logoBytes,
    );

    final targetDirectory =
        await (backupDirectoryProvider?.call() ??
            getApplicationDocumentsDirectory());
    await targetDirectory.create(recursive: true);

    final fileName =
        'pujangga_pos_backup_${_formatTimestamp(generatedAt)}_${DateTime.now().microsecondsSinceEpoch}${password == null ? '' : '_encrypted'}.json';
    final file = File(path.join(targetDirectory.path, fileName));

    final plaintext = const JsonEncoder.withIndent('  ').convert(payload);
    // Never write an intermediate plaintext file for encrypted exports.
    final content = password == null
        ? plaintext
        : await BackupEncryption.encrypt(plaintext, password);
    await file.writeAsString(content, flush: true);

    logger.info('Backup exported to ${file.path}');

    return AppBackupFile(
      filePath: file.path,
      fileName: fileName,
      generatedAt: generatedAt,
      warnings: warnings,
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
