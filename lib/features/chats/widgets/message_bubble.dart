import 'dart:io';

import 'package:flutter/material.dart';
import 'package:gmb/core/services/cache_service.dart';
import 'package:just_audio/just_audio.dart';
import 'video_viewer.dart';
import 'document_viewer.dart';
import 'video_thumb.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/models/message.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/time_format.dart';

/// Renders a single chat message of any supported type.
class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.message,
    this.onRetry,
    this.onDiscard,
  });

  final Message message;

  /// Solo para mensajes locales que fallaron al enviarse
  final VoidCallback? onRetry;
  final VoidCallback? onDiscard;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Internal notes render full-width and centered.
    if (message.type == MessageType.note) {
      return _NoteCard(message: message);
    }

    final outgoing = message.isOutgoing;
    final bg = outgoing
        ? (isDark ? AppColors.bubbleOutDark : AppColors.bubbleOut)
        : (isDark ? AppColors.bubbleInDark : AppColors.bubbleIn);
    final textColor = isDark ? AppColors.textPrimaryDark : AppColors.textPrimary;

    return Align(
      alignment: outgoing ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3, horizontal: 8),
        constraints: BoxConstraints(
          maxWidth: (MediaQuery.sizeOf(context).width * 0.78).clamp(0.0, 560.0),
        ),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(14),
            topRight: const Radius.circular(14),
            bottomLeft: Radius.circular(outgoing ? 14 : 4),
            bottomRight: Radius.circular(outgoing ? 4 : 14),
          ),
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.5),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _SourceTag(source: message.source),
            _content(context, textColor),
            // Los audios manejan su propio footer con el estado
            if (message.type != MessageType.audio) 
              _footer(context, textColor),
            if (message.status == MessageStatus.failed && message.isLocal)
              _failedBar(context),
            if (message.reactions.isNotEmpty) _reactions(),
          ],
        ),
      ),
    );
  }

  Widget _content(BuildContext context, Color textColor) {
    switch (message.type) {
      case MessageType.text:
        return Text(message.text ?? '',
            style: TextStyle(color: textColor, height: 1.35));
      case MessageType.image:
        return _MediaPlaceholder(
          icon: Icons.image,
          label: 'Imagen',
          caption: message.caption,
          aspect: 1.3,
          imageUrl: message.urlArchivo,
          localPath: message.localPath,
          sending: message.status == MessageStatus.sending,
          onTap: () => _openImage(context),
        );
      case MessageType.video:
        return _MediaPlaceholder(
          icon: Icons.play_circle_fill,
          label: 'Video',
          caption: message.caption,
          aspect: 1.6,
          showPlay: true,
          imageUrl: null, // la portada se genera aparte (VideoThumb)
          videoUrl: message.urlArchivo,
          videoLocal: message.localPath,
          sending: message.status == MessageStatus.sending,
          onTap: (message.urlArchivo == null && message.localPath == null)
              ? null
              : () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => VideoViewer(url: message.urlArchivo, localPath: message.localPath),
                  )),
        );
      case MessageType.document:
      case MessageType.pdf:
        return _FileTile(message: message, textColor: textColor);
      case MessageType.audio:
        return _AudioTile(message: message, textColor: textColor); // MEJORADO
      case MessageType.location:
        return _LocationTile(message: message, textColor: textColor);
      case MessageType.buttons:
        return _ButtonsContent(message: message, textColor: textColor);
      case MessageType.list:
        return _ListContent(message: message, textColor: textColor);
      case MessageType.form:
        return _FormContent(message: message, textColor: textColor);
       case MessageType.template:
        return _TemplateContent(message: message, textColor: textColor); // NUEVO
      case MessageType.note:
        return const SizedBox.shrink();
    }
  }

  void _openImage(BuildContext context) {
    final url = message.urlArchivo;
    final local = message.localPath;
    if (url == null && local == null) return;
    Navigator.of(context).push(MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white),
        body: Center(
          child: InteractiveViewer(
            maxScale: 5,
            child: url == null
                ? Image.file(File(local!))
                : Image.network(url, errorBuilder: (_, __, ___) =>
                    const Icon(Icons.broken_image, color: Colors.white54, size: 64)),
          ),
        ),
      ),
    ));
  }

  Widget _failedBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (message.errorText != null)
            Text(message.errorText!,
                textAlign: TextAlign.end,
                style: const TextStyle(fontSize: 12, color: AppColors.danger)),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (onDiscard != null)
                TextButton(onPressed: onDiscard, child: const Text('Descartar')),
              if (onRetry != null)
                FilledButton.tonalIcon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Reintentar'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _footer(BuildContext context, Color textColor) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            TimeFormat.clock(message.time),
            style: TextStyle(
                fontSize: 11, color: textColor.withValues(alpha: 0.5)),
          ),
          if (message.isOutgoing) ...[
            const SizedBox(width: 4),
            Icon(
              message.status == MessageStatus.read ||
                      message.status == MessageStatus.delivered
                  ? Icons.done_all
                  : message.status == MessageStatus.sending
                      ? Icons.schedule
                  : message.status == MessageStatus.failed
                      ? Icons.error_outline
                      : Icons.done,
              size: 15,
              color: message.status == MessageStatus.read
                  ? AppColors.blue
                  : message.status == MessageStatus.failed
                      ? AppColors.danger
                      : textColor.withValues(alpha: 0.5),
            ),
          ],
        ],
      ),
    );
  }

  Widget _reactions() {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Wrap(
        spacing: 4,
        children: message.reactions
            .map((r) => Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(r.emoji, style: const TextStyle(fontSize: 13)),
                ))
            .toList(),
      ),
    );
  }
}

