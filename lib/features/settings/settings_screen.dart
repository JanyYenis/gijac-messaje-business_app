import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/providers/app_providers.dart';
import '../../core/providers/user_provider.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/services/cache_service.dart';
import '../../widgets/app_avatar.dart';
import '../../widgets/section_card.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  static const _webChatbots = 'https://message-business.gijac.com/chatbots';

  Future<void> _abrirWeb(BuildContext context, String url) async {
    var ok = false;
    try {
      ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {}
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se pudo abrir la página.')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final notificaciones = ref.watch(notificacionesActivasProvider);
    final notificacionesOn = notificaciones.valueOrNull ?? true;
    final userState = ref.watch(userProvider);
    final user = userState.user;

    // Calcular iniciales dinámicamente
    String initials = 'U';
    if (user != null) {
      final parts = user.nombreCompleto.split(' ').where((s) => s.isNotEmpty).take(2).toList();
      initials = parts.map((s) => s[0].toUpperCase()).join();
    }

    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Material(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => context.push(Routes.userProfile),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: theme.colorScheme.outline),
                ),
                child: Row(
                  children: [
                    AppAvatar(
                      initials: initials,             // <-- CAMBIADO (antes 'JA')
                      imageUrl: user?.foto,
                      radius: 28,
                      colorValue: 0xFF3B82F6,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user?.nombreCompleto ?? 'Cargando...', // <-- CAMBIADO (antes 'Juan Agente')
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            'Ver y editar perfil',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          const SectionHeader(title: 'Cuenta'),
          GroupedCard(
            children: [
              AppTile(
                icon: Icons.business_center,
                iconColor: AppColors.secondary,
                title: 'Perfil de WhatsApp Business',
                subtitle: 'Información del negocio',
                onTap: () => context.push(Routes.whatsappProfile),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const SectionHeader(title: 'Preferencias'),
          GroupedCard(
            children: [
              AppTile(
                icon: Icons.dark_mode_outlined,
                title: 'Tema',
                subtitle: switch (themeMode) {
                  ThemeMode.light => 'Claro',
                  ThemeMode.dark => 'Oscuro',
                  ThemeMode.system => 'Sistema',
                },
                trailing: SegmentedButton<ThemeMode>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(
                      value: ThemeMode.light,
                      icon: Icon(Icons.light_mode),
                    ),
                    ButtonSegment(
                      value: ThemeMode.system,
                      icon: Icon(Icons.brightness_auto),
                    ),
                    ButtonSegment(
                      value: ThemeMode.dark,
                      icon: Icon(Icons.dark_mode),
                    ),
                  ],
                  selected: {themeMode},
                  onSelectionChanged: (s) =>
                      ref.read(themeModeProvider.notifier).set(s.first),
                ),
              ),
              AppTile(
                icon: Icons.notifications_outlined,
                title: 'Notificaciones',
                subtitle: notificacionesOn ? 'Activadas' : 'Desactivadas',
                trailing: Switch(
                  value: notificacionesOn,
                  onChanged: notificaciones.isLoading
                      ? null
                      : (v) async {
                          final ok = await ref.read(notificacionesActivasProvider.notifier).cambiar(v);
                          if (!ok && context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text(Platform.isIOS
                                  ? 'Permiso bloqueado. Actívalo en Ajustes del iPhone → Notificaciones → GIJAC.'
                                  : 'Permiso bloqueado. Actívalo en Ajustes del teléfono → Aplicaciones → GIJAC → Notificaciones.'),
                            ));
                          }
                        },
                ),
              ),
              AppTile(
                icon: Icons.language,
                title: 'Idioma',
                subtitle: 'Español',
                onTap: () {},
              ),
            ],
          ),
          const SizedBox(height: 20),
          const SectionHeader(title: 'Automatización e IA'),
          GroupedCard(
            children: [
              AppTile(
                icon: Icons.settings_suggest_outlined,
                iconColor: AppColors.aiAccent,
                title: 'Configuración de chatbots',
                subtitle: 'Se administra en la web',
                trailing: const Icon(Icons.open_in_new, size: 18),
                onTap: () => _abrirWeb(context, '$_webChatbots/configuracion'),
              ),
              AppTile(
                icon: Icons.smart_toy_outlined,
                iconColor: AppColors.aiAccent,
                title: 'Chatbot (nodos)',
                subtitle: 'Flujos de conversación',
                trailing: const Icon(Icons.open_in_new, size: 18),
                onTap: () => _abrirWeb(context, '$_webChatbots/nodos'),
              ),
              AppTile(
                icon: Icons.auto_awesome,
                iconColor: AppColors.aiAccent,
                title: 'Asistente con IA',
                subtitle: 'Respuestas con inteligencia artificial',
                trailing: const Icon(Icons.open_in_new, size: 18),
                onTap: () => _abrirWeb(context, '$_webChatbots/asistente'),
              ),
              AppTile(
                icon: Icons.account_tree_outlined,
                iconColor: AppColors.n8nAccent,
                title: 'Integraciones n8n',
                subtitle: 'Workflows y automatizaciones',
                trailing: const Icon(Icons.open_in_new, size: 18),
                onTap: () => _abrirWeb(context, '$_webChatbots/n8n'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const SectionHeader(title: 'Seguridad'),
          GroupedCard(
            children: [
              AppTile(
                icon: Icons.lock_outline,
                title: 'Seguridad',
                onTap: () => context.push(Routes.security),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const SectionHeader(title: 'Soporte'),
          GroupedCard(
            children: [
              AppTile(
                icon: Icons.help_outline,
                title: 'Centro de ayuda y soporte',
                onTap: () => context.push(Routes.support),
              ),
              AppTile(
                icon: Icons.info_outline,
                title: 'Acerca de',
                subtitle: 'Versión 1.0.0',
                onTap: () {},
              ),
            ],
          ),
          const SizedBox(height: 20),
          GroupedCard(
            children: [
              AppTile(
                icon: Icons.logout,
                iconColor: AppColors.danger,
                title: 'Cerrar sesión',
                onTap: () async {
                  final cache = CacheService();
                  await cache.clearDeviceData();
                  await cache.clearProfile();

                  if (context.mounted) {
                    appRouter.go(Routes.qrLogin);
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}