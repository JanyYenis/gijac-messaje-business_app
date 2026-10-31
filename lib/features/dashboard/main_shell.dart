import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/app_providers.dart';
import '../../core/router/app_router.dart';
import '../../core/utils/responsive.dart';

/// Scaffolds the persistent navigation (bottom bar on phones, rail on tablets).
class MainShell extends ConsumerWidget {
  const MainShell({super.key, required this.child});

  final Widget child;

  static const _destinations = [
    (Routes.dashboard, Icons.dashboard_outlined, Icons.dashboard, 'Inicio'),
    (Routes.chats, Icons.chat_bubble_outline, Icons.chat_bubble, 'Chats'),
    (
      Routes.notifications,
      Icons.notifications_outlined,
      Icons.notifications,
      'Alertas'
    ),
    (Routes.settings, Icons.settings_outlined, Icons.settings, 'Ajustes'),
  ];

  int _indexFor(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    final i = _destinations.indexWhere((d) => location.startsWith(d.$1));
    return i < 0 ? 0 : i;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = _indexFor(context);
    final unread = ref.watch(unreadNotificationsProvider);
    final useRail = !Responsive.isMobile(context);

    void onTap(int i) => context.go(_destinations[i].$1);

    if (useRail) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: index,
              onDestinationSelected: onTap,
              labelType: NavigationRailLabelType.all,
              destinations: [
                for (final d in _destinations)
                  NavigationRailDestination(
                    icon: _withBadge(
                        Icon(d.$2), d.$1 == Routes.notifications ? unread : 0),
                    selectedIcon: _withBadge(Icon(d.$3),
                        d.$1 == Routes.notifications ? unread : 0),
                    label: Text(d.$4),
                  ),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(child: child),
          ],
        ),
      );
    }

    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: onTap,
        destinations: [
          for (final d in _destinations)
            NavigationDestination(
              icon: _withBadge(
                  Icon(d.$2), d.$1 == Routes.notifications ? unread : 0),
              selectedIcon: _withBadge(
                  Icon(d.$3), d.$1 == Routes.notifications ? unread : 0),
              label: d.$4,
            ),
        ],
      ),
    );
  }

  Widget _withBadge(Widget icon, int count) {
    if (count <= 0) return icon;
    return Badge(label: Text('$count'), child: icon);
  }
}