class _SourceTag extends StatelessWidget {
  const _SourceTag({required this.source});
  final MessageSource source;

  @override
  Widget build(BuildContext context) {
    final (label, color, icon) = switch (source) {
      MessageSource.ai => ('IA', AppColors.aiAccent, Icons.auto_awesome),
      MessageSource.chatbot =>
        ('Chatbot', AppColors.botAccent, Icons.smart_toy),
      MessageSource.n8n => ('n8n', AppColors.n8nAccent, Icons.account_tree),
      _ => (null, AppColors.primary, Icons.person),
    };
    if (label == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }
}

class _NoteCard extends StatelessWidget {
  const _NoteCard({required this.message});
  final Message message;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 24),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.noteAccent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.noteAccent.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.sticky_note_2, size: 18, color: AppColors.noteAccent),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Nota interna',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.noteAccent)),
                const SizedBox(height: 2),
                Text(message.text ?? '',
                    style: const TextStyle(fontSize: 13, height: 1.3)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MediaPlaceholder extends StatelessWidget {
  const _MediaPlaceholder({
    required this.icon,
    required this.label,
    required this.aspect,
    this.caption,
    this.showPlay = false,
    this.imageUrl,
    this.localPath,
    this.videoUrl,
    this.videoLocal,
    this.sending = false,
    this.onTap,
  });
  final String? videoUrl;
  final String? videoLocal;
  final IconData icon;
  final String label;
  final double aspect;
  final String? caption;
  final bool showPlay;
  final String? imageUrl;
  final String? localPath;
  final bool sending;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: onTap,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: AspectRatio(
              aspectRatio: aspect,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (imageUrl != null)
                    _buildRealImage()
                  else if (localPath != null && !showPlay)
                    Image.file(File(localPath!), fit: BoxFit.cover)
                  else if (showPlay && (videoUrl != null || videoLocal != null))
                    VideoThumb(url: videoUrl, localPath: videoLocal, fallback: _buildPlaceholder(context))
                  else
                    _buildPlaceholder(context),
                  if (showPlay && imageUrl == null)
                    Container(
                      color: Colors.black26,
                      child: const Center(
                        child: Icon(Icons.play_circle_fill, size: 50, color: Colors.white70),
                      ),
                    ),
                  if (sending)
                    Container(
                      color: Colors.black38,
                      child: const Center(
                        child: SizedBox(
                          width: 32,
                          height: 32,
                          child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        if (caption != null) ...[
          const SizedBox(height: 6),
          Text(caption!, style: const TextStyle(fontSize: 14, height: 1.3)),
        ],
      ],
    );
  }

  Widget _buildRealImage() {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.network(
          imageUrl!,
          fit: BoxFit.cover,
          cacheWidth: 700, // decodifica en pequeño: chats largos con muchas fotos no saturan la memoria
          gaplessPlayback: true,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return const Center(child: CircularProgressIndicator(strokeWidth: 2));
          },
          errorBuilder: (context, error, stackTrace) {
            final local = localPath;
            if (local != null && File(local).existsSync()) {
              return Image.file(File(local), fit: BoxFit.cover);
            }
            return _buildPlaceholder(context);
          },
        ),
        if (showPlay)
          Container(
            color: Colors.black26,
            child: const Center(
              child: Icon(Icons.play_circle_fill, size: 50, color: Colors.white70),
            ),
          ),
      ],
    );
  }

  Widget _buildPlaceholder(BuildContext context) {
    return Container(
      width: 240,
      color: Colors.black.withValues(alpha: 0.08),
      child: Center(
        child: Icon(icon, size: 48, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4)),
      ),
    );
  }
}

