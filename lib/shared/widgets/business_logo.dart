import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'catalog_thumbnail.dart';
import '../../core/services/business_logo_service.dart';

/// Close the file before decoding; a failed codec must not retain a file map.
class LocalLogoImage extends FileImage {
  const LocalLogoImage(super.file);

  @override
  ImageStreamCompleter loadImage(FileImage key, ImageDecoderCallback decode) =>
      MultiFrameImageStreamCompleter(
        codec: _load(decode),
        scale: scale,
        debugLabel: 'Logo usaha',
      );

  Future<ui.Codec> _load(ImageDecoderCallback decode) async {
    final bytes = await BusinessLogoService().readSource(file.path);
    return decode(await ui.ImmutableBuffer.fromUint8List(bytes));
  }
}

class BusinessLogo extends StatelessWidget {
  const BusinessLogo({super.key, this.path, this.iconSize = 32, this.onError});
  final String? path;
  final double iconSize;
  final ImageErrorWidgetBuilder? onError;

  @override
  Widget build(BuildContext context) {
    final value = path;
    if (value == null || value.isEmpty) return placeholder;
    return CatalogThumbnail(
      image: LocalLogoImage(File(value)),
      fit: BoxFit.contain,
      errorBuilder: onError ?? (context, error, stack) => placeholder,
    );
  }

  Widget get placeholder => ColoredBox(
    color: const Color(0xFFECEEED),
    child: Center(
      child: Icon(
        Icons.storefront,
        size: iconSize,
        color: const Color(0xFFBEC9C6),
      ),
    ),
  );
}
