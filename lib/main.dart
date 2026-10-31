import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app_links/app_links.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'dart:async';
import 'dart:io';

import 'core/constants/app_constants.dart';
import 'core/models/message.dart';
import 'core/providers/app_providers.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/services/cache_service.dart';
import 'core/services/api_service.dart';
import 'core/services/pusher_service.dart';
import 'core/services/push_service.dart';
import 'core/services/notification_service.dart';
import 'core/services/session_events.dart';
import 'widgets/app_gate.dart';

// MODIFICADO: Ahora es async y inicializa los formatos de fecha
void main() async {
  // Asegura que los bindings de Flutter estén listos antes de hacer operaciones async
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  // Inicializa el idioma español para las fechas (ej. "15 de Octubre")
  await initializeDateFormatting('es', null);

  runApp(const ProviderScope(child: GijacApp()));
}

class GijacApp extends ConsumerStatefulWidget {
  const GijacApp({super.key});

  @override
  ConsumerState<GijacApp> createState() => _GijacAppState();
}

class _GijacAppState extends ConsumerState<GijacApp> with WidgetsBindingObserver {
  StreamSubscription? _deepLinkSubscription;
  final CacheService _cacheService = CacheService();
  final AppLinks _appLinks = AppLinks();
  final ApiService _apiService = ApiService();
  final PusherService _pusherService = PusherService();
  final GlobalKey<ScaffoldMessengerState> _messengerKey = GlobalKey<ScaffoldMessengerState>();

  @override
  void initState() {
    super.initState();
    // Si el servidor revoca la sesión (401), volver a la pantalla de vinculación
    ApiService.onUnauthorized = () => appRouter.go(Routes.qrLogin);
    _initDeepLinks();
    SessionEvents.onLogin = _initPusherIfLoggedIn;
    _initPusherIfLoggedIn();
    WidgetsBinding.instance.addObserver(this);
  }

