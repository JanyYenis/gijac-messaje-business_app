import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gmb/core/services/cache_service.dart';

import '../models/app_notification.dart';
import '../models/chat.dart';
import '../models/message.dart';
import '../services/mock_data.dart';
import '../services/api_service.dart';
import '../services/ajustes_service.dart';
import '../services/pusher_service.dart';

/// Controls light / dark / system theme mode.
final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);

class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    // El tema elegido se guarda en el teléfono y se recupera al abrir la app
    AjustesService.temaGuardado().then((m) {
      if (m != state) state = m;
    });
    return ThemeMode.system;
  }

  void set(ThemeMode mode) {
    state = mode;
    AjustesService.guardarTema(mode);
  }

  void toggle() => set(state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark);
}

/// Avisos de mensajes nuevos activados/desactivados en este dispositivo.
final notificacionesActivasProvider =
    AsyncNotifierProvider<NotificacionesActivasNotifier, bool>(NotificacionesActivasNotifier.new);

class NotificacionesActivasNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() => AjustesService.notificacionesActivas();

  /// true si quedó en el estado pedido
  Future<bool> cambiar(bool activar) async {
    final ok = await AjustesService.cambiarNotificaciones(activar);
    if (ok) state = AsyncData(activar);
    return ok;
  }
}

/// NUEVO: Proveedor de la API
final apiServiceProvider = Provider<ApiService>((ref) => ApiService());

/// All chats, with simple mutations.
final chatsProvider = NotifierProvider<ChatsNotifier, List<Chat>>(
  ChatsNotifier.new,
);

class ChatsNotifier extends Notifier<List<Chat>> {
  @override
  List<Chat> build() {
    // Disparamos la petición en segundo plano
    _fetchRealChats();
    return [];
  }

  /// Recarga manual (pull-to-refresh).
  Future<void> loadChats() => _fetchRealChats();

  Future<void> _fetchRealChats() async {
    final cacheService = CacheService();

    // 1. CARGAR DEL CACHÉ INMEDIATAMENTE
    final cachedChats = await cacheService.getCachedChats();
    if (cachedChats.isNotEmpty) {
      state = cachedChats;
    }

    // 2. INTENTAR TRAER DE LA API
    try {
      final api = ref.read(apiServiceProvider);
      final chats = await api.getChats();
      state = chats; // Actualiza la UI

      // 3. ACTUALIZAR CACHÉ
      await cacheService.cacheChats(chats);
    } catch (e) {
      debugPrint('❌ Error cargando chats reales: $e');
      // Si falla la API, se queda con los datos del caché (si los hay)
    }
  }

  Chat byId(String id) => state.firstWhere((c) => c.id == id);

  /// Devuelve false si el chat aún no está en la lista (contacto nuevo): el llamador recarga la lista.
  /// [serverUnread] es el contador real que envía el servidor en el evento.
  bool receiveRealtimeMessage(
    String chatId,
    Message message, {
    required bool isMine,
    required bool isChatOpen,
    int? serverUnread,
  }) {
    final idx = state.indexWhere((c) => c.id == chatId);
    if (idx == -1) return false;

    final c = state[idx];
    final newUnread = (isMine || isChatOpen) ? 0 : (serverUnread ?? c.unreadCount + 1);

    state = [
      for (final ch in state)
        if (ch.id == chatId)
          Chat(
            id: ch.id,
            contact: ch.contact,
            lastMessage: switch (message.type) {
              MessageType.image => message.caption ?? '📷 Imagen',
              MessageType.video => message.caption ?? '🎬 Video',
              MessageType.audio => '🎤 Audio',
              MessageType.document || MessageType.pdf => '📄 Documento',
              _ => message.text ?? ch.lastMessage,
            },
            lastTime: message.time,
            unreadCount: newUnread,
            status: ch.status,
            isPinned: ch.isPinned,
            isMuted: ch.isMuted,
            assignedAgent: ch.assignedAgent,
            messages: ch.messages,
            rawTime: 'Ahora',
          )
        else
          ch,
    ];
    // El chat con actividad nueva sube al primer lugar (como WhatsApp)
    final subir = state.firstWhere((ch) => ch.id == chatId);
    state = [subir, ...state.where((ch) => ch.id != chatId)];
    return true;
  }