// --- MEJORADO: Íconos dinámicos como en tu Laravel ---
class _FileTile extends StatelessWidget {
  const _FileTile({required this.message, required this.textColor});
  final Message message;
  final Color textColor;

  // Lógica de íconos idéntica a tu Blade (str_contains)
  IconData _getFileIcon(String? fileName) {
    if (fileName == null) return Icons.insert_drive_file;
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.pdf')) return Icons.picture_as_pdf;
    if (lower.endsWith('.doc') || lower.endsWith('.docx')) return Icons.description;
    if (lower.endsWith('.xls') || lower.endsWith('.xlsx')) return Icons.table_chart;
    if (lower.endsWith('.ppt') || lower.endsWith('.pptx')) return Icons.slideshow;
    if (lower.endsWith('.zip') || lower.endsWith('.rar')) return Icons.folder_zip;
    return Icons.insert_drive_file;
  }

  Color _getFileColor(String? fileName) {
    if (fileName == null) return AppColors.blue;
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.pdf')) return AppColors.danger;
    if (lower.endsWith('.doc') || lower.endsWith('.docx')) return const Color(0xFF4CAF50); // Success Green
    if (lower.endsWith('.xls') || lower.endsWith('.xlsx')) return AppColors.blue;
    if (lower.endsWith('.ppt') || lower.endsWith('.pptx')) return const Color(0xFFFF9800); // Warning Orange
    if (lower.endsWith('.zip') || lower.endsWith('.rar')) return Colors.cyan;
    return AppColors.blue;
  }

  @override
  Widget build(BuildContext context) {
    final fileName = message.fileName ?? (message.urlArchivo?.split('/').last ?? 'Documento');
    final icon = _getFileIcon(fileName);
    final color = _getFileColor(fileName);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: (message.urlArchivo == null && message.localPath == null)
              ? null
              : () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => DocumentViewer(
                      url: message.urlArchivo,
                      localPath: message.localPath,
                      fileName: fileName,
                    ),
                  )),
          child: Container(
          width: 240,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  fileName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: textColor, fontWeight: FontWeight.w600, fontSize: 14),
                ),
              ),
              message.status == MessageStatus.sending
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : Icon(Icons.download_rounded, color: textColor.withValues(alpha: 0.6)),
            ],
          ),
        ),
        ),
        if (message.caption != null) ...[
          const SizedBox(height: 6),
          Text(message.caption!, style: TextStyle(color: textColor, fontSize: 14)),
        ],
      ],
    );
  }
}

// --- MEJORADO: Visual de Onda de Audio como en Laravel ---
class _AudioTile extends StatefulWidget {
  const _AudioTile({required this.message, required this.textColor});
  final Message message;
  final Color textColor;

  @override
  State<_AudioTile> createState() => _AudioTileState();
}

class _AudioTileState extends State<_AudioTile> {
  final AudioPlayer _player = AudioPlayer();
  final CacheService _cacheService = CacheService();
  bool _isPlaying = false;
  bool _isLoading = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  final List<double> _waveHeights = const [
    0.4, 0.7, 0.5, 0.9, 0.6, 0.8, 0.45, 0.75, 0.55, 0.85,
    0.5, 0.7, 0.4, 0.65, 0.55, 0.75, 0.45, 0.8, 0.6, 0.5
  ];

