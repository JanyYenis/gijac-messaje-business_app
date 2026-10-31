import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/device_validation_screen.dart';
import '../../features/auth/qr_login_screen.dart';
import '../../features/auth/qr_scanner_screen.dart';
import '../../features/auth/splash_screen.dart';
import '../../features/chats/chats_list_screen.dart';
import '../../features/chats/conversation_screen.dart';
import '../../features/contacts/contact_info_screen.dart';
import '../../features/dashboard/home_dashboard_screen.dart';
import '../../features/dashboard/main_shell.dart';
import '../../features/notifications/notifications_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/support/support_screen.dart';
import '../../features/user_profile/user_profile_screen.dart';
import '../../features/whatsapp_profile/whatsapp_profile_screen.dart';
import '../../features/security/security_screen.dart';
import '../../features/privacy/privacy_screen.dart';

/// Route name constants.
class Routes {
  Routes._();
  static const splash = '/';
  static const qrLogin = '/login';
  static const qrScanner = '/login/scanner';
  static const deviceValidation = '/login/validation';

  static const dashboard = '/dashboard';
  static const chats = '/chats';
  static const conversation = '/chats/:id';
  static const contactInfo = '/chats/:id/contact';
  static const notifications = '/notifications';
  static const settings = '/settings';

  static const whatsappProfile = '/settings/whatsapp';
  static const userProfile = '/settings/profile';
  static const security = '/settings/security';
  static const privacy = '/settings/privacy';
  static const support = '/settings/support';
}

final _rootKey = GlobalKey<NavigatorState>();
final _shellKey = GlobalKey<NavigatorState>();

final appRouter = GoRouter(
  navigatorKey: _rootKey,
  initialLocation: Routes.splash,
  routes: [
    GoRoute(
      path: Routes.splash,
      builder: (_, __) => const SplashScreen(),
    ),
    GoRoute(
      path: Routes.qrLogin,
      builder: (_, __) => const QrLoginScreen(),
    ),
    GoRoute(
      path: Routes.qrScanner,
      builder: (_, __) => const QrScannerScreen(),
    ),
    GoRoute(
      path: Routes.deviceValidation,
      builder: (_, __) => const DeviceValidationScreen(),
    ),

    // Main app with persistent bottom navigation.
    ShellRoute(
      navigatorKey: _shellKey,
      builder: (_, __, child) => MainShell(child: child),
      routes: [
        GoRoute(
          path: Routes.dashboard,
          pageBuilder: (_, s) =>
              const NoTransitionPage(child: HomeDashboardScreen()),
        ),
        GoRoute(
          path: Routes.chats,
          pageBuilder: (_, s) =>
              const NoTransitionPage(child: ChatsListScreen()),
        ),
        GoRoute(
          path: Routes.notifications,
          pageBuilder: (_, s) =>
              const NoTransitionPage(child: NotificationsScreen()),
        ),
        GoRoute(
          path: Routes.settings,
          pageBuilder: (_, s) =>
              const NoTransitionPage(child: SettingsScreen()),
        ),
      ],
    ),

    // Full-screen routes pushed above the shell.
    GoRoute(
      parentNavigatorKey: _rootKey,
      path: Routes.conversation,
      // MODIFICADO: Extraemos el nombre del extra y lo pasamos a la pantalla
      builder: (_, state) {
        final extra = state.extra as Map<String, dynamic>?;
        return ConversationScreen(
          chatId: state.pathParameters['id']!,
          nombre: extra?['nombre'],
        );
      },
    ),
    GoRoute(
      parentNavigatorKey: _rootKey,
      path: Routes.contactInfo,
      builder: (_, state) =>
          ContactInfoScreen(chatId: state.pathParameters['id']!),
    ),
    GoRoute(
      parentNavigatorKey: _rootKey,
      path: Routes.whatsappProfile,
      builder: (_, __) => const WhatsappProfileScreen(),
    ),
    GoRoute(
      parentNavigatorKey: _rootKey,
      path: Routes.userProfile,
      builder: (_, __) => const UserProfileScreen(),
    ),
    GoRoute(
      parentNavigatorKey: _rootKey,
      path: Routes.security,
      builder: (_, __) => const SecurityScreen(),
    ),
    GoRoute(
      parentNavigatorKey: _rootKey,
      path: Routes.privacy,
      builder: (_, __) => const PrivacyScreen(),
    ),
    GoRoute(
      parentNavigatorKey: _rootKey,
      path: Routes.support,
      builder: (_, __) => const SupportScreen(),
    ),
  ],
);