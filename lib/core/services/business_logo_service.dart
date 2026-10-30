import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../errors/app_exception.dart';

final businessLogoServiceProvider = Provider((ref) => BusinessLogoService());

/// Owns only files in business_logos and logo_drafts, never source images.
class BusinessLogoService {
  BusinessLogoService({this.supportDirectory, this.temporaryDirectory});

  final Future<Directory> Function()? supportDirectory;
  final Future<Directory> Function()? temporaryDirectory;
  static const maxInputBytes = 10 * 1024 * 1024;
  static const maxBackupBytes = 5 * 1024 * 1024;
  static Future<void> _pending = Future.value();
  bool _cleaned = false;

  Future<void> cleanupOnStartup(Future<String?> Function() activePath) =>
      synchronized(() async {
        if (_cleaned) return;
        _cleaned = true;
        try {
          await cleanup(await activePath());
        } catch (_) {
          /* Best effort; never block startup. */
        }
      });

  Future<T> synchronized<T>(Future<T> Function() operation) {
    final result = _pending.then((_) => operation());
    _pending = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace stack) {},
    );
    return result;
  }

  Future<Directory> _directory({bool draft = false}) async {
    final parent = draft
        ? await (temporaryDirectory?.call() ?? getTemporaryDirectory())
        : await (supportDirectory?.call() ?? getApplicationSupportDirectory());
    return Directory(
      p.join(parent.path, draft ? 'logo_drafts' : 'business_logos'),
    );
  }

  Future<Uint8List> readSource(String path) async {
    final file = File(path);
    if (await file.length() > maxInputBytes) {
      throw const AppException('logo_size', 'Ukuran logo maksimal 10 MiB.');
    }
    // Bound reads as well as the initial stat, in case a source changes.
    final bytes = BytesBuilder(copy: false);
    await for (final chunk in file.openRead(0, maxInputBytes + 1)) {
      bytes.add(chunk);
      if (bytes.length > maxInputBytes) {
        throw const AppException('logo_size', 'Ukuran logo maksimal 10 MiB.');
      }
    }
    return bytes.takeBytes();
  }

  bool _png(Uint8List b) =>
      b.length >= 8 &&
      b[0] == 137 &&
      b[1] == 80 &&
      b[2] == 78 &&
      b[3] == 71 &&
      b[4] == 13 &&
      b[5] == 10 &&
      b[6] == 26 &&
      b[7] == 10;

  Future<Uint8List> normalize(Uint8List bytes, {bool backup = false}) async {
    final jpeg =
        bytes.length > 3 &&
        bytes[0] == 255 &&
        bytes[1] == 216 &&
        bytes[2] == 255;
    final webp =
        bytes.length >= 12 &&
        String.fromCharCodes(bytes.sublist(0, 4)) == 'RIFF' &&
        String.fromCharCodes(bytes.sublist(8, 12)) == 'WEBP';
    if (bytes.length > (backup ? maxBackupBytes : maxInputBytes) ||
        !(_png(bytes) || (!backup && (jpeg || webp)))) {
      throw const AppException(
        'logo_invalid',
        'Gunakan gambar PNG, JPEG, atau WebP statis yang valid.',
      );
    }
    try {
      final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
      try {
        final descriptor = await ui.ImageDescriptor.encoded(buffer);
        try {
          final w = descriptor.width;
          final h = descriptor.height;
          if (w <= 0 ||
              h <= 0 ||
              w > 8192 ||
              h > 8192 ||
              w * h > 16777216 ||
              (backup && (w > 1024 || h > 1024))) {
            throw const AppException(
              'logo_dimensions',
              'Logo maksimal 16 megapiksel dan 8.192 piksel per sisi.',
            );
          }
          final scale = math.min(1.0, 1024 / math.max(w, h));
          final codec = await descriptor.instantiateCodec(
            targetWidth: math.max(1, (w * scale).round()),
            targetHeight: math.max(1, (h * scale).round()),
          );
          try {
            if (codec.frameCount != 1) {
              throw const AppException(
                'logo_animated',
                'Logo animasi belum didukung. Pilih gambar statis.',
              );
            }
            final frame = await codec.getNextFrame();
            try {
              final data = await frame.image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              if (data == null || data.lengthInBytes > maxBackupBytes) {
                throw const AppException(
                  'logo_invalid',
                  'Logo tidak dapat diproses.',
                );
              }
              return data.buffer.asUint8List(
                data.offsetInBytes,
                data.lengthInBytes,
              );
            } finally {
              frame.image.dispose();
            }
          } finally {
            codec.dispose();
          }
        } finally {
          descriptor.dispose();
        }
      } finally {
        buffer.dispose();
      }
    } on AppException {
      rethrow;
    } catch (_) {
      throw const AppException(
        'logo_invalid',
        'Gambar logo rusak atau tidak dapat dibaca.',
      );
    }
  }

  Future<String> write(Uint8List png, {bool draft = false}) async {
    final directory = await _directory(draft: draft);
    await directory.create(recursive: true);
    final random = math.Random.secure();
    final name = List.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    final target = File(p.join(directory.path, '$name.png'));
    final temporary = File('${target.path}.tmp');
    try {
      await temporary.writeAsBytes(png, flush: true);
      await temporary.rename(target.path);
      return target.path;
    } catch (_) {
      if (await temporary.exists()) await temporary.delete();
      rethrow;
    }
  }

  Future<bool> owns(String path, {bool draft = false}) async {
    final directory = await _directory(draft: draft);
    return p.equals(p.dirname(p.absolute(path)), p.absolute(directory.path)) &&
        RegExp(r'^[0-9a-f]{32}\.png(?:\.tmp)?$').hasMatch(p.basename(path));
  }

  Future<void> deleteOwned(String? path, {bool draft = false}) async {
    if (path == null) return;
    try {
      if (await owns(path, draft: draft)) {
        await File(path).delete();
      }
    } catch (_) {
      /* Cleanup must not turn a committed save into an apparent failure.
         Retry orphan cleanup on next startup. */
    }
  }

  Future<void> cleanup(String? activePath) async {
    for (final draft in [false, true]) {
      final directory = await _directory(draft: draft);
      if (!await directory.exists()) continue;
      await for (final entity in directory.list(followLinks: false)) {
        if (entity is File && entity.path != activePath) {
          await deleteOwned(entity.path, draft: draft);
        }
      }
    }
  }
}
