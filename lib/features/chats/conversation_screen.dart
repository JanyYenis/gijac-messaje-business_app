import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../../core/models/message.dart';
import '../../core/providers/app_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/time_format.dart';
import '../../widgets/app_avatar.dart';
import 'widgets/message_bubble.dart';

class ConversationScreen extends ConsumerStatefulWidget {
  const ConversationScreen({super.key, required this.chatId, this.nombre});
  final String chatId;
  final String? nombre;

  @override
  ConsumerState<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends ConsumerState<ConversationScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  bool _mostrarBajar = false; // botón para volver al último mensaje

  // Refresco automático (estados y mensajes nuevos) mientras el chat está abierto
  late final ConversationNotifier _conversacion;

  // Grabación de audio
  final AudioRecorder _grabadora = AudioRecorder();
  bool _grabando = false;
  int _segundos = 0;
  Timer? _grabacionTimer;
  static const _maxAudioSeg = 5 * 60;

  @override
  void initState() {
    super.initState();
    _conversacion = ref.read(conversationProvider.notifier);

    // AGREGADO: Listener para paginación (cargar mensajes antiguos al hacer scroll arriba)
    _scrollController.addListener(_onScroll);

    // AGREGADO: Cargar mensajes de la API al entrar
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(conversationProvider.notifier).loadMessages(widget.chatId);
    });
  }

  @override
  void dispose() {
    _conversacion.leaveChat(widget.chatId);
    _grabacionTimer?.cancel();
    _grabadora.dispose();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // AGREGADO: Lógica de scroll para cargar historia
  // La lista está invertida (reverse): offset 0 = último mensaje, y el final del scroll = los más antiguos.
  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 300) {
      ref.read(conversationProvider.notifier).loadOlderMessages(widget.chatId);
    }
    final lejos = pos.pixels > 400;
    if (lejos != _mostrarBajar) setState(() => _mostrarBajar = lejos);
  }

  // MODIFICADO: Ahora llama a la API real
  void _send() {
    final text = _controller.text;
    if (text.trim().isEmpty) return;

    _controller.clear();

    ref.read(conversationProvider.notifier).sendMessage(widget.chatId, text);
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  bool get _nearBottom => !_scrollController.hasClients || _scrollController.offset < 200;

  // ------------------------------------------------------------------- audio

  Future<void> _iniciarGrabacion() async {
    try {
      if (!await _grabadora.hasPermission()) {
        _aviso('Da permiso al micrófono para grabar audios.');
        return;
      }
      final dir = await getTemporaryDirectory();
      final ruta = '${dir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _grabadora.start(
        const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 64000, sampleRate: 44100),
        path: ruta,
      );
      setState(() {
        _grabando = true;
        _segundos = 0;
      });
      _grabacionTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() => _segundos++);
        if (_segundos >= _maxAudioSeg) _terminarGrabacion(enviar: true);
      });
    } catch (e) {
      _aviso('No se pudo iniciar la grabación.');
    }
  }

  Future<void> _terminarGrabacion({required bool enviar}) async {
    _grabacionTimer?.cancel();
    final duracion = _segundos;
    String? ruta;
    try {
      ruta = await _grabadora.stop();
    } catch (_) {}
    if (mounted) setState(() => _grabando = false);
    if (ruta == null) return;

    final archivo = File(ruta);
    if (!enviar || duracion < 1) {
      if (await archivo.exists()) await archivo.delete();
      return;
    }
    ref.read(conversationProvider.notifier).sendMedia(
          widget.chatId,
          archivo,
          MessageType.audio,
          fileName: archivo.uri.pathSegments.last,
        );
    _scrollToBottom();
  }

  // ---------------------------------------------------------------- archivos

  static const _maxImagen = 5 * 1024 * 1024;
  static const _maxVideo = 16 * 1024 * 1024;
  static const _maxDocumento = 100 * 1024 * 1024;

  void _aviso(String texto) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(texto)));
  }

  Future<void> _elegirImagen(ImageSource fuente) async {
    try {
      final x = await ImagePicker().pickImage(source: fuente, imageQuality: 80, maxWidth: 2048);
      if (x == null) return;
      await _confirmarEnvio(File(x.path), MessageType.image, x.name);
    } catch (e) {
      _aviso('No se pudo abrir la ${fuente == ImageSource.camera ? 'cámara' : 'galería'}.');
    }
  }

  Future<void> _elegirVideo() async {
    try {
      final x = await ImagePicker().pickVideo(source: ImageSource.gallery);
      if (x == null) return;
      await _confirmarEnvio(File(x.path), MessageType.video, x.name);
    } catch (e) {
      _aviso('No se pudo abrir la galería.');
    }
  }

  Future<void> _elegirDocumento() async {
    try {
      final r = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx', 'txt'],
      );
      final path = r?.files.single.path;
      if (path == null) return;
      await _confirmarEnvio(File(path), MessageType.document, r!.files.single.name);
    } catch (e) {
      _aviso('No se pudo abrir el selector de archivos.');
    }
  }

  /// Vista previa con texto opcional antes de enviar
  Future<void> _confirmarEnvio(File file, MessageType type, String nombre) async {
    final tam = await file.length();
    final max = switch (type) {
      MessageType.image => _maxImagen,
      MessageType.video => _maxVideo,
      _ => _maxDocumento,
    };
    if (tam > max) {
      _aviso('El archivo pesa ${(tam / 1048576).toStringAsFixed(1)} MB y WhatsApp admite máximo ${max ~/ 1048576} MB.');
      return;
    }
    if (!mounted) return;

    // El TextEditingController vive dentro del propio sheet: si se destruyera aquí, mientras el sheet
    // todavía se está cerrando, la app se caía al enviar una imagen con texto.
    final texto = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => _VistaPreviaEnvio(file: file, type: type, nombre: nombre, tam: tam),
    );
    if (texto == null) return;

    ref.read(conversationProvider.notifier).sendMedia(
          widget.chatId,
          file,
          type,
          caption: texto,
          fileName: nombre,
        );
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    // Seguimos usando chatsProvider para obtener los datos del CONTACTO (nombre, avatar, estado)
    final chat = ref.watch(chatsProvider).where((c) => c.id == widget.chatId).firstOrNull;
    if (chat == null) {
      // La lista de chats aún no cargó (o el contacto es nuevo): se muestra el chat con lo que se sabe
      return Scaffold(
        appBar: AppBar(title: Text(widget.nombre ?? widget.chatId)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // Avisos de error de envío
    ref.listen<String?>(conversationErrorProvider, (_, error) {
      if (error != null) {
        _aviso(error);
        ref.read(conversationErrorProvider.notifier).state = null;
      }
    });
    // Bajar automáticamente cuando llega un mensaje y el usuario está al final
    ref.listen<List<Message>>(conversationProvider, (prev, next) {
      if (prev != null && next.length > prev.length && _nearBottom) _scrollToBottom();
    });
    
    // AGREGADO: Ahora escuchamos los mensajes reales de la API
    final messages = ref.watch(conversationProvider);
    final isLoading = ref.watch(isConversationLoadingProvider);

    
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final items = _withDateDividers(messages);

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.backgroundDark : const Color(0xFFEDE7DF),
      appBar: AppBar(
        titleSpacing: 0,
        title: InkWell(
          onTap: () => context.push('/chats/${chat.id}/contact'),
          child: Row(
            children: [
              AppAvatar(
                initials: chat.contact.initials,
                colorValue: chat.contact.avatarColorValue,
                isOnline: chat.contact.isOnline,
                radius: 18,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(chat.contact.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700)),
                    Text(
                      chat.contact.isOnline ? 'en línea' : 'últ. vez hoy',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: chat.contact.isOnline
                            ? AppColors.primary
                            : theme.colorScheme.onSurface
                                .withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          PopupMenuButton<String>(
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'info', child: Text('Ver contacto')),
              PopupMenuItem(value: 'note', child: Text('Agregar nota interna')),
              PopupMenuItem(value: 'resolve', child: Text('Marcar resuelto')),
              PopupMenuItem(value: 'ai', child: Text('Activar respuesta IA')),
            ],
            onSelected: (v) {
              if (v == 'info') context.push('/chats/${chat.id}/contact');
            },
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
        children: [
          Expanded(
            // AGREGADO: Mostrar indicador de carga la primera vez
            child: isLoading && messages.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : Stack(
                    children: [
                      Positioned.fill(
                        // reverse: la conversación queda anclada al último mensaje aunque las imágenes tarden en cargar
                        child: ListView.builder(
                    controller: _scrollController,
                    reverse: true,
                    cacheExtent: 600,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    itemCount: items.length,
                    itemBuilder: (_, i) {
                      final item = items[items.length - 1 - i];
                      if (item is DateTime) return _DateDivider(date: item);
                      final m = item as Message;
                      return MessageBubble(
                        message: m,
                        onRetry: m.status == MessageStatus.failed && m.isLocal
                            ? () => ref.read(conversationProvider.notifier).retry(widget.chatId, m.id)
                            : null,
                        onDiscard: m.status == MessageStatus.failed && m.isLocal
                            ? () => ref.read(conversationProvider.notifier).discard(m.id)
                            : null,
                      );
                    },
                  ),
                      ),
                      if (_mostrarBajar)
                        Positioned(
                          right: 12,
                          bottom: 12,
                          child: FloatingActionButton.small(
                            heroTag: 'bajar',
                            onPressed: _scrollToBottom,
                            child: const Icon(Icons.keyboard_arrow_down),
                          ),
                        ),
                    ],
                  ),
          ),
          _Composer(
            controller: _controller,
            onSend: _send,
            onAttach: () => _showAttachSheet(context),
            recording: _grabando,
            seconds: _segundos,
            onRecordStart: _iniciarGrabacion,
            onRecordCancel: () => _terminarGrabacion(enviar: false),
            onRecordSend: () => _terminarGrabacion(enviar: true),
          ),
        ],
          ),
        ),
      ),
    );
  }

  /// Interleaves date divider markers between messages.
  List<Object> _withDateDividers(List<Message> messages) {
    final out = <Object>[];
    DateTime? lastDay;
    for (final m in messages) {
      final day = DateTime(m.time.year, m.time.month, m.time.day);
      if (lastDay == null || day != lastDay) {
        out.add(m.time);
        lastDay = day;
      }
      out.add(m);
    }
    return out;
  }

  void _showAttachSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        void elegir(VoidCallback accion) {
          Navigator.pop(sheetContext);
          accion();
        }

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: Wrap(
              alignment: WrapAlignment.spaceEvenly,
              runSpacing: 20,
              children: [
                _AttachOption(
                  icon: Icons.photo_camera,
                  label: 'Cámara',
                  color: AppColors.primary,
                  onTap: () => elegir(() => _elegirImagen(ImageSource.camera)),
                ),
                _AttachOption(
                  icon: Icons.image,
                  label: 'Galería',
                  color: AppColors.blue,
                  onTap: () => elegir(() => _elegirImagen(ImageSource.gallery)),
                ),
                _AttachOption(
                  icon: Icons.videocam,
                  label: 'Video',
                  color: AppColors.aiAccent,
                  onTap: () => elegir(_elegirVideo),
                ),
                _AttachOption(
                  icon: Icons.insert_drive_file,
                  label: 'Documento',
                  color: AppColors.secondary,
                  onTap: () => elegir(_elegirDocumento),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _DateDivider extends StatelessWidget {
  const _DateDivider({required this.date});
  final DateTime date;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 10),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          TimeFormat.dayLabel(date),
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class _Composer extends StatefulWidget {
  const _Composer({
    required this.controller,
    required this.onSend,
    required this.onAttach,
    required this.recording,
    required this.seconds,
    required this.onRecordStart,
    required this.onRecordCancel,
    required this.onRecordSend,
  });
  final TextEditingController controller;
  final VoidCallback onSend;
  final VoidCallback onAttach;
  final bool recording;
  final int seconds;
  final VoidCallback onRecordStart;
  final VoidCallback onRecordCancel;
  final VoidCallback onRecordSend;

  @override
  State<_Composer> createState() => _ComposerState();
}

class _ComposerState extends State<_Composer> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_cambio);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_cambio);
    super.dispose();
  }

  void _cambio() => setState(() {});

  String _tiempo(int s) => '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hayTexto = widget.controller.text.trim().isNotEmpty;

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
        color: theme.colorScheme.surface,
        child: widget.recording
            ? Row(
                children: [
                  IconButton(
                    onPressed: widget.onRecordCancel,
                    icon: const Icon(Icons.delete_outline, color: AppColors.danger),
                    tooltip: 'Cancelar',
                  ),
                  const Icon(Icons.fiber_manual_record, color: AppColors.danger, size: 14),
                  const SizedBox(width: 8),
                  Text(_tiempo(widget.seconds),
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text('Grabando…',
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall),
                  ),
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: AppColors.primary,
                    child: IconButton(
                      onPressed: widget.onRecordSend,
                      icon: const Icon(Icons.send, color: Colors.white, size: 20),
                    ),
                  ),
                ],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  IconButton(
                      onPressed: widget.onAttach,
                      icon: const Icon(Icons.add_circle_outline)),
                  Expanded(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 120),
                      child: TextField(
                        controller: widget.controller,
                        minLines: 1,
                        maxLines: 5,
                        textInputAction: TextInputAction.newline,
                        decoration: const InputDecoration(
                          hintText: 'Escribe un mensaje',
                          contentPadding:
                              EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: AppColors.primary,
                    child: IconButton(
                      onPressed: hayTexto ? widget.onSend : widget.onRecordStart,
                      icon: Icon(hayTexto ? Icons.send : Icons.mic,
                          color: Colors.white, size: 22),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _AttachOption extends StatelessWidget {
  const _AttachOption({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 80,
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(30),
            onTap: onTap,
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 26),
            ),
          ),
          const SizedBox(height: 6),
          Text(label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}

/// Vista previa del archivo con texto opcional antes de enviar. Devuelve el texto (o null si se cancela).
class _VistaPreviaEnvio extends StatefulWidget {
  const _VistaPreviaEnvio({required this.file, required this.type, required this.nombre, required this.tam});
  final File file;
  final MessageType type;
  final String nombre;
  final int tam;

  @override
  State<_VistaPreviaEnvio> createState() => _VistaPreviaEnvioState();
}

class _VistaPreviaEnvioState extends State<_VistaPreviaEnvio> {
  final _caption = TextEditingController();

  @override
  void dispose() {
    _caption.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext ctx) {
    final type = widget.type;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, MediaQuery.viewInsetsOf(ctx).bottom + 16),
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: type == MessageType.image
                      ? ConstrainedBox(
                          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * 0.4),
                          child: Image.file(widget.file, fit: BoxFit.contain, cacheWidth: 1200),
                        )
                      : Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          color: Colors.black.withValues(alpha: 0.06),
                          child: Row(
                            children: [
                              Icon(type == MessageType.video ? Icons.videocam : Icons.insert_drive_file, size: 36),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(widget.nombre,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontWeight: FontWeight.w700)),
                                    Text('${(widget.tam / 1048576).toStringAsFixed(1)} MB',
                                        style: Theme.of(ctx).textTheme.bodySmall),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _caption,
                  maxLength: 1024,
                  minLines: 1,
                  maxLines: 3,
                  decoration: const InputDecoration(hintText: 'Agrega un texto (opcional)', counterText: ''),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Cancelar'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => Navigator.pop(ctx, _caption.text),
                        icon: const Icon(Icons.send),
                        label: const Text('Enviar'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}