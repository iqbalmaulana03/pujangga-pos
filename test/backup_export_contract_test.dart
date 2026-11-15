@Timeout(Duration(minutes: 5))
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as path;
import 'package:pujangga_pos/core/database/app_database.dart';
import 'package:pujangga_pos/core/errors/app_exception.dart';
import 'package:pujangga_pos/core/services/business_logo_service.dart';
import 'package:pujangga_pos/features/pengaturan/data/services/app_backup_payload_builder.dart';
import 'package:pujangga_pos/features/pengaturan/data/services/app_backup_service.dart';
import 'package:pujangga_pos/features/pengaturan/data/services/app_restore_service.dart';
import 'package:pujangga_pos/features/pengaturan/data/services/backup_input_limits.dart';
import 'package:pujangga_pos/features/pengaturan/data/services/backup_encryption.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const password = 'Synthetic export password 71';
typedef Payload = Map<String, Object?>;

Matcher errorCode(String code) =>
    throwsA(isA<AppException>().having((e) => e.code, 'code', code));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late Directory exports;
  late AppDatabase source;
  late AppDatabase destination;
  late Database db;
  late File previous;
  late List<LogRecord> records;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });
  setUp(() async {
    root = await Directory.systemTemp.createTemp('export_contract_71_');
    exports = await Directory(path.join(root.path, 'exports')).create();
    source = _Database(path.join(root.path, 'source.sqlite'));
    destination = _Database(path.join(root.path, 'destination.sqlite'));
    for (final database in [source, destination]) {
      expect(path.isWithin(root.path, await database.databasePath()), isTrue);
    }
    expect(
      await source.databasePath(),
      isNot(await destination.databasePath()),
    );
    db = await source.database();
    await db.insert('categories', {
      'name': 'Synthetic category',
      'item_type': 'product',
      'created_at': '2026-11-15',
      'updated_at': '2026-11-15',
    });
    previous = await File(path.join(exports.path, 'previous.json'))
        .writeAsString('previous backup bytes');
    records = [];
    final subscription = Logger.root.onRecord.listen(records.add);
    addTearDown(subscription.cancel);
  });
  tearDown(() async {
    await source.reset();
    await destination.reset();
    await root.delete(recursive: true);
  });

  AppBackupService service([Payload Function(Payload)? change]) =>
      AppBackupService(
        database: source,
        logger: Logger('export-contract'),
        backupDirectoryProvider: () async => exports,
        payloadBuilder: change == null ? null : _Builder(change),
      );

  Future<Map<String, Object?>> snapshot() async => {
    for (final table in AppBackupService.backupTables)
      table: await db.query(table, orderBy: 'id'),
    'sequences': await db.query('sqlite_sequence', orderBy: 'name'),
  };

  Future<void> preserved(Map<String, Object?> before) async {
    expect(await snapshot(), before);
    expect(await previous.readAsString(), 'previous backup bytes');
    expect(await exports.list().map((e) => path.basename(e.path)).toList(), [
      'previous.json',
    ]);
    expect(
      records.where((r) => r.message.startsWith('Backup exported')),
      isEmpty,
    );
  }

  for (final secret in <String?>[null, password]) {
    final format = secret == null ? 'plaintext' : 'encrypted';
    test(
      '$format accepts the byte boundary and rejects the next byte',
      () async {
        final overhead = secret == null
            ? 0
            : utf8.encode(await BackupEncryption.encrypt('', secret)).length;
        final target = secret == null
            ? BackupInputLimits.maxBytes
            : ((BackupInputLimits.maxBytes - overhead) ~/ 4) * 3;
        Payload sized(Payload p, int size) {
          final parts = List.filled(
            (size - 10000) ~/ 60000,
            'a' * 60000,
          ).toList();
          parts.addAll(['', '']);
          p['byte_fixture'] = parts;
          final emptySize = utf8
              .encode(const JsonEncoder.withIndent('  ').convert(p))
              .length;
          final remaining = size - emptySize;
          parts[parts.length - 2] = 'a' * (remaining ~/ 2);
          parts[parts.length - 1] = 'a' * (remaining - remaining ~/ 2);
          expect(
            utf8.encode(const JsonEncoder.withIndent('  ').convert(p)).length,
            size,
          );
          return p;
        }

        final file = await service((p) => sized(p, target))
            .createBackup(password: secret);
        expect(
          await File(file.filePath).length(),
          inInclusiveRange(
            BackupInputLimits.maxBytes - 3,
            BackupInputLimits.maxBytes,
          ),
        );
        final restore = AppRestoreService(
          database: destination,
          logger: Logger('test'),
        );
        await restore.restoreBackup(
          await restore.inspectBackupFile(file.filePath, password: secret),
        );
        await File(file.filePath).delete();
        records.clear();
        final before = await snapshot();
        await expectLater(
          service((p) => sized(p, target + 1)).createBackup(password: secret),
          errorCode('backup_limit_exceeded'),
        );
        await preserved(before);
      },
    );
    test(
      '$format accepts exact row, depth and text budgets together',
      () async {
        final file = await service((p) {
          final tables = p['tables'] as Map;
          final count = tables.values.fold<int>(
            0,
            (n, rows) => n + (rows as List).length,
          );
          tables['budget_fixture'] = List.filled(
            BackupInputLimits.maxRows - count,
            <String, Object?>{},
          );
          p['text'] = 'a' * BackupInputLimits.maxStringLength;
          p['depth'] = List.generate(
            BackupInputLimits.maxDepth - 1,
            (_) => 0,
          ).fold<Object>(0, (v, _) => [v]);
          return p;
        }).createBackup(password: secret);
        final restore = AppRestoreService(
          database: destination,
          logger: Logger('test'),
        );
        await restore.restoreBackup(
          await restore.inspectBackupFile(file.filePath, password: secret),
        );
        expect(
          await (await destination.database()).query('categories'),
          await db.query('categories'),
        );
      },
    );

    test('$format accepts exactly the token budget and rejects one more', () async {
      Payload tokens(Payload p, int extra) {
        // Scanner counts opening string quotes, punctuation and literal digits;
        // closing quotes and characters inside strings consume no units.
        final raw = jsonEncode(p);
        var quoted = false;
        var escaped = false;
        var units = 0;
        for (final c in raw.codeUnits) {
          if (quoted) {
            if (escaped) {
              escaped = false;
            } else if (c == 92) {
              escaped = true;
            } else if (c == 34) {
              quoted = false;
            }
          } else {
            units++;
            if (c == 34) quoted = true;
          }
        }
        // Add comma, key quote, colon, two brackets, then 2*n-1 units.
        final remaining = BackupInputLimits.maxTokens - units - 4;
        final n = remaining ~/ 2;
        final values = List<int>.filled(n, 0);
        values[0] = remaining.isOdd ? 10 : 0;
        if (extra != 0) values[0] = remaining.isOdd ? 100 : 10;
        return p..['token_fixture'] = values;
      }

      final file = await service((p) => tokens(p, 0))
          .createBackup(password: secret);
      final restore = AppRestoreService(
        database: destination,
        logger: Logger('test'),
      );
      await restore.restoreBackup(
        await restore.inspectBackupFile(file.filePath, password: secret),
      );
      await File(file.filePath).delete();
      records.clear();
      final before = await snapshot();
      await expectLater(
        service((p) => tokens(p, 1)).createBackup(password: secret),
        errorCode('backup_limit_exceeded'),
      );
      await preserved(before);
    });
    test('$format round trip persists every table after reopen', () async {
      final logos = BusinessLogoService(
        supportDirectory: () async => Directory(path.join(root.path, 'logos')),
      );
      final png = await logos.normalize(
        await File('test/fixtures/logo-jpeg.jpg').readAsBytes(),
      );
      final logoPath = await logos.write(png);
      await db.insert('business_profile', {
        'business_name': 'Synthetic business',
        'business_type': 'retail',
        'logo_path': logoPath,
        'created_at': '2026-11-15',
        'updated_at': '2026-11-15',
      });
      final before = await snapshot();
      final file = await service().createBackup(password: secret);
      final restore = AppRestoreService(
        database: destination,
        logger: Logger('test'),
        logoService: logos,
      );
      await restore.restoreBackup(
        await restore.inspectBackupFile(file.filePath, password: secret),
      );
      await (await destination.database()).close();
      destination = _Database(await destination.databasePath());
      final restored = await destination.database();
      for (final table in AppBackupService.backupTables) {
        final actual = await restored.query(table, orderBy: 'id');
        if (table == 'business_profile') {
          final profile = Map<String, Object?>.from(actual.single);
          final restoredLogo = profile['logo_path'] as String;
          expect(restoredLogo, isNot(logoPath));
          expect(await File(restoredLogo).readAsBytes(), png);
          profile['logo_path'] = logoPath;
          expect([profile], before[table]);
        } else {
          expect(actual, before[table], reason: table);
        }
      }
      expect(await restored.rawQuery('PRAGMA foreign_key_check'), isEmpty);
      expect(await restored.rawQuery('PRAGMA integrity_check'), [
        {'integrity_check': 'ok'},
      ]);
    });

    final failures = <String, Payload Function(Payload)>{
      'combined rows below byte limit': (p) {
        p['tables'] = {
          'a': List.filled(25000, {}),
          'b': List.filled(25001, {}),
        };
        return p;
      },
      'oversized bytes': (p) {
        p['padding'] = List.filled(400, 'a' * 60000);
        return p;
      },
      'string': (p) =>
          p..['extra'] = 'a' * (BackupInputLimits.maxStringLength + 1),
      'key': (p) => p..['a' * (BackupInputLimits.maxStringLength + 1)] = 0,
      'depth': (p) => p
        ..['extra'] = List.generate(
          12,
          (_) => 0,
        ).fold<Object>(0, (v, _) => [v]),
      'tokens': (p) =>
          p..['extra'] = List.filled(BackupInputLimits.maxTokens ~/ 2, 0),
    };
    for (final entry in failures.entries) {
      test('$format rejects ${entry.key} before publishing', () async {
        final before = await snapshot();
        await expectLater(
          service(entry.value).createBackup(password: secret),
          errorCode('backup_limit_exceeded'),
        );
        await preserved(before);
      });
    }

    final invalid = <String, Payload Function(Payload)>{
      'counts': (p) => p..['table_counts'] = {},
      'date': (p) => p..['generated_at'] = '2026-02-30',
      'columns': (p) {
        (((p['tables'] as Map)['categories'] as List).single as Map).remove(
          'name',
        );
        return p;
      },
      'semantics': (p) {
        (((p['tables'] as Map)['categories'] as List).single
                as Map)['item_type'] =
            'invalid';
        return p;
      },
      'logo': (p) => p
        ..['assets'] = {
          'business_logo': {'mime_type': 'image/png', 'data_base64': 'broken'},
        },
    };
    for (final entry in invalid.entries) {
      test('$format rejects invalid ${entry.key}', () async {
        final before = await snapshot();
        await expectLater(
          service(entry.value).createBackup(password: secret),
          errorCode('backup_invalid'),
        );
        await preserved(before);
      });
    }

    for (final fault in ['write', 'inspect', 'rename']) {
      test('$format $fault failure leaves no final file', () async {
        final before = await snapshot();
        final overrides = _FaultOverrides(fault, encrypted: secret != null);
        await expectLater(
          IOOverrides.runWithIOOverrides(
            () => service().createBackup(password: secret),
            overrides,
          ),
          throwsA(isA<Exception>()),
        );
        expect(overrides.observed, isTrue);
        await preserved(before);
      });
    }
  }

  test('encrypted envelope overflows even though plaintext fits', () async {
    Payload large(Payload p) => p..['padding'] = List.filled(270, 'a' * 60000);
    final plaintext = await service(large).createBackup(password: null);
    expect(
      await File(plaintext.filePath).length(),
      lessThan(BackupInputLimits.maxBytes),
    );
    await File(plaintext.filePath).delete();
    records.clear();
    final before = await snapshot();
    await expectLater(
      service(large).createBackup(password: password),
      errorCode('backup_limit_exceeded'),
    );
    await preserved(before);
  });

  test('invalid active foreign keys cannot be exported', () async {
    await db.execute('PRAGMA foreign_keys = OFF');
    await db.insert('items', {
      'name': 'orphan',
      'item_type': 'product',
      'category_id': 999,
      'sale_price': 1,
      'created_at': '2026-11-15',
      'updated_at': '2026-11-15',
    });
    final before = await snapshot();
    await expectLater(
      service().createBackup(password: null),
      errorCode('backup_invalid'),
    );
    await preserved(before);
  });
}

