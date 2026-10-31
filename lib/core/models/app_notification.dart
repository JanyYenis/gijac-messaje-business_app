enum NotificationType { message, automation, ai, system, alert }

class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.time,
    required this.type,
    this.isRead = false,
    this.color,
    this.ruta,
  });

  final String id;
  final String title;
  final String body;
  final DateTime time;
  final NotificationType type;
  final bool isRead;

  /// Color de la web (primary, danger, warning, success, info…)
  final String? color;

  /// Enlace de la web al que lleva la notificación (puede ser relativo)
  final String? ruta;

  AppNotification copyWith({bool? isRead}) => AppNotification(
        id: id,
        title: title,
        body: body,
        time: time,
        type: type,
        isRead: isRead ?? this.isRead,
        color: color,
        ruta: ruta,
      );

  /// Las notificaciones de Laravel guardan titulo, mensaje, icono (clase FontAwesome), color y ruta
  factory AppNotification.fromJson(Map<String, dynamic> j) {
    final icono = (j['icono'] ?? '').toString();
    final color = (j['color'] ?? 'primary').toString();
    final NotificationType tipo;
    if (icono.contains('comment') || icono.contains('whatsapp') || icono.contains('envelope')) {
      tipo = NotificationType.message;
    } else if (icono.contains('robot')) {
      tipo = NotificationType.ai;
    } else if (icono.contains('sitemap') || icono.contains('project-diagram')) {
      tipo = NotificationType.automation;
    } else if (color == 'danger' || color == 'warning') {
      tipo = NotificationType.alert;
    } else {
      tipo = NotificationType.system;
    }
    return AppNotification(
      id: j['id'].toString(),
      title: (j['titulo'] ?? 'Notificación').toString(),
      body: (j['mensaje'] ?? '').toString(),
      time: DateTime.tryParse((j['fecha'] ?? '').toString())?.toLocal() ?? DateTime.now(),
      type: tipo,
      isRead: j['leida'] == true,
      color: color,
      ruta: (j['ruta'] == null || j['ruta'].toString().isEmpty || j['ruta'].toString() == '#') ? null : j['ruta'].toString(),
    );
  }
}