  void markRead(String id) {
    state = [
      for (final c in state)
        if (c.id == id)
          Chat(
            id: c.id,
            contact: c.contact,
            lastMessage: c.lastMessage,
            lastTime: c.lastTime,
            unreadCount: 0,
            status: c.status,
            isPinned: c.isPinned,
            isMuted: c.isMuted,
            assignedAgent: c.assignedAgent,
            messages: c.messages,
            rawTime: c.rawTime,
          )
        else
          c,
    ];
  }

  // AGREGADO: Para actualizar la lista cuando se envía un mensaje desde la conversación
  void updateLastMessage(String chatId, String text) {
    state = [
      for (final c in state)
        if (c.id == chatId)
          Chat(
            id: c.id,
            contact: c.contact,
            lastMessage: text,
            lastTime: DateTime.now(),
            unreadCount: 0,
            status: c.status,
            isPinned: c.isPinned,
            isMuted: c.isMuted,
            assignedAgent: c.assignedAgent,
            messages: c.messages,
            rawTime: 'Ahora',
          )
        else
          c,
    ];
  }

  void sendText(String chatId, String text) {
    if (text.trim().isEmpty) return;
    state = [
      for (final c in state)
        if (c.id == chatId)
          Chat(
            id: c.id,
            contact: c.contact,
            lastMessage: text,
            lastTime: DateTime.now(),
            unreadCount: 0,
            status: c.status,
            isPinned: c.isPinned,
            isMuted: c.isMuted,
            assignedAgent: c.assignedAgent,
            messages: [
              ...c.messages,
              Message(
                id: 'm${DateTime.now().millisecondsSinceEpoch}',
                type: MessageType.text,
                source: MessageSource.agent,
                time: DateTime.now(),
                text: text,
                status: MessageStatus.sent,
              ),
            ],
            rawTime: 'Ahora',
          )
        else
          c,
    ];
  }
}

/// Current chat list filter.
enum ChatFilter { all, unread, bot, resolved }

final chatFilterProvider = StateProvider<ChatFilter>((ref) => ChatFilter.all);
final chatSearchProvider = StateProvider<String>((ref) => '');

final filteredChatsProvider = Provider<List<Chat>>((ref) {
  final chats = ref.watch(chatsProvider);
  final filter = ref.watch(chatFilterProvider);
  final query = ref.watch(chatSearchProvider).toLowerCase();

  Iterable<Chat> result = chats;
  switch (filter) {
    case ChatFilter.unread:
      result = result.where((c) => c.unreadCount > 0);
      break;
    case ChatFilter.bot:
      result = result.where((c) => c.status == ChatStatus.bot);
      break;
    case ChatFilter.resolved:
      result = result.where((c) => c.status == ChatStatus.resolved);
      break;
    case ChatFilter.all:
      break;
  }
  if (query.isNotEmpty) {
    result = result.where(
      (c) =>
          c.contact.name.toLowerCase().contains(query) ||
          c.lastMessage.toLowerCase().contains(query),
    );
  }
  final list = result.toList()
    ..sort((a, b) {
      if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
      return b.lastTime.compareTo(a.lastTime);
    });
  return list;
});

/// Notifications.
final notificationsProvider =
    NotifierProvider<NotificationsNotifier, List<AppNotification>>(
      NotificationsNotifier.new,
    );

class NotificationsNotifier extends Notifier<List<AppNotification>> {
  @override
  List<AppNotification> build() {
    Future.microtask(load); // al primer uso se traen las alertas reales
    return const [];
  }

