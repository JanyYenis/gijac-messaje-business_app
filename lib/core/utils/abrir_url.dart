import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../widgets/web_view_screen.dart';

/// Abre un enlace: las páginas web (http/https) dentro de la app y el resto
/// (mailto:, tel:, whatsapp:…) con la app del teléfono.
Future<void> abrirUrl(BuildContext context, String url, {String? titulo}) async {
  final uri = Uri.tryParse(url.trim());
  if (uri == null || uri.scheme.isEmpty) {
    _aviso(context);
    return;
  }

  if (uri.scheme == 'http' || uri.scheme == 'https') {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => WebViewScreen(url: uri.toString(), titulo: titulo)),
    );
    return;
  }

  var ok = false;
  try {
    ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {}
  if (!ok && context.mounted) _aviso(context);
}

void _aviso(BuildContext context) {
  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se pudo abrir el enlace.')));
}
