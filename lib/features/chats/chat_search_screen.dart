import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/models/message.dart';
import '../../core/services/api_service.dart';
import '../../core/utils/time_format.dart';

/// Buscar texto dentro de la conversación (en todo el historial, no solo lo cargado).
class ChatSearchScreen extends StatefulWidget {
  const ChatSearchScreen({super.key, required this.chatId});
  final String chatId;

  @override
  State<ChatSearchScreen> createState() => _ChatSearchScreenState();
}

class _ChatSearchScreenState extends State<ChatSearchScreen> {
  final _api = ApiService();
  final _controller = TextEditingController();
  Timer? _debounce;
  List<Message> _resultados = [];
  bool _buscando = false;
  String _consulta = '';
  String? _error;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _cambio(String texto) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), () => _buscar(texto.trim()));
  }

  Future<void> _buscar(String texto) async {
    if (texto.length < 2) {
      setState(() {
        _resultados = [];
        _consulta = '';
        _error = null;
      });
      return;
    }
    setState(() {
      _buscando = true;
      _error = null;
    });
    try {
      final r = await _api.buscarMensajes(widget.chatId, texto);
      if (!mounted || _controller.text.trim() != texto) return;
      setState(() {
        _resultados = r;
        _consulta = texto;
        _buscando = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _buscando = false;
          _error = 'No se pudo buscar. Revisa tu conexión.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: true,
          onChanged: _cambio,
          textInputAction: TextInputAction.search,
          onSubmitted: (t) => _buscar(t.trim()),
          decoration: const InputDecoration(
            hintText: 'Buscar en esta conversación',
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            filled: false,
          ),
        ),
        actions: [
          if (_controller.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                _controller.clear();
                _buscar('');
              },
            ),
        ],
        bottom: _buscando
            ? const PreferredSize(preferredSize: Size.fromHeight(3), child: LinearProgressIndicator(minHeight: 3))
            : null,
      ),
      body: _error != null
          ? Center(child: Text(_error!))
          : _consulta.isEmpty
              ? const Center(child: Text('Escribe al menos 2 letras'))
              : _resultados.isEmpty && !_buscando
                  ? Center(child: Text('Sin resultados para "$_consulta"'))
                  : ListView.separated(
                      itemCount: _resultados.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final m = _resultados[i];
                        return ListTile(
                          title: _resaltado(m.text ?? '', _consulta, theme),
                          subtitle: Text(
                            '${m.isOutgoing ? 'Tú' : 'Cliente'} · ${TimeFormat.dayLabel(m.time)} ${TimeFormat.clock(m.time)}',
                          ),
                        );
                      },
                    ),
    );
  }

  /// Texto con la coincidencia resaltada
  Widget _resaltado(String texto, String q, ThemeData theme) {
    final i = texto.toLowerCase().indexOf(q.toLowerCase());
    if (i < 0) return Text(texto, maxLines: 3, overflow: TextOverflow.ellipsis);
    return Text.rich(
      TextSpan(children: [
        TextSpan(text: texto.substring(0, i)),
        TextSpan(
          text: texto.substring(i, i + q.length),
          style: TextStyle(fontWeight: FontWeight.w800, color: theme.colorScheme.primary),
        ),
        TextSpan(text: texto.substring(i + q.length)),
      ]),
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
    );
  }
}