  int get unreadCount => state.where((n) => !n.isRead).length;

  /// Trae las alertas del servidor. Sin conexión se conservan las que ya hay.
  Future<void> load() async {
    try {
      state = await ApiService().getNotifications();
      _escucharEnVivo();
    } catch (e) {
      debugPrint('⚠️ Alertas: $e');
    }
  }

  /// Se suscribe una sola vez al canal de alertas del usuario; cada evento recarga la lista
  Future<void> _escucharEnVivo() async {
    final uid = ApiService.usuarioIdNotif;
    if (uid == null) return;
    final server = await CacheService().getServerUrl();
    final token = await CacheService().getDeviceToken();
    if (server == null || token == null) return;
    PusherService().suscribirNotificaciones(
      usuarioId: uid,
      server: server,
      deviceToken: token,
      onNotificacion: load,
    );
  }

  Future<void> markAllRead() async {
    final antes = state;
    state = [for (final n in state) n.copyWith(isRead: true)];
    try {
      await ApiService().markNotificationsRead();
    } catch (_) {
      state = antes; // no se pudo guardar: se deja como estaba
    }
  }

  Future<void> markRead(String id) async {
    state = [for (final n in state) n.id == id ? n.copyWith(isRead: true) : n];
    try {
      await ApiService().markNotificationsRead(id);
    } catch (_) {}
  }
}

/// Resumen de Inicio: datos reales; sin conexión se muestra lo último guardado.
final resumenProvider = FutureProvider.autoDispose<Map<String, int>>((ref) async {
  const clave = 'resumen_inicio_cache';
  try {
    final r = await ApiService().getResumen();
    try {
      (await SharedPreferences.getInstance()).setString(clave, jsonEncode(r));
    } catch (_) {}
    return r;
  } catch (e) {
    try {
      final txt = (await SharedPreferences.getInstance()).getString(clave);
      if (txt != null) {
        return (jsonDecode(txt) as Map).map((k, v) => MapEntry(k.toString(), int.tryParse('$v') ?? 0));
      }
    } catch (_) {}
    rethrow;
  }
});

final unreadNotificationsProvider = Provider<int>((ref) {
  final list = ref.watch(notificationsProvider);
  return list.where((n) => !n.isRead).length;
});

/// Privacy settings state.
class PrivacySettings {
  const PrivacySettings({
    this.lastSeen = 'Mis contactos',
    this.profilePhoto = 'Todos',
    this.about = 'Mis contactos',
    this.groupAdd = 'Mis contactos',
    this.readReceipts = true,
    this.blockScreenshots = false,
    this.blockedCount = 3,
  });

  final String lastSeen;
  final String profilePhoto;
  final String about;
  final String groupAdd;
  final bool readReceipts;
  final bool blockScreenshots;
  final int blockedCount;

  PrivacySettings copyWith({
    String? lastSeen,
    String? profilePhoto,
    String? about,
    String? groupAdd,
    bool? readReceipts,
    bool? blockScreenshots,
    int? blockedCount,
  }) {
    return PrivacySettings(
      lastSeen: lastSeen ?? this.lastSeen,
      profilePhoto: profilePhoto ?? this.profilePhoto,
      about: about ?? this.about,
      groupAdd: groupAdd ?? this.groupAdd,
      readReceipts: readReceipts ?? this.readReceipts,
      blockScreenshots: blockScreenshots ?? this.blockScreenshots,
      blockedCount: blockedCount ?? this.blockedCount,
    );
  }
}

final privacySettingsProvider =
    NotifierProvider<PrivacySettingsNotifier, PrivacySettings>(
      PrivacySettingsNotifier.new,
    );

class PrivacySettingsNotifier extends Notifier<PrivacySettings> {
  @override
  PrivacySettings build() => const PrivacySettings();

