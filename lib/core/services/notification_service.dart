import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Color;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ajustes_service.dart';
import 'api_service.dart';

/// Recibe los push "solo datos" del servidor (app cerrada, en segundo plano o abierta) y muestra
/// la notificación con acciones como WhatsApp: tocar abre el chat, "Responder" y "Marcar como leído".
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage m) async {
  await Firebase.initializeApp();
  debugPrint('🔔 Push en segundo plano: ${m.data} (notification=${m.notification != null})');
  if (m.notification != null) return; // iPhone: el sistema ya la muestra
  if (!await AjustesService.notificacionesActivas()) return; // apagadas en Ajustes
  try {
    await NotificationService.init();
    await NotificationService.mostrar(m.data);
  } catch (e) {
    debugPrint('❌ Push: no se pudo mostrar la notificación: $e');
  }
}

/// Acciones tocadas con la app en segundo plano o cerrada (corre en otro isolate)
@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse r) {
  NotificationService.procesar(r);
}

class NotificationService {
  NotificationService._();

  static final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  static const _canal = 'mensajes';
  static const _accionResponder = 'responder';
  static const _accionLeido = 'leido';
  static bool _listo = false;
  static const _iconoNotificacion = 'ic_stat_gijac'; // blanco sobre transparente en res/drawable
  static const _kPendientes = 'push_respuestas_pendientes';
  static const _kLeidos = 'push_leidos_pendientes';

  /// Lo asigna PushService: abre el chat cuando se toca la notificación con la app en marcha
  static void Function(String chatId, String? nombre)? onOpenChat;

  static Future<void> init() async {
    if (_listo) return;
    final ios = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
      notificationCategories: [
        DarwinNotificationCategory(
          'MENSAJE',
          actions: [
            DarwinNotificationAction.text('responder', 'Responder',
                buttonTitle: 'Enviar', placeholder: 'Escribe un mensaje'),
            DarwinNotificationAction.plain('leido', 'Marcar como leído'),
          ],
        ),
      ],
    );
    await _plugin.initialize(
      InitializationSettings(
        android: const AndroidInitializationSettings('@mipmap/launcher_icon'), // siempre válido; el ícono propio se aplica por notificación
        iOS: ios,
      ),
      onDidReceiveNotificationResponse: procesar,
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(const AndroidNotificationChannel(
          _canal,
          'Mensajes',
          description: 'Mensajes nuevos de tus clientes',
          importance: Importance.high,
        ));
    _listo = true;
  }

  /// Si la app fue abierta tocando una notificación local, devuelve ese chat
  static Future<Map<String, dynamic>?> chatDeLanzamiento() async {
    final d = await _plugin.getNotificationAppLaunchDetails();
    final p = d?.notificationResponse?.payload;
    if (d?.didNotificationLaunchApp == true && p != null && d?.notificationResponse?.actionId == null) {
      return Map<String, dynamic>.from(jsonDecode(p) as Map);
    }
    return null;
  }

  static int _idDe(String chatId) => chatId.hashCode & 0x7fffffff;

  static Future<void> mostrar(Map<String, dynamic> d, {bool silenciosa = false, String? textoPropio}) async {
    final titulo = d['titulo']?.toString() ?? 'Nuevo mensaje';
    final cuerpo = textoPropio ?? d['cuerpo']?.toString() ?? '';
    final chatId = d['chat_id']?.toString();
    final id = _idDe(chatId ?? titulo);

    AndroidNotificationDetails detalles(String icono) => AndroidNotificationDetails(
          _canal,
          'Mensajes',
          icon: icono,
          color: const Color(0xFF25D366),
          importance: Importance.high,
          priority: Priority.high,
          category: AndroidNotificationCategory.message,
          styleInformation: BigTextStyleInformation(cuerpo),
          onlyAlertOnce: silenciosa,
          actions: chatId == null
              ? null
              : const [
                  AndroidNotificationAction(
                    _accionResponder,
                    'Responder',
                    showsUserInterface: false,
                    cancelNotification: false,
                    allowGeneratedReplies: true,
                    inputs: [AndroidNotificationActionInput(label: 'Escribe un mensaje')],
                  ),
                  AndroidNotificationAction(_accionLeido, 'Marcar como leído',
                      showsUserInterface: false, cancelNotification: true),
                ],
        );

    Future<void> mostrarCon(String icono) => _plugin.show(
          id,
          titulo,
          cuerpo,
          NotificationDetails(
            android: detalles(icono),
            iOS: const DarwinNotificationDetails(categoryIdentifier: 'MENSAJE'),
          ),
          payload: jsonEncode({'chat_id': chatId, 'nombre': d['nombre'] ?? titulo}),
        );

    try {
      await mostrarCon(_iconoNotificacion);
    } catch (e) {
      // Si el ícono propio aún no está en el proyecto, se usa el de la app para no perder la notificación
      debugPrint('⚠️ Ícono de notificación no encontrado ($e), se usa el de la app');
      await mostrarCon('@mipmap/launcher_icon');
    }
  }

