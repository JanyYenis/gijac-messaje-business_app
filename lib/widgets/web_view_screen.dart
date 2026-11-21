import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

/// Páginas externas (web de GIJAC, políticas, etc.) dentro de la app.
class WebViewScreen extends StatefulWidget {
  const WebViewScreen({super.key, required this.url, this.titulo});

  final String url;
  final String? titulo;

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  late final WebViewController _controller;
  int _progreso = 0;
  bool _error = false;
  bool _puedeVolver = false;
  String? _titulo;

  @override
  void initState() {
    super.initState();
    _titulo = widget.titulo;

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (p) {
            if (mounted) setState(() => _progreso = p);
          },
          onPageStarted: (_) {
            if (mounted) setState(() => _error = false);
          },
          onPageFinished: (_) async {
            final volver = await _controller.canGoBack();
            final t = await _controller.getTitle();
            if (!mounted) return;
            setState(() {
              _puedeVolver = volver;
              if (widget.titulo == null && t != null && t.isNotEmpty) _titulo = t;
            });
          },
          onWebResourceError: (e) {
            // Solo se muestra el error si falla la página principal (no imágenes ni scripts sueltos)
            if (e.isForMainFrame ?? true) {
              if (mounted) setState(() => _error = true);
            }
          },
          onNavigationRequest: (req) {
            final uri = Uri.tryParse(req.url);
            // mailto:, tel:, whatsapp:, intent:… se abren con la app del teléfono
            if (uri != null && uri.scheme != 'http' && uri.scheme != 'https' && uri.scheme != 'about') {
              launchUrl(uri, mode: LaunchMode.externalApplication).catchError((_) => false);
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      );

    // Android: permitir que los formularios de la web suban archivos (<input type="file">)
    final plataforma = _controller.platform;
    if (plataforma is AndroidWebViewController) {
      plataforma.setOnShowFileSelector(_elegirArchivos);
    }

    _controller.loadRequest(Uri.parse(widget.url));
  }

  Future<List<String>> _elegirArchivos(FileSelectorParams params) async {
    try {
      final r = await FilePicker.platform.pickFiles(
        allowMultiple: params.mode == FileSelectorMode.openMultiple,
      );
      if (r == null) return [];
      return r.paths.whereType<String>().map((p) => File(p).uri.toString()).toList();
    } catch (_) {
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_puedeVolver,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop && _puedeVolver) await _controller.goBack();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.close),
            tooltip: 'Cerrar',
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Text(_titulo ?? 'GIJAC', overflow: TextOverflow.ellipsis),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Recargar',
              onPressed: () => _controller.reload(),
            ),
          ],
          bottom: _progreso < 100 && !_error
              ? PreferredSize(
                  preferredSize: const Size.fromHeight(3),
                  child: LinearProgressIndicator(value: _progreso / 100, minHeight: 3),
                )
              : null,
        ),
        body: _error
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.wifi_off, size: 48),
                      const SizedBox(height: 12),
                      const Text('No se pudo cargar la página. Revisa tu conexión.', textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: () {
                          setState(() => _error = false);
                          _controller.loadRequest(Uri.parse(widget.url));
                        },
                        child: const Text('Reintentar'),
                      ),
                    ],
                  ),
                ),
              )
            : SafeArea(top: false, child: WebViewWidget(controller: _controller)),
      ),
    );
  }
}