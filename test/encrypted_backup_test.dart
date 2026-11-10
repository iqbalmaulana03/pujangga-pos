import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as path;
import 'package:pujangga_pos/core/database/app_database.dart';
import 'package:pujangga_pos/core/errors/app_exception.dart';
import 'package:pujangga_pos/features/pengaturan/data/services/app_backup_service.dart';
import 'package:pujangga_pos/features/pengaturan/data/services/app_restore_service.dart';
import 'package:pujangga_pos/features/pengaturan/data/services/backup_encryption.dart';
import 'package:pujangga_pos/features/pengaturan/data/services/backup_file_picker_service.dart';
import 'package:pujangga_pos/features/pengaturan/presentation/controllers/pengaturan_restore_controller.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const _password = 'Kata sandi sintetis 52';

Matcher _error(String code) =>
    isA<AppException>().having((error) => error.code, 'code', code);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('decrypts independent Python cryptography fixture', () async {
    // Generated with Python cryptography 47 PBKDF2HMAC(SHA256, 600000,
    // length=32), AESGCM, salt=bytes(range(16)), nonce=bytes(range(12)).
    final envelope = jsonDecode(
      await File('test/fixtures/encrypted_backup_v1.json').readAsString(),
    ) as Map<String, dynamic>;
    expect(
      await BackupEncryption.decrypt(envelope, 'fixture-password-52'),
      'Cadangan portabel sintetis 52',
    );
  });

  group('portable encrypted backup service', () {
    late Directory temporary;
    late AppDatabase source;
    late AppDatabase destination;
    late AppBackupService backup;
    late AppRestoreService restore;

    setUpAll(() {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });

    setUp(() async {
      temporary = await Directory.systemTemp.createTemp(
        'pujangga_encryption_52_',
      );
      source = _PathDatabase(path.join(temporary.path, 'source.sqlite'));
      destination = _PathDatabase(
        path.join(temporary.path, 'other-device.sqlite'),
      );
      // Effective database paths are test-owned, disposable, and distinct.
      expect(
        await source.databasePath(),
        isNot(await destination.databasePath()),
      );
      for (final db in [source, destination]) {
        expect(path.dirname(await db.databasePath()), temporary.path);
      }
      final now = DateTime.utc(2026, 11, 10).toIso8601String();
      await (await source.database()).insert('employees', {
        'name': 'Karyawan Sintetis Rahasia 52',
        'compensation_type': 'monthly_salary',
        'monthly_salary': 7654321,
        'effective_from': now,
        'created_at': now,
        'updated_at': now,
      });
      await (await destination.database()).insert('categories', {
        'name': 'Data tujuan tetap utuh',
        'item_type': 'product',
        'created_at': now,
        'updated_at': now,
      });
      backup = AppBackupService(
        database: source,
        logger: Logger('encrypted-backup-test'),
        backupDirectoryProvider: () async => temporary,
      );
      restore = AppRestoreService(
        database: destination,
        logger: Logger('encrypted-backup-test'),
      );
    });

    tearDown(() async {
      await source.reset();
      await destination.reset();
      await temporary.delete(recursive: true);
    });

    Future<Map<String, List<Map<String, Object?>>>> snapshot() async {
      final db = await destination.database();
      return {
        for (final table in AppBackupService.backupTables)
          table: await db.query(table),
      };
    }

    test(
      'round-trip on a fresh destination, no sensitive plaintext or logs',
      () async {
        final records = <LogRecord>[];
        final subscription = Logger.root.onRecord.listen(records.add);
        addTearDown(subscription.cancel);
        final file = await backup.createBackup(password: _password);
        final raw = await File(file.filePath).readAsString();
        for (final sensitive in [
          'Karyawan Sintetis Rahasia 52',
          '7654321',
          _password,
          'monthly_salary',
          'tables',
        ]) {
          expect(raw, isNot(contains(sensitive)));
        }
        expect(
          await temporary.list().where((f) => f.path.endsWith('.json')).length,
          1,
        );
        final candidate = await restore.inspectBackupFile(
          file.filePath,
          password: _password,
        );
        await restore.restoreBackup(candidate);
        final actual = await snapshot();
        final sourceDb = await source.database();
        for (final table in AppBackupService.backupTables) {
          expect(actual[table], await sourceDb.query(table), reason: table);
        }
        expect(
          records.map((r) => r.message).join(),
          isNot(contains(_password)),
        );
        expect(
          records.map((r) => r.message).join(),
          isNot(contains('Karyawan Sintetis Rahasia 52')),
        );
      },
    );

    test('wrong/missing password and tampering leave every destination table intact', () async {
      final file = await backup.createBackup(password: _password);
      final original = jsonDecode(
        await File(file.filePath).readAsString(),
      ) as Map<String, dynamic>;
      final before = await snapshot();
      await expectLater(
        restore.inspectBackupFile(file.filePath),
        throwsA(_error('backup_password_required')),
      );
      await expectLater(
        restore.inspectBackupFile(file.filePath, password: 'wrong password'),
        throwsA(_error('backup_authentication_failed')),
      );
      for (final field in ['ciphertext', 'tag', 'salt', 'nonce']) {
        final bytes = base64Decode(original[field] as String);
        bytes[0] ^= 1;
        await File(
          file.filePath,
        ).writeAsString(jsonEncode({...original, field: base64Encode(bytes)}));
        await expectLater(
          restore.inspectBackupFile(file.filePath, password: _password),
          throwsA(_error('backup_authentication_failed')),
          reason: field,
        );
        expect(await snapshot(), before);
      }
      expect(await snapshot(), before);
    });

    test(
      'exports use independent salt and nonce; unsupported KDF rejected',
      () async {
        final first = await backup.createBackup(password: _password);
        final second = await backup.createBackup(password: _password);
        expect(first.filePath, isNot(second.filePath));
        final a = jsonDecode(
          await File(first.filePath).readAsString(),
        ) as Map<String, dynamic>;
        final b = jsonDecode(
          await File(second.filePath).readAsString(),
        ) as Map<String, dynamic>;
        for (final field in ['salt', 'nonce', 'ciphertext']) {
          expect(a[field], isNot(b[field]), reason: field);
        }
        for (final change in [
          {'iterations': 1},
          {'iterations': 999999999},
          {'format_version': 2},
          {'cipher': 'AES-CBC'},
          {'kdf': 'unknown'},
          {'salt': 'bad-base64'},
          {'nonce': ''},
          {'tag': ''},
        ]) {
          await expectLater(
            () => BackupEncryption.decrypt({...a, ...change}, _password),
            throwsA(_error('backup_encryption_invalid')),
          );
        }
      },
    );

    test(
      'explicit legacy plaintext export still imports without a password',
      () async {
        final file = await backup.createBackup(password: null);
        expect(
          await File(file.filePath).readAsString(),
          contains('Karyawan Sintetis Rahasia 52'),
        );
        final candidate = await restore.inspectBackupFile(file.filePath);
        await restore.restoreBackup(candidate);
        expect(
          (await snapshot())['employees'],
          await (await source.database()).query('employees'),
        );
      },
    );

    test('restore controller requests password only for encrypted files and handles cancel', () async {
      final encrypted = await backup.createBackup(password: _password);
      final legacy = await backup.createBackup(password: null);
      final picker = _Picker(encrypted.filePath);
      final container = ProviderContainer(
        overrides: [
          appRestoreServiceProvider.overrideWithValue(restore),
          backupFilePickerServiceProvider.overrideWithValue(picker),
        ],
      );
      addTearDown(container.dispose);
      await container.read(pengaturanRestoreControllerProvider.future);
      final controller = container.read(
        pengaturanRestoreControllerProvider.notifier,
      );
      final before = await snapshot();
      var prompts = 0;
      final cancelled = await controller.pickBackupFile(
        requestPassword: () async {
          prompts++;
          return null;
        },
      );
      expect(cancelled, isNull);
      expect(
        container.read(pengaturanRestoreControllerProvider).isLoading,
        isFalse,
      );
      expect(await snapshot(), before);
      final candidate = await controller.pickBackupFile(
        requestPassword: () async {
          prompts++;
          return _password;
        },
      );
      expect(candidate?.recordCounts['employees'], 1);
      expect(prompts, 2);
      expect(
        await snapshot(),
        before,
      ); // Still requires the restore confirmation.
      picker.selected = legacy.filePath;
      expect(
        await controller.pickBackupFile(
          requestPassword: () async {
            fail('Legacy imports must not request a password');
          },
        ),
        isNotNull,
      );
    });

    test('weak password produces no backup file', () async {
      await expectLater(
        backup.createBackup(password: 'short'),
        throwsA(_error('backup_password_weak')),
      );
      expect(
        await temporary.list().where((f) => f.path.endsWith('.json')).length,
        0,
      );
    });
  });
}

class _PathDatabase extends AppDatabase {
  _PathDatabase(this.filePath);
  final String filePath;
  @override
  Future<String> databasePath() async => filePath;
}

class _Picker extends BackupFilePickerService {
  _Picker(this.selected);
  String selected;
  @override
  Future<String?> pickBackupFile() async => selected;
}
