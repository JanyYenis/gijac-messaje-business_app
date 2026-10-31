import 'dart:io';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

import 'video_thumb.dart';

/// Reproductor de video a pantalla completa (desde la URL del servidor o el archivo local).
class VideoViewer extends StatefulWidget {
  const VideoViewer({super.key, this.url, this.localPath});
  final String? url;
  final String? localPath;

  @override
  State<VideoViewer> createState() => _VideoViewerState();
}

class _VideoViewerState extends State<VideoViewer> {
  VideoPlayerController? _c;
  bool _error = false;
  String _detalle = '';

  @override
  void initState() {
    super.initState();
    _iniciar();
  }

  Future<void> _iniciar() async {
    try {
      final url = widget.url;
      final local = widget.localPath;
      final c = (url != null)
          ? VideoPlayerController.networkUrl(Uri.parse(url))
          : VideoPlayerController.file(File(local!));
      _c = c;
      await c.initialize();
      c.addListener(() {
        if (mounted) setState(() {});
      });
      await c.play();
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('❌ Error reproduciendo video (${widget.url}): $e');
      if (mounted) {
        setState(() {
          _error = true;
          _detalle = e.toString();
        });
      }
    }
  }

  @override
  void dispose() {
    _c?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _c;
    final listo = c != null && c.value.isInitialized;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white),
      body: Center(
        child: _error
            ? Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('No se pudo reproducir el video aquí.',
                        textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 16)),
                    const SizedBox(height: 8),
                    Text(_detalle,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white54, fontSize: 12)),
                    if (widget.url != null) ...[
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: () => launchUrl(Uri.parse(widget.url!), mode: LaunchMode.externalApplication),
                        icon: const Icon(Icons.open_in_new),
                        label: const Text('Abrir en otra app'),
                      ),
                    ],
                  ],
                ),
              )
            : !listo
                ? Stack(
                    alignment: Alignment.center,
                    children: [
                      Positioned.fill(
                        child: Opacity(
                          opacity: 0.5,
                          child: VideoThumb(url: widget.url, localPath: widget.localPath, fit: BoxFit.contain),
                        ),
                      ),
                      const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(color: Colors.white),
                          SizedBox(height: 12),
                          Text('Cargando video…', style: TextStyle(color: Colors.white70)),
                        ],
                      ),
                    ],
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AspectRatio(
                        aspectRatio: c.value.aspectRatio == 0 ? 16 / 9 : c.value.aspectRatio,
                        child: GestureDetector(
                          onTap: () => c.value.isPlaying ? c.pause() : c.play(),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              VideoPlayer(c),
                              if (!c.value.isPlaying)
                                const Icon(Icons.play_circle_fill, size: 64, color: Colors.white70),
                            ],
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: VideoProgressIndicator(c, allowScrubbing: true),
                      ),
                    ],
                  ),
      ),
    );
  }
}