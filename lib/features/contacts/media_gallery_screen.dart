import 'package:flutter/material.dart';

import '../../core/models/message.dart';
import '../../core/services/api_service.dart';
import '../../core/utils/time_format.dart';
import '../chats/widgets/document_viewer.dart';
import '../chats/widgets/video_thumb.dart';
import '../chats/widgets/video_viewer.dart';

/// Multimedia compartida del chat, como en WhatsApp: pestañas Multimedia (fotos y videos) y Documentos.
class MediaGalleryScreen extends StatelessWidget {
  const MediaGalleryScreen({super.key, required this.chatId, required this.titulo});
  final String chatId;
  final String titulo;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(titulo, overflow: TextOverflow.ellipsis),
          bottom: const TabBar(tabs: [Tab(text: 'Multimedia'), Tab(text: 'Documentos')]),
        ),
        body: TabBarView(
          children: [
            _GaleriaTab(chatId: chatId, tipo: 'media'),
            _GaleriaTab(chatId: chatId, tipo: 'documentos'),
          ],
        ),
      ),
    );
  }
}

class _GaleriaTab extends StatefulWidget {
  const _GaleriaTab({required this.chatId, required this.tipo});
  final String chatId;
  final String tipo;

  @override
  State<_GaleriaTab> createState() => _GaleriaTabState();
}

class _GaleriaTabState extends State<_GaleriaTab> with AutomaticKeepAliveClientMixin {
  final _api = ApiService();
  final _scroll = ScrollController();
  final List<Message> _items = [];
  bool _cargando = true;
  bool _cargandoMas = false;
  bool _fin = false;
  String? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 400) _cargarMas();
    });
    _cargar();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final r = await _api.getMultimedia(widget.chatId, tipo: widget.tipo);
      if (!mounted) return;
      setState(() {
        _items
          ..clear()
          ..addAll(r);
        _fin = r.length < 60;
        _cargando = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'No se pudo cargar. Revisa tu conexión.';
          _cargando = false;
        });
      }
    }
  }

  Future<void> _cargarMas() async {
    if (_cargandoMas || _fin || _items.isEmpty) return;
    setState(() => _cargandoMas = true);
    try {
      final r = await _api.getMultimedia(widget.chatId, tipo: widget.tipo, beforeId: _items.last.id);
      if (!mounted) return;
      setState(() {
        _items.addAll(r);
        _fin = r.length < 60;
        _cargandoMas = false;
      });
    } catch (_) {
      if (mounted) setState(() => _cargandoMas = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_cargando) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(_error!),
          const SizedBox(height: 12),
          FilledButton(onPressed: _cargar, child: const Text('Reintentar')),
        ]),
      );
    }
    if (_items.isEmpty) {
      return Center(
        child: Text(widget.tipo == 'media' ? 'Aún no hay fotos ni videos' : 'Aún no hay documentos'),
      );
    }
    return widget.tipo == 'media' ? _cuadricula() : _lista();
  }

  Widget _cuadricula() {
    return GridView.builder(
      controller: _scroll,
      padding: const EdgeInsets.all(2),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 2,
        crossAxisSpacing: 2,
      ),
      itemCount: _items.length,
      itemBuilder: (_, i) => MediaThumb(
        mensaje: _items[i],
        onTap: () => abrirMultimedia(context, _items, i),
      ),
    );
  }

  Widget _lista() {
    return ListView.separated(
      controller: _scroll,
      itemCount: _items.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (_, i) {
        final m = _items[i];
        final nombre = m.fileName ?? m.caption ?? 'Documento';
        return ListTile(
          leading: const Icon(Icons.insert_drive_file_outlined),
          title: Text(nombre, maxLines: 2, overflow: TextOverflow.ellipsis),
          subtitle: Text([if (m.fileSize != null) m.fileSize!, TimeFormat.dayLabel(m.time)].join(' · ')),
          onTap: m.urlArchivo == null
              ? null
              : () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => DocumentViewer(url: m.urlArchivo, fileName: nombre),
                  )),
        );
      },
    );
  }
}

/// Miniatura cuadrada de una foto o un video
class MediaThumb extends StatelessWidget {
  const MediaThumb({super.key, required this.mensaje, required this.onTap});
  final Message mensaje;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final esVideo = mensaje.type == MessageType.video;
    final url = mensaje.urlArchivo;
    final fondo = Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Icon(esVideo ? Icons.videocam_outlined : Icons.image_outlined),
    );

    Widget imagen;
    if (url == null) {
      imagen = fondo;
    } else if (esVideo) {
      imagen = VideoThumb(url: url, fallback: fondo);
    } else {
      imagen = Image.network(
        url,
        fit: BoxFit.cover,
        cacheWidth: 360,
        errorBuilder: (_, __, ___) => fondo,
      );
    }

    return GestureDetector(
      onTap: onTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          imagen,
          if (esVideo)
            const Center(child: Icon(Icons.play_circle_fill, color: Colors.white, size: 30)),
        ],
      ),
    );
  }
}

/// Abre la foto o el video tocado; las fotos se pueden pasar con el dedo (solo las fotos de la lista).
void abrirMultimedia(BuildContext context, List<Message> lista, int indice) {
  final m = lista[indice];
  if (m.urlArchivo == null) return;

  if (m.type == MessageType.video) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => VideoViewer(url: m.urlArchivo)));
    return;
  }

  final fotos = lista.where((x) => x.type == MessageType.image && x.urlArchivo != null).toList();
  final inicio = fotos.indexWhere((x) => x.id == m.id);
  Navigator.of(context).push(MaterialPageRoute(
    fullscreenDialog: true,
    builder: (_) => _VisorFotos(fotos: fotos, inicio: inicio < 0 ? 0 : inicio),
  ));
}

class _VisorFotos extends StatefulWidget {
  const _VisorFotos({required this.fotos, required this.inicio});
  final List<Message> fotos;
  final int inicio;

  @override
  State<_VisorFotos> createState() => _VisorFotosState();
}

class _VisorFotosState extends State<_VisorFotos> {
  late final PageController _page = PageController(initialPage: widget.inicio);
  late int _actual = widget.inicio;

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.fotos[_actual];
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(TimeFormat.dayLabel(m.time), style: const TextStyle(fontSize: 15)),
      ),
      body: PageView.builder(
        controller: _page,
        itemCount: widget.fotos.length,
        onPageChanged: (i) => setState(() => _actual = i),
        itemBuilder: (_, i) => InteractiveViewer(
          maxScale: 5,
          child: Center(
            child: Image.network(
              widget.fotos[i].urlArchivo!,
              errorBuilder: (_, __, ___) =>
                  const Icon(Icons.broken_image_outlined, color: Colors.white54, size: 64),
            ),
          ),
        ),
      ),
    );
  }
}
