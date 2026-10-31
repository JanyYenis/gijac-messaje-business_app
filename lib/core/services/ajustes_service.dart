import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show ThemeMode;
import 'package:shared_preferences/shared_preferences.dart';

import 'api_service.dart';

/// Preferencias de la app guardadas en el teléfono: tema y notificaciones.
class AjustesService {
  AjustesService._();

  static const _kTema = 'ajuste_tema';
  static const kNotificaciones = 'notificaciones_activas';

  // ───── Tema ─────
  static Future<ThemeMode> temaGuardado() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return switch (prefs.getString(_kTema)) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };
    } catch (_) {
      return ThemeMode.system;
    }
  }

  static Future<void> guardarTema(ThemeMode modo) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kTema, modo.name);
    } catch (e) {
      debugPrint('⚠️ No se pudo guardar el tema: $e');
    }
  }

  // ───── Notificaciones ─────
  /// Por defecto activadas. `reload` porque el push en segundo plano corre en otro isolate.
  static Future<bool> notificacionesActivas() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      return prefs.getBool(kNotificaciones) ?? true;
    } catch (_) {
      return true;
    }
  }

  /// Activa o desactiva los avisos de mensajes nuevos en este dispositivo (Android y iPhone).
  /// - Desactivar: se borra el token FCM; el servidor lo descarta solo en el siguiente envío (token inválido).
  /// - Activar: se pide el permiso del sistema si falta y se registra un token nuevo.
  /// Devuelve false si no se pudo (p. ej. el permiso del sistema está bloqueado).
  static Future<bool> cambiarNotificaciones(bool activar) async {
    final prefs = await SharedPreferences.getInstance();
    final fm = FirebaseMessaging.instance;
    try {
      if (activar) {
        final permiso = await fm.requestPermission();
        final estado = permiso.authorizationStatus;
        if (estado != AuthorizationStatus.authorized && estado != AuthorizationStatus.provisional) {
          return false;
        }
        await prefs.setBool(kNotificaciones, true);
        final token = await fm.getToken();
        if (token != null) await ApiService().updateFcmToken(token);
        return true;
      }
      await prefs.setBool(kNotificaciones, false);
      await fm.deleteToken();
      return true;
    } catch (e) {
      debugPrint('⚠️ No se pudo cambiar el ajuste de notificaciones: $e');
      return false;
    }
  }
}
