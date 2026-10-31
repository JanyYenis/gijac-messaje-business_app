import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/app_providers.dart';
import '../../core/providers/user_provider.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/responsive.dart';
import '../../core/utils/time_format.dart';
import '../../widgets/app_avatar.dart';
import '../../widgets/section_card.dart';
import '../../widgets/stat_card.dart';

class HomeDashboardScreen extends ConsumerWidget {
  const HomeDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Obtener el estado del usuario (ya debería estar en 'success')
    final userState = ref.watch(userProvider);

    // Cargar datos si es la primera vez
    if (userState.status == ProfileStatus.initial) {
      Future.microtask(() => ref.read(userProvider.notifier).loadProfile());
    }

    final user = userState.user;
    // Calcular iniciales de forma segura (siempre tendrá un valor por defecto)
    String initials = 'GJ';
    if (user != null) {
      // Si tiene empresa, usa las iniciales de la empresa, si no, del usuario
      final source = user.empresa?.nombre ?? user.nombreCompleto;
      final parts = source.split(' ').where((s) => s.isNotEmpty).take(2).toList();
      if (parts.isNotEmpty) {
        initials = parts.map((s) => s[0].toUpperCase()).join();
      }
    }

    final theme = Theme.of(context);
    final chats = ref.watch(chatsProvider);
    final unread = ref.watch(unreadNotificationsProvider);
    final resumen = ref.watch(resumenProvider);
    final crossAxisCount = Responsive.value(context,
        mobile: 2, tablet: 3, desktop: 4);

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(resumenProvider);
            await Future.wait([
              ref.read(chatsProvider.notifier).loadChats(),
              ref.read(userProvider.notifier).refreshProfile(),
            ]);
          },
          child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                Responsive.horizontalPadding(context),
                16,
                Responsive.horizontalPadding(context),
                100,
              ),
              sliver: SliverList.list(children: [
                _header(context, theme, unread, initials, user),
                const SizedBox(height: 20),
                resumen.when(
                  data: (r) => GridView.count(
                    crossAxisCount: crossAxisCount,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.15,
                    children: [
                      StatCard(
                        icon: Icons.forum_rounded,
                        value: '${r['conversaciones_activas'] ?? 0}',
                        label: 'Conversaciones activas (24 h)',
                        color: AppColors.primary,
                      ),
                      StatCard(
                        icon: Icons.mark_chat_unread_rounded,
                        value: '${r['mensajes_sin_leer'] ?? 0}',
                        label: 'Mensajes sin leer (${r['chats_sin_leer'] ?? 0} chats)',
                        color: AppColors.warning,
                      ),
                      StatCard(
                        icon: Icons.call_received_rounded,
                        value: '${r['recibidos_hoy'] ?? 0}',
                        label: 'Mensajes recibidos hoy',
                        color: AppColors.blue,
                      ),
                      StatCard(
                        icon: Icons.call_made_rounded,
                        value: '${r['enviados_hoy'] ?? 0}',
                        label: 'Mensajes enviados hoy',
                        color: AppColors.secondary,
                      ),
                    ],
                  ),
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (_, __) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Column(
                      children: [
                        const Text('No se pudo cargar el resumen.'),
                        TextButton(
                          onPressed: () => ref.invalidate(resumenProvider),
                          child: const Text('Reintentar'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const SectionHeader(title: 'Actividad reciente'),
                ...chats.take(4).map((c) => _recentTile(context, theme, c)),
              ]),
            ),
          ],
        ),
        ),
      ),
    );
  }

  String _saludo() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Buenos días,';
    if (h < 19) return 'Buenas tardes,';
    return 'Buenas noches,';
  }

  Widget _header(BuildContext context, ThemeData theme, int unread, String? initials, user) {
    return Row(
      children: [
        AppAvatar(
          initials: initials ?? 'GJ',
          radius: 24,
          colorValue: 0xFF128C7E,
          imageUrl: user?.empresa?.logo, // logo de la empresa; si no hay o no carga, iniciales
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_saludo(),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  )),
              Text(user?.empresa?.nombre ?? user?.nombreCompleto ?? 'Cargando...',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800)),
            ],
          ),
        ),
        IconButton.filledTonal(
          onPressed: () => context.go(Routes.notifications),
          icon: Badge(
            isLabelVisible: unread > 0,
            label: Text('$unread'),
            child: const Icon(Icons.notifications_outlined),
          ),
        ),
      ],
    );
  }

  Widget _recentTile(BuildContext context, ThemeData theme, chat) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => context.push('/chats/${chat.id}'),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: theme.colorScheme.outline),
            ),
            child: Row(
              children: [
                AppAvatar(
                  initials: chat.contact.initials,
                  colorValue: chat.contact.avatarColorValue,
                  isOnline: chat.contact.isOnline,
                  radius: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(chat.contact.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      Text(chat.lastMessage,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(TimeFormat.relative(chat.lastTime),
                    style: theme.textTheme.bodySmall),
              ],
            ),
          ),
        ),
      ),
    );
  }
}