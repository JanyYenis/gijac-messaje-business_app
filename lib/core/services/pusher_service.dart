import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:dart_pusher_channels/dart_pusher_channels.dart';

class PusherService {
  static final PusherService _instance = PusherService._internal();
  factory PusherService() => _instance;
  PusherService._internal();

  PusherChannelsClient? _client;
  PresenceChannel? _channel;
  final List<StreamSubscription> _subs = [];

  // Alertas en tiempo real (canal notificacion.{id}, el mismo de la web)
  PresenceChannel? _notifChannel;
  int? _notifUsuarioId;
  String? _notifServer;
  String? _notifToken;
  void Function()? _onNotificacion;
  bool _conectado = false;

  Future<void> connect({
    required String server,
    required String deviceToken,
    required String phoneNumberId,
    required void Function(Map<String, dynamic> data) onMensajeSent,
    required void Function(Map<String, dynamic> data) onMensajeLeido,
    void Function(Map<String, dynamic> data)? onMensajeEstado,
    void Function()? onConnected, // se llama al conectar y en cada reconexión (para ponerse al día)
  }) async {
    if (_client != null) return;

    final uri = Uri.parse(server);
    final options = PusherChannelsOptions.fromHost(
      scheme: 'wss',
      host: uri.host,
      key: '2C77uk6Ujmqyc11uuAbx',
      port: 443,
    );

    debugPrint('🔌 URI de conexión Pusher: ${options.uri}'); // AGREGADO

    _client = PusherChannelsClient.websocket(
      options: options,
      connectionErrorHandler: (exception, trace, refresh) async {
        debugPrint(
          '❌ Error de conexión Pusher: $exception',
        ); // ya existente, ahora clave
        refresh();
      },
    );

    _channel = _client!.presenceChannel(
      'presence-chat.$phoneNumberId',
      authorizationDelegate:
          EndpointAuthorizableChannelTokenAuthorizationDelegate.forPresenceChannel(
            authorizationEndpoint: Uri.parse(
              '$server/api/mobile/broadcasting/auth',
            ),
            headers: {'Authorization': 'Bearer $deviceToken'},
          ),
    );

    // AGREGADO: ver éxito/error de autenticación del canal
    _subs.add(
      _channel!.bind('pusher:subscription_succeeded').listen((event) {
        debugPrint(
          '✅ Suscripción exitosa al canal presence-chat.$phoneNumberId',
        );
      }),
    );
    _subs.add(
      _channel!.bind('pusher:subscription_error').listen((event) {
        debugPrint('❌ Error de suscripción: ${event.data}');
      }),
    );

    _subs.add(
      _channel!.bind('mensaje.enviado').listen((event) {
        onMensajeSent(jsonDecode(event.data));
      }),
    );
    _subs.add(
      _channel!.bind('mensaje.leido').listen((event) {
        onMensajeLeido(jsonDecode(event.data));
      }),
    );

    if (onMensajeEstado != null) {
      _subs.add(
        _channel!.bind('mensaje.estado').listen((event) {
          try {
            onMensajeEstado(jsonDecode(event.data));
          } catch (e) {
            debugPrint('⚠️ mensaje.estado inválido: $e');
          }
        }),
      );
    }

    // AGREGADO: log de conexión establecida
    _subs.add(
      _client!.onConnectionEstablished.listen((_) {
        debugPrint('🔌✅ Conexión Pusher establecida');
        _conectado = true;
        _channel?.subscribeIfNotUnsubscribed();
        _notifChannel?.subscribeIfNotUnsubscribed();
        onConnected?.call();
      }),
    );

    _enlazarNotificaciones(); // si las alertas se pidieron antes de conectar
    unawaited(_client!.connect());
  }

  /// Escucha el evento NotificacionEvent del usuario y avisa para recargar las alertas. Se puede llamar varias veces.
  void suscribirNotificaciones({
    required int usuarioId,
    required String server,
    required String deviceToken,
    required void Function() onNotificacion,
  }) {
    _notifUsuarioId = usuarioId;
    _notifServer = server;
    _notifToken = deviceToken;
    _onNotificacion = onNotificacion;
    _enlazarNotificaciones();
  }

  void _enlazarNotificaciones() {
    final client = _client;
    final id = _notifUsuarioId;
    if (client == null || id == null || _notifChannel != null) return;

    _notifChannel = client.presenceChannel(
      'presence-notificacion.$id',
      authorizationDelegate:
          EndpointAuthorizableChannelTokenAuthorizationDelegate.forPresenceChannel(
            authorizationEndpoint: Uri.parse('$_notifServer/api/mobile/broadcasting/auth'),
            headers: {'Authorization': 'Bearer $_notifToken'},
          ),
    );
    _subs.add(_notifChannel!.bind('pusher:subscription_succeeded').listen((_) {
      debugPrint('✅ Suscripción exitosa al canal presence-notificacion.$id');
    }));
    _subs.add(_notifChannel!.bind('pusher:subscription_error').listen((event) {
      debugPrint('❌ Error de suscripción a alertas: ${event.data}');
    }));
    _subs.add(_notifChannel!.bind('App\\Events\\NotificacionEvent').listen((_) {
      debugPrint('🔔 NotificacionEvent recibido');
      _onNotificacion?.call();
    }));
    if (_conectado) _notifChannel!.subscribeIfNotUnsubscribed();
  }

  Future<void> disconnect() async {
    for (final s in _subs) {
      await s.cancel();
    }
    _subs.clear();
    _channel?.unsubscribe();
    _notifChannel?.unsubscribe();
    _client?.dispose();
    _client = null;
    _channel = null;
    _notifChannel = null;
    _conectado = false;
  }
}