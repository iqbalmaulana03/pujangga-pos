import 'dart:convert';
import 'dart:isolate';

import 'package:cryptography/cryptography.dart';

import '../../../../core/errors/app_exception.dart';

/// Portable v1 envelope. All parameters are fixed and checked before the KDF.
/// Only the authenticated plaintext is passed to the existing restore parser.
class BackupEncryption {
  static const format = 'pujangga_pos_encrypted_backup';
  static const iterations = 600000;
  static const maxPlaintextBytes = 64 * 1024 * 1024;
  static const _aad = '$format:1:AES-256-GCM:PBKDF2-HMAC-SHA256:600000';

  static Future<SecretKey> _key(String password, List<int> salt) => Pbkdf2(
    macAlgorithm: Hmac.sha256(),
    iterations: iterations,
    bits: 256,
  ).deriveKey(secretKey: SecretKey(utf8.encode(password)), nonce: salt);

  static Future<String> encrypt(String plaintext, String password) {
    if (password.length < 12) {
      throw const AppException(
        'backup_password_weak',
        'Gunakan kata sandi minimal 12 karakter.',
      );
    }
    return Isolate.run(() async {
      final bytes = utf8.encode(plaintext);
      if (bytes.length > maxPlaintextBytes) throw _invalid;
      // SecretKeyData.random uses the library's secure random generator.
      final salt = SecretKeyData.random(length: 16).bytes;
      final algorithm = AesGcm.with256bits();
      final box = await algorithm.encrypt(
        bytes,
        secretKey: await _key(password, salt),
        nonce: algorithm.newNonce(),
        aad: utf8.encode(_aad),
      );
      return jsonEncode({
        'format': format,
        'format_version': 1,
        'cipher': 'AES-256-GCM',
        'kdf': 'PBKDF2-HMAC-SHA256',
        'iterations': iterations,
        'salt': base64Encode(salt),
        'nonce': base64Encode(box.nonce),
        'ciphertext': base64Encode(box.cipherText),
        'tag': base64Encode(box.mac.bytes),
      });
    });
  }

  static Future<String> decrypt(
    Map<String, dynamic> envelope,
    String? password,
  ) {
    List<int> field(String name, {int? length}) {
      final value = envelope[name];
      if (value is! String ||
          value.length > ((maxPlaintextBytes + 2) ~/ 3) * 4) {
        throw _invalid;
      }
      try {
        final bytes = base64Decode(value);
        if (length != null && bytes.length != length) throw _invalid;
        if (bytes.length > maxPlaintextBytes) throw _invalid;
        return bytes;
      } on FormatException {
        throw _invalid;
      }
    }

    if (envelope['format'] != format ||
        envelope['format_version'] != 1 ||
        envelope['cipher'] != 'AES-256-GCM' ||
        envelope['kdf'] != 'PBKDF2-HMAC-SHA256' ||
        envelope['iterations'] != iterations) {
      throw _invalid;
    }
    final salt = field('salt', length: 16);
    final nonce = field('nonce', length: 12);
    final ciphertext = field('ciphertext');
    final tag = field('tag', length: 16);
    if (password == null) {
      throw const AppException(
        'backup_password_required',
        'Masukkan kata sandi cadangan ini.',
      );
    }
    return Isolate.run(() async {
      try {
        final bytes = await AesGcm.with256bits().decrypt(
          SecretBox(ciphertext, nonce: nonce, mac: Mac(tag)),
          secretKey: await _key(password, salt),
          aad: utf8.encode(_aad),
        );
        return utf8.decode(bytes);
      } on SecretBoxAuthenticationError {
        throw const AppException(
          'backup_authentication_failed',
          'Kata sandi salah atau file cadangan telah berubah.',
        );
      }
    });
  }

  static const _invalid = AppException(
    'backup_encryption_invalid',
    'Format atau ukuran cadangan terenkripsi tidak didukung.',
  );
}