  void setLastSeen(String v) => state = state.copyWith(lastSeen: v);
  void setProfilePhoto(String v) => state = state.copyWith(profilePhoto: v);
  void setAbout(String v) => state = state.copyWith(about: v);
  void setGroupAdd(String v) => state = state.copyWith(groupAdd: v);
  void toggleReadReceipts() =>
      state = state.copyWith(readReceipts: !state.readReceipts);
  void toggleBlockScreenshots() =>
      state = state.copyWith(blockScreenshots: !state.blockScreenshots);
}

// =========================================================================
// NUEVO: PROVIDERS DE CONVERSACIÓN ACTIVA
// =========================================================================

/// Para saber si está cargando la primera vez (y mostrar el CircularIndicator)
final isConversationLoadingProvider = StateProvider<bool>((ref) => true);

/// Último error de envío (la pantalla lo muestra en un aviso y lo limpia)
final conversationErrorProvider = StateProvider<String?>((ref) => null);

/// Maneja los mensajes de la conversación que está abierta actualmente
final conversationProvider =
    NotifierProvider<ConversationNotifier, List<Message>>(
      ConversationNotifier.new,
    );

class ConversationNotifier extends Notifier<List<Message>> {
  @override
  List<Message> build() => [];

  bool _isLoadingMore = false;
  String? _activeChatId;

  /// Acciones de envío pendientes o fallidas, por id temporal (para reintentar)
  final Map<String, Future<Message> Function()> _pendientes = {};

  /// Mensajes confirmados por el servidor (los locales no se guardan en caché)
  List<Message> get _persistibles => state.where((m) => !m.isLocal).toList();
  final CacheService _cacheService = CacheService(); // <--- AGREGADO

  // AGREGADO: saber si el chat dado es el que está abierto ahora mismo
  bool isViewingChat(String chatId) => _activeChatId == chatId;
  String? get activeChatId => _activeChatId;

  /// Al salir de la conversación ya no se considera abierta
  void leaveChat(String chatId) {
    if (_activeChatId == chatId) _activeChatId = null;
  }

  // AGREGADO: insertar un mensaje que llegó por Pusher, solo si es el chat abierto
  void receiveRealtimeMessage(String chatId, Message message, {bool isMine = false}) {
    if (_activeChatId != chatId) return;
    if (state.any((m) => m.id == message.id)) return; // evitar duplicados

    // El evento en tiempo real no trae la URL del archivo ni los datos completos de los mensajes
    // propios o multimedia: se pide al servidor el mensaje completo en lugar de pintar el evento tal cual.
    if (isMine || message.type != MessageType.text) {
      Future.delayed(const Duration(milliseconds: 900), () => refreshSilently(chatId));
      return;
    }
    state = [...state, message];
    _cacheService.cacheMessages(chatId, _persistibles);
  }

  /// Cargar mensajes al entrar (o reentrar) al chat
  Future<void> loadMessages(String numero) async {
    // Otro chat: no mostrar los mensajes del anterior mientras carga
    if (_activeChatId != numero) state = [];
    _activeChatId = numero;
    final loadingState = ref.read(isConversationLoadingProvider.notifier);
    loadingState.state = true;

    // 1. LEER DEL CACHÉ INMEDIATAMENTE (Estilo WhatsApp)
    final cachedMessages = await _cacheService.getCachedMessages(numero);
    if (_activeChatId != numero) return;
    if (cachedMessages.isNotEmpty) {
      state = cachedMessages;
      loadingState.state =
          false; // Ya tenemos algo que mostrar, quitamos el loading
    }

    // 2. INTENTAR TRAER DE LA API (En segundo plano)
    try {
      final api = ref.read(apiServiceProvider);
      final res = await api.getChatMessages(numero);
      if (_activeChatId != numero) return;

      final List<dynamic> rawMessages = res['messages'] ?? [];
      final apiMessages = rawMessages.map((e) => Message.fromJson(e)).toList();

      // Datos frescos + los mensajes que aún se están enviando (o fallaron)
      state = [...apiMessages, ...state.where((m) => m.isLocal)];

      // 3. ACTUALIZAR CACHÉ con lo más reciente
      await _cacheService.cacheMessages(numero, apiMessages);

      // 4. Marcar como leído en segundo plano
      api.markAsRead(numero);
      ref.read(chatsProvider.notifier).markRead(numero);
    } catch (e) {
      debugPrint('❌ Error cargando mensajes de API: $e');

      // Si NO HABÍA caché y falló la API, dejamos el estado vacío para que la UI muestre el error
      if (cachedMessages.isEmpty) {
        state = [];
      }
      // Si SÍ HABÍA caché, simplemente dejamos los mensajes del caché en el 'state'
      // y el usuario nunca se entera de que no hay internet.
    } finally {
      // Asegurarnos de quitar el loading en caso de que no hubiera caché
      if (_activeChatId == numero) {
        loadingState.state = false;
      }
    }
  }

