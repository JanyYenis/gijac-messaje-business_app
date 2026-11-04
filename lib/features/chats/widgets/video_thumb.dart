import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_thumbnail_gdx_plus/video_thumbnail_gdx_plus.dart';

/// Portada (primer cuadro) de un video, generada en el teléfono y guardada en caché.
class VideoThumb extends StatelessWidget {
  const VideoThumb({super.key, this.url, this.localPath, this.fallback, this.fit = BoxFit.cover});
  final String? url;
  final String? localPath;
  final Widget? fallback;
  final BoxFit fit;

  static final Map<String, Future<String?>> _cache = {};

  Future<String?> _generar() {
    final origen = localPath ?? url!;
    return _cache.putIfAbsent(origen, () async {
      try {
        final dir = (await getTemporaryDirectory()).path;
        return await VideoThumbnail.thumbnailFile(
          video: origen,
          thumbnailPath: dir,
          imageFormat: ImageFormat.JPEG,
          maxWidth: 480,
          quality: 60,
        );
      } catch (e) {
        debugPrint('⚠️ No se pudo generar la portada del video: $e');
        return null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (url == null && localPath == null) return fallback ?? const SizedBox.shrink();
    return FutureBuilder<String?>(
      future: _generar(),
      builder: (_, snap) {
        final ruta = snap.data;
        if (ruta == null) return fallback ?? const ColoredBox(color: Colors.black12);
        return Image.file(File(ruta), fit: fit, gaplessPlayback: true);
      },
    );
  }
}
