/// Avisos entre pantallas y la raíz de la app (sin dependencias circulares).
class SessionEvents {
  SessionEvents._();

  /// Lo asigna main.dart: arranca push (permiso de notificaciones) y Tiempo real al iniciar sesión.
  static Future<void> Function()? onLogin;
}
