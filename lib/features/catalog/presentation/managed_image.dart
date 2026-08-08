import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../domain/repositories/media_store.dart';

class ManagedImage extends StatelessWidget {
  const ManagedImage({
    super.key,
    required this.imageRef,
    required this.mediaStore,
    required this.fallback,
    this.height,
    this.width,
    this.fit = BoxFit.cover,
  });

  final String? imageRef;
  final MediaStore mediaStore;
  final Widget fallback;
  final double? height;
  final double? width;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final ref = imageRef;
    if (ref == null) return _fallback();
    return FutureBuilder<Uint8List?>(
      future: mediaStore.read(ref),
      builder: (context, snapshot) {
        final bytes = snapshot.data;
        if (bytes == null || bytes.isEmpty) return _fallback();
        return Image.memory(
          bytes,
          fit: fit,
          cacheWidth: 512,
          cacheHeight: 512,
          height: height,
          width: width,
          errorBuilder: (_, _, _) => _fallback(),
        );
      },
    );
  }

  Widget _fallback() => SizedBox(
    height: height,
    width: width,
    child: Center(child: fallback),
  );
}
