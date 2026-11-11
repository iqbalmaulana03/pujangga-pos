import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pujangga_pos/core/errors/app_exception.dart';
import 'package:pujangga_pos/features/pengaturan/data/services/backup_input_limits.dart';
import 'package:pujangga_pos/features/pengaturan/data/services/backup_encryption.dart';

void main() {
  late Directory directory;
  late File file;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('backup_limits_');
    file = File('${directory.path}/backup.json');
  });
  tearDown(() => directory.delete(recursive: true));

  final limitError = throwsA(
    isA<AppException>().having((e) => e.code, 'code', 'backup_limit_exceeded'),
  );

  test(
    'stat rejects oversized invalid UTF-8 before reading/decoding',
    () async {
      final handle = await file.open(mode: FileMode.write);
      await handle.writeByte(255);
      await handle.truncate(BackupInputLimits.maxBytes + 1);
      await handle.close();
      await expectLater(BackupInputLimits.read(file.path), limitError);
    },
  );

  test('accepts exact byte budget and rejects one byte more', () async {
    await file.writeAsString('{}${' ' * (BackupInputLimits.maxBytes - 2)}');
    expect(await BackupInputLimits.read(file.path), isEmpty);
    await file.writeAsString(' ', mode: FileMode.append);
    await expectLater(BackupInputLimits.read(file.path), limitError);
  });

  test(
    'depth boundary and deeply nested input are bounded before decode',
    () async {
      final depth = BackupInputLimits.maxDepth - 1;
      await file.writeAsString('{"x":${'[' * depth}0${']' * depth}}');
      expect(await BackupInputLimits.read(file.path), contains('x'));
      await file.writeAsString('{"x":${'[' * 100000}0${']' * 100000}}');
      await expectLater(BackupInputLimits.read(file.path), limitError);
    },
  );

  test('counts rows across all tables, including unknown tables', () async {
    final rows = List.filled(
      BackupInputLimits.maxRows ~/ 2,
      <String, Object?>{},
    );
    final tables = {'a': rows, 'b': rows};
    await file.writeAsString(jsonEncode({'tables': tables}));
    expect(await BackupInputLimits.read(file.path), contains('tables'));
    tables['unknown'] = [{}];
    await file.writeAsString(jsonEncode({'tables': tables}));
    await expectLater(BackupInputLimits.read(file.path), limitError);
  });

  test('limits decoded values and keys, including escaped Unicode', () async {
    await file.writeAsString(
      jsonEncode({'x': 'a' * BackupInputLimits.maxStringLength}),
    );
    expect(await BackupInputLimits.read(file.path), contains('x'));
    await file.writeAsString(
      '{"x":"${r'\u0061' * (BackupInputLimits.maxStringLength + 1)}"}',
    );
    await expectLater(BackupInputLimits.read(file.path), limitError);
    await file.writeAsString(
      jsonEncode({'a' * (BackupInputLimits.maxStringLength + 1): 0}),
    );
    await expectLater(BackupInputLimits.read(file.path), limitError);
  });

  test(
    'only an encrypted root ciphertext receives the bounded string exception',
    () async {
      final large = 'a' * (BackupInputLimits.maxStringLength + 1);
      await file.writeAsString(
        jsonEncode({'format': BackupEncryption.format, 'ciphertext': large}),
      );
      expect(
        await BackupInputLimits.read(file.path, allowEncryptedEnvelope: true),
        contains('ciphertext'),
      );
      await expectLater(BackupInputLimits.read(file.path), limitError);
      await file.writeAsString(
        jsonEncode({'format': 'pujangga_pos_backup', 'ciphertext': large}),
      );
      await expectLater(
        BackupInputLimits.read(file.path, allowEncryptedEnvelope: true),
        limitError,
      );
      await file.writeAsString(
        jsonEncode({
          'format': BackupEncryption.format,
          'nested': {'ciphertext': large},
        }),
      );
      await expectLater(
        BackupInputLimits.read(file.path, allowEncryptedEnvelope: true),
        limitError,
      );
    },
  );

  test('logo exception preserves the existing base64 allowance', () async {
    final logo = 'A' * BackupInputLimits.maxLogoLength;
    await file.writeAsString(
      jsonEncode({
        'assets': {
          'business_logo': {'data_base64': logo},
        },
      }),
    );
    expect(await BackupInputLimits.read(file.path), contains('assets'));
    await file.writeAsString(
      jsonEncode({
        'assets': {
          'business_logo': {'data_base64': '${logo}A'},
        },
      }),
    );
    await expectLater(BackupInputLimits.read(file.path), limitError);
    await file.writeAsString(jsonEncode({'other': logo}));
    await expectLater(BackupInputLimits.read(file.path), limitError);
  });

  test('wide arrays cannot evade the complexity budget', () async {
    await file.writeAsString(
      '{"x":[${'0,' * (BackupInputLimits.maxTokens ~/ 2)}0]}',
    );
    await expectLater(BackupInputLimits.read(file.path), limitError);
  });

  test('braces and escaped quotes in strings do not count as depth', () async {
    final value = '${'[{"\\' * 100}end';
    await file.writeAsString(jsonEncode({'x': value}));
    expect((await BackupInputLimits.read(file.path))['x'], value);
  });

  test('malformed JSON and UTF-8 use a clear application error', () async {
    for (final bytes in [
      [255],
      utf8.encode('{"x":"\\uZZZZ"}'),
      utf8.encode('{'),
    ]) {
      await file.writeAsBytes(bytes);
      await expectLater(
        BackupInputLimits.read(file.path),
        throwsA(
          isA<AppException>().having((e) => e.code, 'code', 'backup_invalid'),
        ),
      );
    }
  });

  test('budgets reject before decoding a malformed trailing payload', () async {
    final inputs = [
      // The final JSON decoder would reject these broken suffixes. Budget
      // errors prove that preflight stops before allocating their value tree.
      '{"x":"${'a' * (BackupInputLimits.maxStringLength + 1)}", broken',
      '{"tables":{"items":[${'{},' * BackupInputLimits.maxRows}{}]}, broken',
      '{"x":${'[' * BackupInputLimits.maxDepth}0, broken',
    ];
    for (final input in inputs) {
      await file.writeAsString(input);
      await expectLater(BackupInputLimits.read(file.path), limitError);
    }
  });

  test('escaped keys identify tables and logo without path spoofing', () async {
    await file.writeAsString(
      '{"ta\\u0062les":{"items":[${'{},' * BackupInputLimits.maxRows}{}]}}',
    );
    await expectLater(BackupInputLimits.read(file.path), limitError);
    final value = 'A' * (BackupInputLimits.maxStringLength + 1);
    await file.writeAsString(
      '{"assets":{"business_logo":{"data_base\\u0036\\u0034":"$value"}}}',
    );
    expect(await BackupInputLimits.read(file.path), contains('assets'));
    await file.writeAsString(
      jsonEncode({
        'assets/business_logo': {'data_base64': value},
      }),
    );
    await expectLater(BackupInputLimits.read(file.path), limitError);
  });
}
