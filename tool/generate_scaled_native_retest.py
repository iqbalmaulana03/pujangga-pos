from pathlib import Path

target = Path('integration_test/scaled_legacy_retest_test.dart')
assert not target.exists()
s = Path('test/scaled_transaction_persistence_test.dart').read_text()
s = s.replace("import 'dart:io';", """import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';""")
s = s.replace("import 'package:sqflite_common_ffi/sqflite_ffi.dart';", "import 'package:sqflite/sqflite.dart';")
s = s.replace('  test(', '  deviceTest(')
s = s.replace('void main() {', '''void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const revision = String.fromEnvironment('E2E_SOURCE_REVISION');
  late Directory evidence;
  final completed = <String>[];
  final snapshots = <Map<String, Object?>>[];
''')
marker = '  setUpAll(() {\n    sqfliteFfiInit();\n    databaseFactory = databaseFactoryFfi;\n  });'
assert marker in s
s = s.replace(marker, '''
  void deviceTest(String name, Future<void> Function() body) {
    test(name, () async {
      await body();
      completed.add(name);
      for (final entry in {'source': source, 'destination': destination}.entries) {
        final connection = await entry.value.database();
        final path = await entry.value.databasePath();
        expect(p.isWithin(root.path, path), isTrue);
        expect((await connection.rawQuery('PRAGMA database_list')).singleWhere((row) => row['name'] == 'main')['file'], path);
        final tables = <String, Object?>{};
        for (final table in AppBackupService.backupTables) {
          tables[table] = await connection.query(table, orderBy: 'id');
        }
        expect(await connection.rawQuery('PRAGMA integrity_check'), [{'integrity_check': 'ok'}]);
        expect(await connection.rawQuery('PRAGMA foreign_key_check'), isEmpty);
        await connection.close();
        final filename = '${completed.length}-${entry.key}.sqlite';
        await File(path).copy(p.join(evidence.path, filename));
        snapshots.add({'test': name, 'file': filename, 'tables': tables});
      }
      debugPrint('PR82_LEGACY_PASS: $name');
    });
  }
  setUpAll(() async {
    expect(revision, matches(RegExp(r'^[a-f0-9]{40}$')));
    final cache = await getTemporaryDirectory();
    expect(cache.path, contains('/com.pujanggapos.pujangga_pos.pr82e2e/'));
    evidence = Directory(p.join(cache.path, 'pr82-legacy-evidence'));
    expect(await evidence.exists(), isFalse);
    await evidence.create();
  });
  tearDownAll(() async {
    await File(p.join(evidence.path, 'result.json')).writeAsString(jsonEncode({
      'revision': revision, 'status': 'passed', 'tests': completed,
      'snapshots': snapshots, 'verified_at_utc': DateTime.now().toUtc().toIso8601String(),
    }));
    debugPrint('PR82_LEGACY_COMPLETE: ${completed.length} native regression cases');
  });''')
s = s.replace("root = await Directory.systemTemp.createTemp('pujangga_72_');", """final cache = await getTemporaryDirectory();
    root = await cache.createTemp('pujangga_72_');
    expect(p.isWithin(cache.path, root.path), isTrue);""")
target.write_text(s, encoding='utf-8')
print('Generated native harness from committed persistence regression suite')
