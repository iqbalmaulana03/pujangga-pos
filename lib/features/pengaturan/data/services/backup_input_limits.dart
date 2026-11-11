import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../../../../core/errors/app_exception.dart';
import 'backup_encryption.dart';

part 'backup_json_budget_scanner.dart';

/// Resource budget for a small, local-first business dataset. See
/// docs/RESTORE-LIMITS.md before changing these limits.
abstract final class BackupInputLimits {
  static const maxBytes = 20 * 1024 * 1024;
  static const maxDepth = 12;
  static const maxTokens = 2000000;
  static const maxRows = 50000;
  static const maxStringLength = 65536;
  // Matches the existing 5 MiB PNG backup allowance, encoded as base64.
  static const maxLogoLength = ((5 * 1024 * 1024 + 2) ~/ 3) * 4;

  static Never exceeded(String detail) => throw AppException(
    'backup_limit_exceeded',
    'File backup melebihi batas $detail. Gunakan backup yang lebih kecil.',
  );

  /// Called only inside the inspection worker. Both stat and the bounded read
  /// are necessary: the file can grow after stat completes.
  static Future<Map<String, dynamic>> read(
    String filePath, {
    bool allowEncryptedEnvelope = false,
  }) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw const AppException(
        'backup_not_found',
        'File backup tidak ditemukan di perangkat.',
      );
    }
    if (await file.length() > maxBytes) exceeded('ukuran 20 MiB');
    final bytes = BytesBuilder(copy: false);
    await for (final chunk in file.openRead(0, maxBytes + 1)) {
      if (bytes.length + chunk.length > maxBytes) exceeded('ukuran 20 MiB');
      bytes.add(chunk);
    }
    try {
      return decode(
        utf8.decode(bytes.takeBytes()),
        allowEncryptedEnvelope: allowEncryptedEnvelope,
      );
    } on FormatException {
      throw const AppException(
        'backup_invalid',
        'Format file backup tidak valid.',
      );
    }
  }

  /// Also used for authenticated plaintext; never bypass the JSON budgets.
  static Map<String, dynamic> decode(
    String raw, {
    bool allowEncryptedEnvelope = false,
  }) {
    if (utf8.encode(raw).length > maxBytes) exceeded('ukuran 20 MiB');
    try {
      _BackupJsonBudgetScanner(
        raw,
        allowEncryptedEnvelope: allowEncryptedEnvelope,
      ).scan();
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException();
      }
      if (allowEncryptedEnvelope &&
          decoded['format'] != BackupEncryption.format) {
        // A legacy/unknown format must not borrow the ciphertext exception.
        _BackupJsonBudgetScanner(raw).scan();
      }
      return decoded;
    } on FormatException {
      throw const AppException(
        'backup_invalid',
        'Format file backup tidak valid.',
      );
    }
  }
}