  /// Refresco silencioso (sin loading): trae lo último del servidor, actualiza estados
  /// (enviado/entregado/leído) y agrega mensajes nuevos. Conserva los locales.
  Future<void> refreshSilently(String numero) async {
    if (_activeChatId != numero || _isLoadingMore) return;
    try {
      final api = ref.read(apiServiceProvider);
      final res = await api.getChatMessages(numero);
      if (_activeChatId != numero) return;

      final nuevos = ((res['messages'] ?? []) as List)
          .map((e) => Message.fromJson(e))
          .toList();
      if (nuevos.isEmpty) return;

      final porId = {for (final m in nuevos) m.id: m};
      final actuales = state.where((m) => !m.isLocal).toList();
      final idsActuales = actuales.map((m) => m.id).toSet();

      var cambio = false;
      final fusion = <Message>[];
      for (final m in actuales) {
        final fresco = porId[m.id];
        if (fresco != null && (m.urlArchivo == null && fresco.urlArchivo != null)) {
          cambio = true; // el archivo ya está disponible
          fusion.add(fresco);
        } else if (fresco != null && fresco.status != m.status) {
          cambio = true;
          fusion.add(m.copyWith(status: fresco.status));
        } else {
          fusion.add(m);
        }
      }
      final agregados = nuevos.where((m) => !idsActuales.contains(m.id)).toList();
      // Un mensaje enviado desde aquí ya llegó con su id real: no duplicar el temporal
      if (agregados.isNotEmpty) cambio = true;
      if (!cambio) return;

      fusion.addAll(agregados);
      fusion.sort((a, b) => a.time.compareTo(b.time));
      state = [...fusion, ...state.where((m) => m.isLocal)];
      await _cacheService.cacheMessages(numero, _persistibles);

      if (agregados.any((m) => !m.isOutgoing)) {
        api.markAsRead(numero);
        ref.read(chatsProvider.notifier).markRead(numero);
      }
    } catch (e) {
      debugPrint('⚠️ Refresco silencioso falló: $e');
    }
  }

  /// Cambio de estado recibido por tiempo real (entregado / leído / fallido)
  void applyStatus(String messageId, int estado) {
    final nuevo = Message.statusFromInt(estado);
    final idx = state.indexWhere((m) => m.id == messageId);
    if (idx == -1 || state[idx].status == nuevo) return;
    state = [
      for (final m in state)
        if (m.id == messageId) m.copyWith(status: nuevo) else m,
    ];
    _cacheService.cacheMessages(_activeChatId ?? '', _persistibles);
  }

