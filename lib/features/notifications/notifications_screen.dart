import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/models/app_notification.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/cache_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/time_format.dart';
import '../../widgets/brand_logo.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(notificationsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notificaciones'),
        actions: [
          TextButton(
            onPressed: () =>
                ref.read(notificationsProvider.notifier).markAllRead(),
            child: const Text('Marcar leídas'),
          ),
        ],
      ),
      body: items.isEmpty
          ? RefreshIndicator(
              onRefresh: () => ref.read(notificationsProvider.notifier).load(),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 120),
                  EmptyState(
                    icon: Icons.notifications_off_outlined,
                    title: 'Sin notificaciones',
                    message: 'Aquí verás tus alertas, igual que en la web.',
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: () => ref.read(notificationsProvider.notifier).load(),
              child: ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: items.length,
                separatorBuilder: (_, __) =>
                    const Divider(height: 1, indent: 72),
                itemBuilder: (_, i) => _NotificationTile(item: items[i]),
              ),
            ),
    );
  }
}

class _NotificationTile extends ConsumerWidget {
  const _NotificationTile({required this.item});
  final AppNotification item;

  Future<void> _abrir(BuildContext context, WidgetRef ref) async {
    if (!item.isRead) ref.read(notificationsProvider.notifier).markRead(item.id);
    final ruta = item.ruta;
    if (ruta == null) return;
    final server = await CacheService().getServerUrl();
    final url = ruta.startsWith('http') ? ruta : '${server ?? ''}${ruta.startsWith('/') ? '' : '/'}$ruta';
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final (icon, color) = switch (item.type) {
      NotificationType.message => (Icons.chat_bubble, AppColors.primary),
      NotificationType.automation => (Icons.account_tree, AppColors.n8nAccent),
      NotificationType.ai => (Icons.auto_awesome, AppColors.aiAccent),
      NotificationType.alert => (Icons.warning_amber, AppColors.warning),
      NotificationType.system => (Icons.settings, AppColors.blue),
    };

    return Container(
      color: item.isRead
          ? null
          : AppColors.primary.withValues(alpha: 0.06),
      child: ListTile(
        onTap: () => _abrir(context, ref),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        title: Text(item.title,
            style: TextStyle(
                fontWeight:
                    item.isRead ? FontWeight.w600 : FontWeight.w800)),
        subtitle: Text(item.body,
            maxLines: 2, overflow: TextOverflow.ellipsis),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(TimeFormat.relative(item.time),
                style: theme.textTheme.bodySmall),
            if (!item.isRead)
              Container(
                margin: const EdgeInsets.only(top: 6),
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }
}