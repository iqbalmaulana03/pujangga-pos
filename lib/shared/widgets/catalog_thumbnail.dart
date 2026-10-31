import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Bounds decoded pixels while sharing identical sources through ImageCache.
class CatalogThumbnail extends StatelessWidget {
  const CatalogThumbnail({
    super.key,
    required this.image,
    this.fit = BoxFit.cover,
    this.errorBuilder,
  });

  final ImageProvider image;
  final BoxFit fit;
  final ImageErrorWidgetBuilder? errorBuilder;

  static void configureCache() {
    PaintingBinding.instance.imageCache
      ..maximumSizeBytes = 24 * 1024 * 1024
      ..maximumSize = 100;
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final ratio = MediaQuery.devicePixelRatioOf(context);
      // Quantization avoids separate cache entries for tiny layout differences.
      final side =
          (math.max(constraints.maxWidth, constraints.maxHeight) * ratio / 64)
              .ceil() *
          64;
      return Image(
        image: ResizeImage(
          image,
          width: side,
          height: side,
          policy: ResizeImagePolicy.fit,
        ),
        width: double.infinity,
        height: double.infinity,
        fit: fit,
        errorBuilder:
            errorBuilder ??
            (context, error, stackTrace) => const ColoredBox(
              color: Color(0xFFECEEED),
              child: Center(
                child: Icon(Icons.storefront, color: Color(0xFFBEC9C6)),
              ),
            ),
      );
    },
  );
}
