import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdfx/pdfx.dart';

import '../../../core/theme/app_colors.dart';

/// Previsualización de documentos: los PDF se ven dentro de la app (con zoom y páginas);
/// el resto de formatos (Word, Excel, PowerPoint, texto) se descargan y se abren con la app instalada.
class DocumentViewer extends StatefulWidget {
  const DocumentViewer({super.key, this.url, this.localPath, required this.fileName});
  final String? url;
  final String? localPath;
  final String fileName;

  @override
  State<DocumentViewer> createState() => _DocumentViewerState();
}

class _DocumentViewerState extends State<DocumentViewer> {
  String? _ruta;
  double? _progreso;
  String? _error;
  PdfController? _pdf;
  int _pagina = 1;
  int _paginas = 0;

  bool get _esPdf => widget.fileName.toLowerCase().endsWith('.pdf');

  @override
  void initState() {
    super.initState();
    _preparar();
  }

  @override
  void dispose() {
    _pdf?.dispose();
    super.dispose();
  }

  Future<void> _preparar() async {
    try {
      final local = widget.localPath;
      String ruta;
      if (local != null && File(local).existsSync()) {
        ruta = local;
      } else {
        ruta = await _descargar(widget.url!);
      }
      if (_esPdf) {
        _pdf = PdfController(document: PdfDocument.openFile(ruta));
      }
      if (mounted) setState(() => _ruta = ruta);
    } catch (e) {
      debugPrint('❌ Error preparando documento: $e');
      if (mounted) setState(() => _error = 'No se pudo cargar el documento.');
    }
  }

  /// Descarga a la carpeta temporal (queda en caché para abrirlo de nuevo sin red)
  Future<String> _descargar(String url) async {
    final dir = Directory('${(await getTemporaryDirectory()).path}/docs');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    final nombre = '${url.hashCode.abs()}_${widget.fileName.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_')}';
    final archivo = File('${dir.path}/$nombre');
    if (archivo.existsSync() && archivo.lengthSync() > 0) return archivo.path;

    final cliente = http.Client();
    try {
      final res = await cliente.send(http.Request('GET', Uri.parse(url)));
      if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');
      final total = res.contentLength ?? 0;
      var recibido = 0;
      final sink = archivo.openWrite();
      await for (final trozo in res.stream) {
        sink.add(trozo);
        recibido += trozo.length;
        if (total > 0 && mounted) setState(() => _progreso = recibido / total);
      }
      await sink.close();
      return archivo.path;
    } catch (e) {
      if (archivo.existsSync()) archivo.deleteSync();
      rethrow;
    } finally {
      cliente.close();
    }
  }

  Future<void> _abrirExterno() async {
    final r = _ruta;
    if (r == null) return;
    final res = await OpenFilex.open(r);
    if (res.type != ResultType.done && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay una app instalada para abrir este tipo de archivo.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.fileName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16)),
        actions: [
          if (_ruta != null)
            IconButton(onPressed: _abrirExterno, icon: const Icon(Icons.open_in_new), tooltip: 'Abrir con otra app'),
        ],
      ),
      body: _error != null
          ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!, textAlign: TextAlign.center)))
          : _ruta == null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(value: _progreso),
                      const SizedBox(height: 12),
                      Text(_progreso == null ? 'Descargando…' : '${(_progreso! * 100).toStringAsFixed(0)} %'),
                    ],
                  ),
                )
              : _esPdf && _pdf != null
                  ? Stack(
                      children: [
                        PdfView(
                          controller: _pdf!,
                          onDocumentLoaded: (doc) => setState(() => _paginas = doc.pagesCount),
                          onPageChanged: (p) => setState(() => _pagina = p),
                        ),
                        if (_paginas > 0)
                          Positioned(
                            bottom: 16,
                            right: 16,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(16)),
                              child: Text('$_pagina / $_paginas', style: const TextStyle(color: Colors.white)),
                            ),
                          ),
                      ],
                    )
                  : Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.insert_drive_file, size: 72, color: AppColors.secondary),
                          const SizedBox(height: 12),
                          Text(widget.fileName, textAlign: TextAlign.center),
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            onPressed: _abrirExterno,
                            icon: const Icon(Icons.open_in_new),
                            label: const Text('Abrir'),
                          ),
                        ],
                      ),
                    ),
    );
  }
}