  /// Cargar mensajes anteriores (Scroll hacia arriba)
  Future<void> loadOlderMessages(String numero) async {
    if (state.isEmpty || _isLoadingMore) return;
    _isLoadingMore = true;

    try {
      final api = ref.read(apiServiceProvider);
      final res = await api.getChatMessages(numero, beforeId: state.first.id);

      final List<dynamic> rawMessages = res['messages'] ?? [];
      if (rawMessages.isNotEmpty) {
        final olderMessages = rawMessages
            .map((e) => Message.fromJson(e))
            .toList();
        state = [...olderMessages, ...state];

        // Actualizar el caché con el historial completo ahora
        await _cacheService.cacheMessages(numero, _persistibles);
      }
    } catch (e) {
      debugPrint('❌ Error cargando mensajes antiguos: $e');
    } finally {
      _isLoadingMore = false;
    }
  }

  /// Enviar mensaje de texto
  Future<void> sendMessage(String numero, String text) async {
    final limpio = text.trim();
    if (limpio.isEmpty) return;

    // 1. Mostrar inmediatamente en la UI (Optimistic UI)
    final temp = Message.localTemp(text: limpio);
    state = [...state, temp];

    await _enviar(numero, temp, () => ref.read(apiServiceProvider).sendMessage(numero, limpio), limpio);
  }

  /// Enviar imagen, video, audio o documento
  Future<void> sendMedia(
    String numero,
    File file,
    MessageType type, {
    String? caption,
    String? fileName,
  }) async {
    final temp = Message.localTemp(
      type: type,
      localPath: file.path,
      fileName: fileName,
      caption: (caption != null && caption.trim().isNotEmpty) ? caption.trim() : null,
    );
    state = [...state, temp];

    final etiqueta = switch (type) {
      MessageType.image => '📷 Imagen',
      MessageType.video => '🎬 Video',
      MessageType.audio => '🎤 Audio',
      _ => '📄 Documento',
    };

    await _enviar(
      numero,
      temp,
      () => ref.read(apiServiceProvider).sendMedia(numero, file, caption: temp.caption),
      temp.caption ?? etiqueta,
    );
  }

  /// Reintentar un mensaje que falló
  Future<void> retry(String numero, String tempId) async {
    final accion = _pendientes[tempId];
    if (accion == null) return;
    final idx = state.indexWhere((m) => m.id == tempId);
    if (idx == -1) return;

    final temp = state[idx].copyWith(status: MessageStatus.sending);
    state = [for (final m in state) m.id == tempId ? temp : m];
    await _enviar(numero, temp, accion, temp.text ?? temp.caption ?? '');
  }

  /// Descartar un mensaje fallido
  void discard(String tempId) {
    _pendientes.remove(tempId);
    state = state.where((m) => m.id != tempId).toList();
  }

  Future<void> _enviar(
    String numero,
    Message temp,
    Future<Message> Function() accion,
    String resumen,
  ) async {
    _pendientes[temp.id] = accion;
    try {
      final real = await accion();
      _pendientes.remove(temp.id);

      // Sigue abierto el mismo chat: reemplazar el temporal por el real
      if (_activeChatId == numero) {
        final yaLlego = state.any((m) => m.id == real.id); // llegó antes por tiempo real
        // El mensaje real conserva la imagen local por si la descarga de la URL falla
        final conLocal = real.copyWith(localPath: temp.localPath);
        state = yaLlego
            ? state.where((m) => m.id != temp.id).toList()
            : [for (final m in state) m.id == temp.id ? conLocal : m];
        await _cacheService.cacheMessages(numero, _persistibles);
      }
      ref.read(chatsProvider.notifier).updateLastMessage(numero, resumen);
    } catch (e) {
      debugPrint('❌ Error al enviar mensaje: $e');
      final motivo = e is ApiException ? e.message : 'No se pudo enviar el mensaje.';
      // El mensaje queda visible con estado "fallido" para poder reintentar o descartarlo
      if (_activeChatId == numero) {
        state = [
          for (final m in state)
            if (m.id == temp.id) m.copyWith(status: MessageStatus.failed, errorText: motivo) else m,
        ];
      }
      ref.read(conversationErrorProvider.notifier).state = motivo;
    }
  }
}