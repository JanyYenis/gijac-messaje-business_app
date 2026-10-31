import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Bloqueo biométrico de la app (huella, rostro o el PIN/patrón del teléfono como respaldo).
class BiometriaService {
  BiometriaService._();

  static const _kActivo = 'bloqueo_biometrico';
  static final _auth = LocalAuthentication();

  /// El teléfono tiene huella/rostro o bloqueo de pantalla configurado
  static Future<bool> disponible() async {
    try {
      return await _auth.isDeviceSupported();
    } catch (_) {
      return false;
    }
  }

  static Future<bool> activo() async {
    try {
      final p = await SharedPreferences.getInstance();
      return p.getBool(_kActivo) ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Pide la verificación del sistema. true si el usuario se identificó.
  static Future<bool> autenticar(String motivo) async {
    try {
      return await _auth.authenticate(
        localizedReason: motivo,
        options: const AuthenticationOptions(stickyAuth: true),
      );
    } catch (e) {
      debugPrint('⚠️ Biometría: $e');
      return false;
    }
  }

  /// Activar exige verificar primero (así se comprueba que funciona y que es el dueño). Devuelve el estado final.
  static Future<bool> cambiar(bool activar) async {
    if (activar) {
      if (!await disponible()) return false;
      if (!await autenticar('Confirma tu identidad para activar el bloqueo')) return false;
    } else {
      if (!await autenticar('Confirma tu identidad para desactivar el bloqueo')) return true;
    }
    try {
      final p = await SharedPreferences.getInstance();
      await p.setBool(_kActivo, activar);
    } catch (_) {
      return !activar;
    }
    return activar;
  }
}