  @override
  void initState() {
    super.initState();
    _player.playerStateStream.listen((state) {
      if (!mounted) return;
      setState(() => _isPlaying = state.playing);
      if (state.processingState == ProcessingState.completed) {
        _player.seek(Duration.zero);
        _player.pause();
      }
    });
    _player.durationStream.listen((d) {
      if (d != null && mounted) setState(() => _duration = d);
    });
    _player.positionStream.listen((p) {
      if (mounted) setState(() => _position = p);
    });
  }

  Future<void> _togglePlay() async {
    try {
      if (_player.audioSource == null) {
        setState(() => _isLoading = true);
        final local = widget.message.localPath;
        final path = widget.message.urlArchivo;
        if (local != null && path == null) {
          await _player.setFilePath(local);
        } else {
          if (path == null) {
            setState(() => _isLoading = false);
            return;
          }
          String fullUrl = path;
          if (!path.startsWith('http')) {
            final server = await _cacheService.getServerUrl();
            fullUrl = '$server$path';
          }
          await _player.setUrl(fullUrl);
        }
        setState(() => _isLoading = false);
      }

      if (_isPlaying) {
        await _player.pause();
      } else {
        await _player.play();
      }
    } catch (e) {
      debugPrint('❌ Error reproduciendo audio: $e');
      setState(() => _isLoading = false);
    }
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString();
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progress = _duration.inMilliseconds > 0
        ? _position.inMilliseconds / _duration.inMilliseconds
        : 0.0;

    final ancho = MediaQuery.sizeOf(context).width * 0.6;
    return SizedBox(
      width: ancho < 260 ? ancho : 260,
      child: Row(
        children: [
          InkWell(
            onTap: _isLoading ? null : _togglePlay,
            customBorder: const CircleBorder(),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.secondary.withValues(alpha: 0.1),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      _isPlaying ? Icons.pause : Icons.play_arrow,
                      size: 28,
                      color: AppColors.secondary,
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 30,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: _waveHeights.asMap().entries.map((entry) {
                      final played = (entry.key / _waveHeights.length) <= progress;
                      return Container(
                        width: 3,
                        margin: const EdgeInsets.symmetric(horizontal: 1),
                        decoration: BoxDecoration(
                          color: (played ? AppColors.secondary : widget.textColor)
                              .withValues(alpha: played ? 0.9 : 0.5),
                          borderRadius: BorderRadius.circular(2),
                        ),
                        height: 30 * entry.value,
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  (_isPlaying || _position > Duration.zero)
                      ? _formatDuration(_position)
                      : (widget.message.duration ?? '0:00'),
                  style: TextStyle(fontSize: 11, color: widget.textColor.withValues(alpha: 0.6)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (widget.message.isOutgoing)
            Icon(
              switch (widget.message.status) {
                MessageStatus.sending => Icons.schedule,
                MessageStatus.failed => Icons.error_outline,
                MessageStatus.sent => Icons.done,
                _ => Icons.done_all,
              },
              size: 16,
              color: widget.message.status == MessageStatus.read
                  ? AppColors.blue
                  : widget.message.status == MessageStatus.failed
                      ? AppColors.danger
                      : widget.textColor.withValues(alpha: 0.6),
            )
          else
            Icon(Icons.mic_none, color: widget.textColor.withValues(alpha: 0.6), size: 22),
        ],
      ),
    );
  }
}

class _LocationTile extends StatelessWidget {
  const _LocationTile({required this.message, required this.textColor});
  final Message message;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 240,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Container(
              height: 110,
              color: AppColors.secondary.withValues(alpha: 0.12),
              child: const Center(
                child: Icon(Icons.location_on, size: 40, color: AppColors.secondary),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(message.locationName ?? 'Ubicación',
              style: TextStyle(color: textColor, fontWeight: FontWeight.w600)),
          Text(message.locationAddress ?? '',
              style: TextStyle(fontSize: 12, color: textColor.withValues(alpha: 0.6))),
        ],
      ),
    );
  }
}

class _ButtonsContent extends StatelessWidget {
  const _ButtonsContent({required this.message, required this.textColor});
  final Message message;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (message.text != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(message.text!, style: TextStyle(color: textColor, height: 1.35)),
          ),
        ...message.actions.map((a) => Container(
              width: 240,
              margin: const EdgeInsets.only(top: 4),
              child: OutlinedButton(
                onPressed: () {},
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(40),
                  foregroundColor: AppColors.secondary,
                  side: const BorderSide(color: AppColors.secondary),
                ),
                child: Text(a.label),
              ),
            )),
      ],
    );
  }
}