class _Database extends AppDatabase {
  _Database(this.file);
  final String file;
  @override
  Future<String> databasePath() async => file;
}

class _Builder extends AppBackupPayloadBuilder {
  _Builder(this.change);
  final Payload Function(Payload) change;
  @override
  Payload build({
    required DateTime generatedAt,
    required Map<String, List<Map<String, Object?>>> tables,
    Uint8List? businessLogoBytes,
  }) => change(
    super.build(
      generatedAt: generatedAt,
      tables: tables,
      businessLogoBytes: businessLogoBytes,
    ),
  );
}

// Intercept real staging file I/O; worker inspection still reads the real bytes.
final class _FaultOverrides extends IOOverrides {
  _FaultOverrides(this.fault, {required this.encrypted});
  final String fault;
  final bool encrypted;
  bool observed = false;
  @override
  File createFile(String path) {
    final file = super.createFile(path);
    return path.contains('.pending-') ? _FaultFile(file, this) : file;
  }
}

class _FaultFile implements File {
  _FaultFile(this.file, this.owner);
  final File file;
  final _FaultOverrides owner;
  @override
  String get path => file.path;
  @override
  Uri get uri => file.uri;
  @override
  Future<File> writeAsString(
    String contents, {
    FileMode mode = FileMode.write,
    Encoding encoding = utf8,
    bool flush = false,
  }) async {
    owner.observed = true;
    if (owner.encrypted) {
      expect(contents, isNot(contains('Synthetic category')));
      expect(jsonDecode(contents)['ciphertext'], isA<String>());
    }
    await file.writeAsString(
      contents,
      mode: mode,
      encoding: encoding,
      flush: flush,
    );
    if (owner.fault == 'write') {
      throw const FileSystemException('synthetic write failure');
    }
    if (owner.fault == 'inspect') await file.writeAsString('{');
    return this;
  }

  @override
  Future<File> rename(String newPath) async {
    if (owner.fault == 'rename') {
      throw const FileSystemException('synthetic rename failure');
    }
    return file.rename(newPath);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