  // ───── Respuestas desde la notificación: se guardan antes de enviar y se reintentan si Android corta la red ─────
  static Future<void> _guardarPendiente(String id, String chatId, String texto) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final lista = prefs.getStringList(_kPendientes) ?? [];
    lista.add(jsonEncode({'id': id, 'chat': chatId, 'texto': texto, 'ts': DateTime.now().millisecondsSinceEpoch}));
    await prefs.setStringList(_kPendientes, lista);
  }

  static Future<void> _quitarPendiente(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final lista = (prefs.getStringList(_kPendientes) ?? []).where((e) => (jsonDecode(e) as Map)['id'] != id).toList();
    await prefs.setStringList(_kPendientes, lista);
  }

  // ───── "Marcar como leído" desde la notificación: se recuerda hasta que el servidor lo confirme ─────
  static Future<void> _cambiarLeido(String chatId, {required bool agregar}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final lista = (prefs.getStringList(_kLeidos) ?? []).where((c) => c != chatId).toList();
    if (agregar) lista.add(chatId);
    await prefs.setStringList(_kLeidos, lista);
  }

  /// Envía las respuestas que no alcanzaron a salir (se llama al abrir la app o reconectar)
  static Future<void> enviarPendientes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      for (final chat in List<String>.from(prefs.getStringList(_kLeidos) ?? [])) {
        if (await ApiService().markAsRead(chat)) {
          await _cambiarLeido(chat, agregar: false);
          debugPrint('✅ Leído pendiente enviado: $chat');
        }
      }
      final ahora = DateTime.now().millisecondsSinceEpoch;
      for (final raw in List<String>.from(prefs.getStringList(_kPendientes) ?? [])) {
        final p = Map<String, dynamic>.from(jsonDecode(raw) as Map);
        if (ahora - (p['ts'] as int) < 30000) continue; // puede que aún se esté enviando desde la notificación
        try {
          await ApiService().sendMessage(p['chat'].toString(), p['texto'].toString());
          await _quitarPendiente(p['id'].toString());
          debugPrint('✅ Respuesta pendiente enviada a ${p['chat']}');
        } catch (e) {
          debugPrint('⚠️ Respuesta pendiente no enviada: $e');
        }
      }
    } catch (e) {
      debugPrint('⚠️ No se pudieron revisar las respuestas pendientes: $e');
    }
  }

  static Future<void> procesar(NotificationResponse r) async {
    try {
      final p = r.payload == null ? <String, dynamic>{} : Map<String, dynamic>.from(jsonDecode(r.payload!) as Map);
      final chatId = p['chat_id']?.toString();
      if (chatId == null || chatId.isEmpty) return;

      switch (r.actionId) {
        case _accionLeido:
          await _plugin.cancel(_idDe(chatId));
          await _cambiarLeido(chatId, agregar: true); // Oppo suele cortar la red en segundo plano: se reintenta al abrir la app
          // Con la pantalla apagada Oppo tarda en devolver la red: se insiste ~20 s antes de dejarlo pendiente
          for (var i = 0; i < 6; i++) {
            if (await ApiService().markAsRead(chatId)) {
              await _cambiarLeido(chatId, agregar: false);
              break;
            }
            await Future.delayed(const Duration(seconds: 3));
          }
          break;
        case _accionResponder:
          final texto = r.input?.trim() ?? '';
          if (texto.isEmpty) return;
          await init();
          final idRespuesta = '${DateTime.now().microsecondsSinceEpoch}';
          await _guardarPendiente(idRespuesta, chatId, texto); // por si Android corta el proceso antes de terminar
          final datos = {'titulo': p['nombre'] ?? chatId, 'chat_id': chatId, 'nombre': p['nombre']};
          try {
            debugPrint('📤 Respuesta desde la notificación a $chatId');
            await ApiService().sendMessage(chatId, texto).timeout(const Duration(seconds: 25));
            await _quitarPendiente(idRespuesta);
            ApiService().markAsRead(chatId);
            await mostrar(datos, silenciosa: true, textoPropio: 'Tú: $texto');
          } catch (e) {
            debugPrint('⚠️ La respuesta quedó pendiente: $e');
            await mostrar(datos, silenciosa: true, textoPropio: 'Tú: $texto (se enviará al abrir la app)');
          }
          break;
        default:
          onOpenChat?.call(chatId, p['nombre']?.toString());
      }
    } catch (e) {
      debugPrint('⚠️ Notificación: error procesando acción: $e');
    }
  }
}