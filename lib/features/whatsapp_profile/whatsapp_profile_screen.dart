import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/models/whatsapp_business_profile.dart';
import '../../core/services/api_service.dart';
import '../../core/theme/app_colors.dart';
import '../../widgets/app_avatar.dart';
import '../../widgets/section_card.dart';
import '../../widgets/status_badge.dart';
import 'edit_whatsapp_profile_screen.dart';

/// Perfil de WhatsApp Business del número activo (datos reales). Editable solo en números de producción.
class WhatsappProfileScreen extends StatefulWidget {
  const WhatsappProfileScreen({super.key});

  @override
  State<WhatsappProfileScreen> createState() => _WhatsappProfileScreenState();
}

class _WhatsappProfileScreenState extends State<WhatsappProfileScreen> {
  static const _urlCatalogo = 'https://message-business.gijac.com/catalogo';

  WhatsappBusinessProfile? _perfil;
  String? _error;
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final p = await ApiService().getWhatsappProfile();
      if (mounted) setState(() => _perfil = p);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'No se pudo cargar el perfil.');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _editar() async {
    final p = _perfil;
    if (p == null) return;
    final nuevo = await Navigator.of(context).push<WhatsappBusinessProfile>(
      MaterialPageRoute(builder: (_) => EditWhatsappProfileScreen(perfil: p)),
    );
    if (nuevo != null && mounted) setState(() => _perfil = nuevo);
  }

  Future<void> _abrir(String url) async {
    final ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se pudo abrir el enlace.')));
    }
  }

  String _iniciales(String nombre) {
    final partes = nombre.split(' ').where((s) => s.isNotEmpty).take(2).toList();
    return partes.isEmpty ? 'WB' : partes.map((s) => s[0].toUpperCase()).join();
  }

  String _o(String v, String vacio) => v.trim().isEmpty ? vacio : v;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = _perfil;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Perfil de WhatsApp Business'),
        actions: [
          IconButton(tooltip: 'Actualizar', icon: const Icon(Icons.refresh), onPressed: _cargando ? null : _cargar),
          if (p != null && p.editable) TextButton(onPressed: _editar, child: const Text('Editar')),
        ],
      ),
      body: _cargando && p == null
          ? const Center(child: CircularProgressIndicator())
          : p == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error ?? 'No se pudo cargar el perfil.', textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        FilledButton(onPressed: _cargar, child: const Text('Reintentar')),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _cargar,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    children: [
                      Center(
                        child: Column(
                          children: [
                            AppAvatar(initials: _iniciales(p.nombre), radius: 48, colorValue: 0xFF128C7E, imageUrl: p.foto),
                            const SizedBox(height: 12),
                            Text(_o(p.nombre, 'Sin nombre'),
                                textAlign: TextAlign.center,
                                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                            const SizedBox(height: 4),
                            p.esPrueba
                                ? const StatusBadge(label: 'Número de prueba', color: Colors.orange, icon: Icons.science_outlined)
                                : const StatusBadge(label: 'Número de producción', color: AppColors.primary, icon: Icons.verified),
                          ],
                        ),
                      ),
                      if (p.esPrueba)
                        Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: Text(
                            'Meta no permite editar el perfil de los números de prueba. Solo se puede consultar.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                      const SizedBox(height: 24),
                      const SectionHeader(title: 'Información del negocio'),
                      GroupedCard(children: [
                        AppTile(icon: Icons.info_outline, title: _o(p.about, 'Sin información'), subtitle: 'Info'),
                        AppTile(icon: Icons.category_outlined, title: _o(p.categoriaNombre, 'Sin categoría'), subtitle: 'Categoría'),
                        AppTile(icon: Icons.description_outlined, title: _o(p.description, 'Sin descripción'), subtitle: 'Descripción'),
                      ]),
                      const SizedBox(height: 20),
                      const SectionHeader(title: 'Contacto'),
                      GroupedCard(children: [
                        AppTile(icon: Icons.phone, title: _o(p.telefono, 'Sin teléfono'), subtitle: 'Teléfono comercial'),
                        AppTile(icon: Icons.email_outlined, title: _o(p.email, 'Sin correo'), subtitle: 'Correo'),
                        if (p.websites.isEmpty)
                          const AppTile(icon: Icons.language, title: 'Sin sitio web', subtitle: 'Sitio web')
                        else
                          for (final w in p.websites) AppTile(icon: Icons.language, title: w, subtitle: 'Sitio web', onTap: () => _abrir(w)),
                        AppTile(icon: Icons.location_on_outlined, title: _o(p.address, 'Sin dirección'), subtitle: 'Dirección'),
                      ]),
                      const SizedBox(height: 20),
                      // TODO: Horario de atención (oculto por ahora)
                      const SectionHeader(title: 'Catálogo'),
                      GroupedCard(children: [
                        AppTile(
                          icon: Icons.storefront_outlined,
                          title: 'Catálogo',
                          subtitle: 'Gestiónalo desde la web',
                          trailing: const Icon(Icons.open_in_new, size: 18),
                          onTap: () => _abrir(_urlCatalogo),
                        ),
                      ]),
                    ],
                  ),
                ),
    );
  }
}