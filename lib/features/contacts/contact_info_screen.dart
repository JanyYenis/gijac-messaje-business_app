import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/message.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/api_service.dart';
import '../../core/theme/app_colors.dart';
import '../../widgets/app_avatar.dart';
import '../../widgets/section_card.dart';
import '../chats/chat_search_screen.dart';
import 'media_gallery_screen.dart';

class ContactInfoScreen extends ConsumerStatefulWidget {
  const ContactInfoScreen({super.key, required this.chatId});
  final String chatId;

  @override
  ConsumerState<ContactInfoScreen> createState() => _ContactInfoScreenState();
}

class _ContactInfoScreenState extends ConsumerState<ContactInfoScreen> {
  final _api = ApiService();

  bool? _chatbot; // null = cargando
  bool? _ia;
  bool _guardando = false;
  List<Message> _media = [];
  bool _mediaCargando = true;

  @override
  void initState() {
    super.initState();
    _cargarDetalle();
    _cargarMedia();
  }

  Future<void> _cargarDetalle() async {
    try {
      final d = await _api.getContactoDetalle(widget.chatId);
      if (!mounted) return;
      setState(() {
        _chatbot = d['chatbot_activo'] == true;
        _ia = d['ia_activa'] == true;
      });
    } catch (e) {
      debugPrint('⚠️ Detalle del contacto: $e');
    }
  }

  Future<void> _cargarMedia() async {
    try {
      final r = await _api.getMultimedia(widget.chatId, tipo: 'media', limit: 12);
      if (mounted) setState(() => _media = r);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _mediaCargando = false);
    }
  }

  Future<void> _cambiar(String campo, bool valor) async {
    if (_guardando) return;
    final anterior = campo == 'ia' ? _ia : _chatbot;
    setState(() {
      _guardando = true;
      if (campo == 'ia') {
        _ia = valor;
      } else {
        _chatbot = valor;
      }
    });
    try {
      await _api.setAutomatizacion(widget.chatId, campo: campo, activo: valor);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        if (campo == 'ia') {
          _ia = anterior;
        } else {
          _chatbot = anterior;
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  void _buscar() => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ChatSearchScreen(chatId: widget.chatId)),
      );

  void _verMultimedia(String nombre) => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => MediaGalleryScreen(chatId: widget.chatId, titulo: nombre)),
      );

  @override
  Widget build(BuildContext context) {
    final chat = ref.watch(chatsProvider).firstWhere((c) => c.id == widget.chatId);
    final c = chat.contact;
    final theme = Theme.of(context);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 220,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                color: AppColors.secondary,
                padding: const EdgeInsets.only(top: 60, bottom: 16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AppAvatar(
                      initials: c.initials,
                      colorValue: c.avatarColorValue,
                      radius: 44,
                      isOnline: c.isOnline,
                    ),
                    const SizedBox(height: 12),
                    Text(c.name,
                        style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text(c.phone, style: TextStyle(color: Colors.white.withValues(alpha: 0.85))),
                  ],
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList.list(children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _accion(Icons.message, 'Mensaje', () => Navigator.of(context).pop()),
                  _accion(Icons.search, 'Buscar', _buscar),
                  _accion(Icons.perm_media_outlined, 'Multimedia', () => _verMultimedia(c.name)),
                ],
              ),
              const SizedBox(height: 20),
              const SectionHeader(title: 'Información'),
              GroupedCard(children: [
                AppTile(icon: Icons.phone_outlined, title: c.phone, subtitle: 'Teléfono'),
              ]),
              const SizedBox(height: 20),
              const SectionHeader(title: 'Respuestas automáticas'),
              GroupedCard(children: [
                AppTile(
                  icon: Icons.smart_toy_outlined,
                  iconColor: AppColors.aiAccent,
                  title: 'Respuestas con IA',
                  subtitle: 'El asistente responde a este contacto',
                  trailing: _interruptor(_ia, (v) => _cambiar('ia', v)),
                ),
                AppTile(
                  icon: Icons.account_tree_outlined,
                  iconColor: AppColors.aiAccent,
                  title: 'Chatbot de nodos',
                  subtitle: 'Flujo automático de respuestas',
                  trailing: _interruptor(_chatbot, (v) => _cambiar('chatbot', v)),
                ),
              ]),
              // TODO: "Agente asignado" y "Administrar etiquetas" (pendiente de conectar con el servidor)
              const SizedBox(height: 20),
              SectionHeader(title: 'Multimedia compartida', action: 'Ver todo', onAction: () => _verMultimedia(c.name)),
              _tira(theme, c.name),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _interruptor(bool? valor, ValueChanged<bool> alCambiar) {
    if (valor == null) {
      return const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2));
    }
    return Switch(value: valor, onChanged: _guardando ? null : alCambiar);
  }

  Widget _tira(ThemeData theme, String nombre) {
    if (_mediaCargando) {
      return const SizedBox(height: 80, child: Center(child: CircularProgressIndicator(strokeWidth: 2)));
    }
    if (_media.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text('Aún no hay fotos ni videos', style: theme.textTheme.bodySmall),
      );
    }
    return SizedBox(
      height: 90,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _media.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (_, i) => SizedBox(
          width: 90,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: MediaThumb(mensaje: _media[i], onTap: () => abrirMultimedia(context, _media, i)),
          ),
        ),
      ),
    );
  }

  Widget _accion(IconData icon, String label, VoidCallback onTap) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton.filledTonal(onPressed: onTap, icon: Icon(icon)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}