class _ListContent extends StatelessWidget {
  const _ListContent({required this.message, required this.textColor});
  final Message message;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 250,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (message.text != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(message.text!, style: TextStyle(color: textColor, height: 1.35)),
            ),
          ...message.actions.map((a) => Container(
                margin: const EdgeInsets.only(top: 4),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.radio_button_unchecked, size: 18, color: AppColors.secondary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(a.label, style: TextStyle(color: textColor, fontWeight: FontWeight.w600)),
                          if (a.description != null)
                            Text(a.description!, style: TextStyle(fontSize: 12, color: textColor.withValues(alpha: 0.6))),
                        ],
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}

// --- MEJORADO: Simula el "Ver Respuesta Formulario" de tu Laravel ---
class _FormContent extends StatelessWidget {
  const _FormContent({required this.message, required this.textColor});
  final Message message;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (message.text != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(message.text!, style: TextStyle(color: textColor, height: 1.35)),
          ),
        // Si no hay texto, mostramos la tarjeta genérica de Formulario (como tu btnVerFormulario)
        if (message.text == null)
          Container(
            width: 250,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.n8nAccent.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.file_copy_outlined, color: AppColors.n8nAccent, size: 24),
                const SizedBox(width: 12),
                Text('Ver Respuesta Formulario', style: TextStyle(color: textColor, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        // Si hay acciones (campos del form)
        if (message.actions.isNotEmpty)
          Container(
            width: 250,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.n8nAccent.withValues(alpha: 0.3)),
            ),
            child: Column(
              children: message.actions
                  .map((a) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(a.label, style: TextStyle(fontSize: 13, color: textColor.withValues(alpha: 0.6))),
                            Flexible(
                              child: Text(a.description ?? '', textAlign: TextAlign.end, style: TextStyle(fontSize: 13, color: textColor, fontWeight: FontWeight.w600)),
                            ),
                          ],
                        ),
                      ))
                  .toList(),
            ),
          ),
      ],
    );
  }
}

// --- NUEVO: Dibuja Plantillas de WhatsApp (Header + Texto + Botones) ---
class _TemplateContent extends StatelessWidget {
  const _TemplateContent({required this.message, required this.textColor});
  final Message message;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. HEADER (Imagen, Video o Documento)
        if (message.templateHeaderUrl != null) ...[
          _buildHeader(context),
          const SizedBox(height: 8),
        ],
        
        // 2. TEXTO (Body)
        if (message.text != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(message.text!, style: TextStyle(color: textColor, height: 1.35)),
          ),

        // 3. BOTONES
        if (message.actions.isNotEmpty)
          ...message.actions.map((a) => Container(
                width: 240,
                margin: const EdgeInsets.only(top: 4),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      a.description == 'Teléfono' ? Icons.phone_outlined : Icons.open_in_new,
                      size: 18, 
                      color: AppColors.secondary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(a.label, style: TextStyle(color: textColor, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              )),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    switch (message.templateHeaderType) {
      case MessageType.image:
        return ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.network(
            message.templateHeaderUrl!,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              return const Center(child: CircularProgressIndicator(strokeWidth: 2));
            },
            errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, size: 50),
          ),
        );
      case MessageType.video:
        // En plantillas, el "video" suele ser solo una imagen de portada
        return ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Image.network(message.templateHeaderUrl!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox()),
              Container(color: Colors.black26, child: const Icon(Icons.play_circle_fill, size: 50, color: Colors.white70)),
            ],
          ),
        );
      case MessageType.document:
        // Reutilizamos la lógica de archivo
        return _FileTile(
          message: Message(
            id: '', 
            type: MessageType.document, 
            source: MessageSource.agent, 
            time: DateTime.now(), 
            urlArchivo: message.templateHeaderUrl,
            fileName: message.templateHeaderUrl?.split('/').last,
          ), 
          textColor: textColor
        );
      default:
        return const SizedBox.shrink();
    }
  }
}

/// Abre un archivo (documento, video) con la app del teléfono o el navegador.
Future<void> _openExternal(BuildContext context, String url) async {
  final ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  if (!ok && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('No se pudo abrir el archivo.')),
    );
  }
}