  /// Sin consultas periódicas: todo llega por tiempo real (Pusher) y push (FCM).
  /// Solo se pone al día al volver a la app o cuando el tiempo real se reconecta.
  Future<void> _sincronizar() async {
    if (await _cacheService.getDeviceToken() == null) return;
    NotificationService.enviarPendientes();
    ref.read(chatsProvider.notifier).loadChats();
    ref.read(notificationsProvider.notifier).load();
    ref.invalidate(resumenProvider);
    final abierto = ref.read(conversationProvider.notifier).activeChatId;
    if (abierto != null) {
      ref.read(conversationProvider.notifier).refreshSilently(abierto);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _sincronizar();
  }
  Timer? _debounceLista;
  Timer? _debounceResumen;

  /// El resumen de Inicio se recalcula (en el servidor) poco después de cada mensaje o cambio de estado
  void _resumenPronto() {
    _debounceResumen?.cancel();
    _debounceResumen = Timer(const Duration(milliseconds: 1500), () {
      ref.invalidate(resumenProvider);
    });
  }

  void _recargarListaPronto() {
    _debounceLista?.cancel();
    _debounceLista = Timer(const Duration(seconds: 2), () {
      ref.read(chatsProvider.notifier).loadChats();
    });
  }

  Future<void> _initPusherIfLoggedIn() async {
    debugPrint('🔍 Verificando sesión para Pusher...');
    try {
      final server = await _cacheService.getServerUrl();
      final token = await _cacheService.getDeviceToken();
      if (server == null || token == null) {
        debugPrint('⚠️ No hay sesión activa, no se conecta Pusher');
        return;
      }

      // Pide el permiso de notificaciones y registra el token en cuanto hay sesión (sin esperar al perfil)
      _initPush();

      final profile = await _apiService.getProfile();
      final phoneNumberId = profile.phoneNumberId;
      debugPrint('🔍 phoneNumberId obtenido: $phoneNumberId'); // AGREGADO
      if (phoneNumberId == null) {
        debugPrint(
          '⚠️ phoneNumberId es null, no se conecta Pusher',
        ); // AGREGADO
        return;
      }

      debugPrint(
        '🔌 Conectando a Pusher, canal: presence-chat.$phoneNumberId',
      ); // AGREGADO

      await _pusherService.connect(
        server: server,
        deviceToken: token,
        phoneNumberId: phoneNumberId,
        onMensajeSent: (data) {
          debugPrint('📨 Pusher mensaje.enviado: ${data['mensaje']?['wa_from']} -> ${data['mensaje']?['wa_to']} (canal $phoneNumberId)');
          final mensajeData = data['mensaje'] as Map<String, dynamic>?;
          if (mensajeData == null) return;
          _resumenPronto();

          final waFrom = mensajeData['wa_from']?.toString();
          final waTo = mensajeData['wa_to']?.toString();
          final myPhoneNumberId =
              data['phone_number_id']?.toString() ?? phoneNumberId;
          final bool esMio = waFrom == myPhoneNumberId;
          final String chatId = esMio ? (waTo ?? '') : (waFrom ?? '');
          if (chatId.isEmpty) return;

          final mapped = {
            'id': mensajeData['id'],
            'tipo': mensajeData['type'],
            'estado': mensajeData['estado'],
            'es mio': esMio,
            'metadata': mensajeData['metadata'],
            'contenido': mensajeData['body'],
            'fecha': mensajeData['sent_at'] ?? mensajeData['created_at'],
            'url_archivo': mensajeData['url_archivo'],
          };
          final message = Message.fromJson(mapped);

          final isChatOpen = ref
              .read(conversationProvider.notifier)
              .isViewingChat(chatId);
          ref
              .read(conversationProvider.notifier)
              .receiveRealtimeMessage(chatId, message, isMine: esMio);
          final aplicado = ref
              .read(chatsProvider.notifier)
              .receiveRealtimeMessage(
                chatId,
                message,
                isMine: esMio,
                isChatOpen: isChatOpen,
                serverUnread: int.tryParse('${data['no_leidos']}'),
              );
          // Solo si es un contacto que aún no está en la lista se consulta al servidor
          if (!aplicado) _recargarListaPronto();
        },
        onConnected: _sincronizar,
        onMensajeLeido: (data) {
          debugPrint('👁️ Mensaje leído: $data');
        },
        onMensajeEstado: (data) {
          final id = (data['id'] ?? data['mensaje_id'])?.toString();
          final estado = int.tryParse('${data['estado']}');
          _resumenPronto();
          if (id == null || estado == null) return;
          ref.read(conversationProvider.notifier).applyStatus(id, estado);
        },
      );
    } catch (e, st) {
      debugPrint('⚠️ No se pudo conectar Pusher al iniciar: $e');
      debugPrint('$st'); // AGREGADO: stack trace completo
    }
  }

  void _initPush() {
    PushService.instance.init(
      onOpenChat: (chatId, nombre) =>
          appRouter.push('/chats/$chatId', extra: {'nombre': nombre ?? chatId}),
      isViewingChat: (chatId) =>
          ref.read(conversationProvider.notifier).isViewingChat(chatId),
      onForeground: (titulo, cuerpo, chatId, nombre) {
        ref.read(chatsProvider.notifier).loadChats();
        // Aviso en la barra superior del sistema (como WhatsApp), también con la app abierta
        NotificationService.mostrar({
          'titulo': titulo,
          'cuerpo': cuerpo,
          'chat_id': chatId,
          'nombre': nombre ?? titulo,
        });
      },
    );
  }

  Future<void> _initDeepLinks() async {
    try {
      final uri = await _appLinks.getInitialLink();
      if (uri != null) {
        _handleDeepLink(uri);
      }
    } catch (e) {
      debugPrint('Error getting initial link: $e');
    }

    _deepLinkSubscription = _appLinks.uriLinkStream.listen(
      (Uri? uri) {
        if (uri != null) {
          _handleDeepLink(uri);
        }
      },
      onError: (err) {
        debugPrint('Error on deep link stream: $err');
      },
    );
  }

  Future<void> _handleDeepLink(Uri uri) async {
    debugPrint('Deep link received: $uri');

    if (uri.scheme == 'gijac' && uri.host == 'auth') {
      final token = uri.queryParameters['token'];
      final server = uri.queryParameters['server'];

      if (token != null && server != null) {
        // 1. Guardar servidor temporalmente
        await _cacheService.saveServerUrl(server);

        // 2. Obtener info del celular
        final deviceData = await _getDeviceInfo();

        // 3. Enviar datos a Laravel (no bloquea el flujo si falla)
        try {
          await _apiService.registerDevice({
            'token': token,
            'nombre_dispositivo': deviceData['nombre_dispositivo'],
            'modelo': deviceData['modelo'],
            'sistema_operativo': deviceData['sistema_operativo'],
            'version_so': deviceData['version_so'],
            'fcm_token': deviceData['fcm_token'],
            'ip': null,
          });
        } catch (e) {
          debugPrint('⚠️ No se pudo registrar dispositivo: $e');
        }

        // 4. Guardar el token (SIEMPRE)
        await _cacheService.saveDeviceToken(token);

        debugPrint('Token saved from deep link');

        _initPush(); // pide el permiso de notificaciones al iniciar sesión

        _initPusherIfLoggedIn();

        if (mounted) {
          appRouter.go('/dashboard');
        }
      }
    }
  }

  Future<Map<String, dynamic>> _getDeviceInfo() async {
    final device = DeviceInfoPlugin();
    var info = {
      'nombre_dispositivo': 'Desconocido',
      'modelo': null,
      'sistema_operativo': 'Desconocido',
      'version_so': null,
      'fcm_token': null,
    };

    try {
      if (Platform.isAndroid) {
        final android = await device.androidInfo;
        info = {
          'nombre_dispositivo': android.model ?? 'Android',
          'modelo': android.model,
          'sistema_operativo': 'Android',
          'version_so': android.version.release,
          'fcm_token': null,
        };
      } else if (Platform.isIOS) {
        final ios = await device.iosInfo;
        info = {
          'nombre_dispositivo': ios.name ?? 'iPhone',
          'modelo': ios.model,
          'sistema_operativo': 'iOS',
          'version_so': ios.systemVersion,
          'fcm_token': null,
        };
      }
    } catch (e) {
      debugPrint('❌ Error obteniendo info: $e');
    }

    try {
      info['fcm_token'] = await FirebaseMessaging.instance.getToken();
    } catch (e) {
      debugPrint('⚠️ No se pudo obtener el token FCM: $e');
    }

    return info;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _debounceLista?.cancel();
    _debounceResumen?.cancel();
    _deepLinkSubscription?.cancel();
    _pusherService.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      scaffoldMessengerKey: _messengerKey,
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      routerConfig: appRouter,
      builder: (context, child) => AppGate(child: child ?? const SizedBox.shrink()),
    );
  }
}