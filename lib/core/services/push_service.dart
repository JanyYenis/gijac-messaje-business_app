import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'ajustes_service.dart';
import 'api_service.dart';
import 'energia_service.dart';
import 'notification_service.dart';

/// Notificaciones push: registro del token, aviso en primer plano y apertura del chat al tocarlas.
class PushService {
  PushService._();
  static final PushService instance = PushService._();

  bool _iniciado = false;
  StreamSubscription? _subRefresh;
  StreamSubscription? _subOpen;
  StreamSubscription? _subForeground;

  Future<void> init({
    required void Function(String chatId, String? nombre) onOpenChat,
    required bool Function(String chatId) isViewingChat,
    required void Function(String titulo, String cuerpo, String chatId, String? nombre) onForeground,
  }) async {
    if (_iniciado) return;
    _iniciado = true;

    final fm = FirebaseMessaging.instance;
    NotificationService.onOpenChat = onOpenChat;
    try {
      await NotificationService.init();
    } catch (e) {
      debugPrint('❌ Push: no se pudo iniciar las notificaciones locales: $e');
    }
    // iPhone: con la app abierta no se muestra el banner del sistema (se avisa dentro de la app)
    await fm.setForegroundNotificationPresentationOptions(alert: false, badge: false, sound: false);
    // Si el usuario las apagó en Ajustes, no se pide permiso ni se registra token
    final activas = await AjustesService.notificacionesActivas();
    if (activas) {
      try {
        final permiso = await fm.requestPermission(); // Android 13+: pide el permiso de notificaciones
        debugPrint('🔔 Push: permiso = ${permiso.authorizationStatus}');
        final token = await fm.getToken();
        debugPrint('🔔 Push: token FCM termina en …${token == null ? 'NULL' : token.substring(token.length - 12)}');
        if (token != null) await ApiService().updateFcmToken(token);
      } catch (e) {
        debugPrint('⚠️ Push: no se pudo registrar el token: $e');
      }

      // Android: una sola vez, pide funcionar sin restricciones de batería (la app ya está en pantalla)
      Future.delayed(const Duration(seconds: 3), EnergiaService.avisarUnaVez);
    } else {
      debugPrint('🔕 Push: desactivadas en Ajustes');
    }

    _subRefresh = fm.onTokenRefresh.listen((t) async {
      if (await AjustesService.notificacionesActivas()) ApiService().updateFcmToken(t);
    });

    // App abierta: no hay notificación del sistema, se avisa dentro de la app (salvo que ya esté en ese chat)
    _subForeground = FirebaseMessaging.onMessage.listen((m) {
      debugPrint('🔔 Push recibido con la app abierta: ${m.data}');
      final chatId = m.data['chat_id']?.toString();
      if (chatId == null || chatId.isEmpty || isViewingChat(chatId)) return;
      onForeground(
        m.data['titulo']?.toString() ?? m.notification?.title ?? 'Nuevo mensaje',
        m.data['cuerpo']?.toString() ?? m.notification?.body ?? '',
        chatId,
        m.data['nombre']?.toString(),
      );
    });

    // App en segundo plano: al tocar la notificación abre el chat
    _subOpen = FirebaseMessaging.onMessageOpenedApp.listen(_abrir(onOpenChat));

    // App cerrada y abierta tocando la notificación local (Android)
    final lanzada = await NotificationService.chatDeLanzamiento();
    if (lanzada != null) {
      Future.delayed(const Duration(milliseconds: 900),
          () => onOpenChat(lanzada['chat_id'].toString(), lanzada['nombre']?.toString()));
    }

    // App cerrada: la notificación (iPhone) que la abrió
    final inicial = await fm.getInitialMessage();
    if (inicial != null) {
      Future.delayed(const Duration(milliseconds: 900), () => _abrir(onOpenChat)(inicial));
    }
  }

  void Function(RemoteMessage) _abrir(void Function(String, String?) onOpenChat) {
    return (m) {
      final id = m.data['chat_id']?.toString();
      if (id == null || id.isEmpty) return;
      onOpenChat(id, m.data['nombre']?.toString());
    };
  }

  Future<void> dispose() async {
    await _subRefresh?.cancel();
    await _subOpen?.cancel();
    await _subForeground?.cancel();
    _iniciado = false;
  }
}