import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/user_profile.dart';
import '../models/whatsapp_business_profile.dart';
import '../models/app_notification.dart';
import '../models/chat.dart';
import '../models/message.dart';
import 'cache_service.dart';

/// Error de la API con el mensaje que se le puede mostrar al usuario.
class ApiException implements Exception {
  ApiException(this.message, {this.statusCode, this.code});
  final String message;
  final int? statusCode;
  final String? code; // ej. 'ventana_24h'

  @override
  String toString() => message;
}

class ApiService {
  final CacheService _cacheService = CacheService();

  /// Se ejecuta cuando el servidor responde 401 (sesión revocada o vencida).
  /// Lo configura main.dart para volver a la pantalla de vinculación.
  static void Function()? onUnauthorized;

  Future<void> _handleUnauthorized() async {
    await _cacheService.clearDeviceData();
    onUnauthorized?.call();
  }

  /// Extrae el texto de error del JSON del servidor.
  ApiException _errorFrom(http.Response response, String fallback) {
    try {
      final body = jsonDecode(response.body);
      if (body is Map) {
        return ApiException(
          (body['message'] ?? fallback).toString(),
          statusCode: response.statusCode,
          code: body['code']?.toString(),
        );
      }
    } catch (_) {}
    return ApiException(fallback, statusCode: response.statusCode);
  }

  // CAMBIADO: Ahora devuelve dynamic (puede ser Map o List)
  Future<dynamic> _get(String endpoint) async {
    final server = await _cacheService.getServerUrl();
    final token = await _cacheService.getDeviceToken();

    if (server == null || token == null) {
      throw Exception('No hay sesión activa');
    }

    debugPrint('📍 Consultando: $server/api/$endpoint');

    final url = Uri.parse('$server/api/$endpoint');

    try {
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        if (body['success'] == true) {
          return body['data'];
        }
        throw Exception(body['message'] ?? 'Error en la respuesta');
      } else {
        // IMPRIMIR EL CUERPO COMPLETO DEL ERROR
        debugPrint('❌ ERROR ${response.statusCode}: ${response.body}');
        if (response.statusCode == 401) await _handleUnauthorized();
        throw Exception('Error de conexión: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ EXCEPCIÓN: $e');
      rethrow;
    }
  }

  // Aquí forzamos el casteo a Map porque sabemos que el perfil devuelve un objeto
  Future<UserProfile> getProfile() async {
    final data = await _get('mobile/profile');
    return UserProfile.fromJson(data as Map<String, dynamic>);
  }

  // Aquí verificamos que sea una Lista antes de mapear los chats
  Future<List<Chat>> getChats() async {
    final data = await _get('mobile/chats');

    if (data is List) {
      return data
          .map((json) => Chat.fromJson(json as Map<String, dynamic>))
          .toList();
    }

    return [];
  }

  Future<bool> registerDevice(Map<String, dynamic> deviceData) async {
    final server = await _cacheService.getServerUrl();

    if (server == null) {
      throw Exception('No hay servidor configurado');
    }

    // CAMBIADO: Usar la URL del QR directamente (/device-link) en vez de la API (/api/mobile/device)
    final url = Uri.parse('$server/device-link');

    debugPrint('📱 Registrando dispositivo en: $url');
    debugPrint('📊 Datos: $deviceData');

    final http.Response response;
    try {
      response = await http
          .post(
            url,
            headers: {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(deviceData),
          )
          .timeout(const Duration(seconds: 15));
    } catch (e) {
      debugPrint('❌ Sin respuesta al registrar el dispositivo: $e');
      return false;
    }

    if (response.statusCode == 200 || response.statusCode == 201) {
      debugPrint('✅ Dispositivo registrado correctamente');
      return true;
    } else {
      debugPrint('❌ Error al registrar dispositivo: ${response.body}');
      return false;
    }
  }

  // =========================================================================
  // MENSAJES (AGREGADO)
  // =========================================================================

  /// Helper para no repetir los headers en las peticiones nuevas
  /// Si el servidor devuelve la ruta del archivo relativa (/storage/...), se completa con la URL del servidor
  Map<String, dynamic> _conUrlAbsoluta(dynamic m, String server) {
    final map = Map<String, dynamic>.from(m as Map);
    final u = map['url_archivo']?.toString();
    if (u != null && u.startsWith('/')) map['url_archivo'] = '$server$u';
    return map;
  }

  /// Envía al servidor el token de notificaciones push de este dispositivo
  Future<void> updateFcmToken(String fcmToken) async {
    final server = await _cacheService.getServerUrl();
    final token = await _cacheService.getDeviceToken();
    if (server == null || token == null) return;
    try {
      final r = await http
          .post(
            Uri.parse('$server/api/mobile/device/fcm'),
            headers: _authHeaders(token),
            body: jsonEncode({'fcm_token': fcmToken}),
          )
          .timeout(const Duration(seconds: 15));
      debugPrint('🔔 Token FCM enviado al servidor: HTTP ${r.statusCode}');
      if (r.statusCode == 401) _handleUnauthorized();
    } catch (e) {
      debugPrint('⚠️ No se pudo registrar el token FCM: $e');
    }
  }

  // ───── Editar perfil ─────
  /// Interpreta la respuesta de los endpoints de perfil (devuelve el perfil ya actualizado)
  Future<UserProfile> _perfilDe(http.Response r) async {
    if (r.statusCode == 401) await _handleUnauthorized();
    dynamic body;
    try {
      body = jsonDecode(r.body);
    } catch (_) {}
    if (r.statusCode == 200 && body is Map && body['success'] == true) {
      return UserProfile.fromJson(body['data'] as Map<String, dynamic>);
    }
    var mensaje = 'No se pudo guardar. Intenta de nuevo.';
    if (body is Map) {
      final errores = body['errors'];
      if (errores is Map && errores.isNotEmpty && errores.values.first is List && (errores.values.first as List).isNotEmpty) {
        mensaje = (errores.values.first as List).first.toString();
      } else if (body['message'] != null) {
        mensaje = body['message'].toString();
      }
    }
    debugPrint('❌ Perfil ${r.statusCode}: ${r.body}');
    throw ApiException(mensaje, statusCode: r.statusCode);
  }

  /// GET /mobile/profile/options y /profile/cities/{pais} — listas para el formulario
  Future<Map<String, dynamic>> _getLista(String ruta) async {
    final server = await _cacheService.getServerUrl();
    final token = await _cacheService.getDeviceToken();
    if (server == null || token == null) throw ApiException('No hay sesión activa');
    final http.Response r;
    try {
      r = await http.get(Uri.parse('$server/api/mobile/profile/$ruta'), headers: _authHeaders(token)).timeout(const Duration(seconds: 30));
    } catch (_) {
      throw ApiException('No se pudo conectar. Revisa tu conexión.');
    }
    if (r.statusCode == 401) await _handleUnauthorized();
    final body = r.statusCode == 200 ? jsonDecode(r.body) : null;
    if (body is Map && body['success'] == true) return {'data': body['data']};
    throw ApiException('No se pudieron cargar las opciones.', statusCode: r.statusCode);
  }

  Future<Map<String, List<Map<String, String>>>> getOpcionesPerfil() async {
    final data = (await _getLista('options'))['data'] as Map;
    List<Map<String, String>> a(dynamic l) =>
        (l as List).map((e) => {'id': e['id'].toString(), 'nombre': e['nombre'].toString()}).toList();
    return {'generos': a(data['generos']), 'documentos': a(data['documentos']), 'paises': a(data['paises'])};
  }

  Future<List<Map<String, String>>> getCiudades(String paisId) async {
    final data = (await _getLista('cities/$paisId'))['data'] as List;
    return data.map((e) => {'id': e['id'].toString(), 'nombre': e['nombre'].toString()}).toList();
  }

  /// PUT /mobile/profile — mismos campos que el formulario de la web
  Future<UserProfile> updateProfile(Map<String, dynamic> datos) async {
    final server = await _cacheService.getServerUrl();
    final token = await _cacheService.getDeviceToken();
    if (server == null || token == null) throw ApiException('No hay sesión activa');

    final http.Response r;
    try {
      r = await http
          .put(
            Uri.parse('$server/api/mobile/profile'),
            headers: _authHeaders(token),
            body: jsonEncode(datos),
          )
          .timeout(const Duration(seconds: 30));
    } catch (_) {
      throw ApiException('No se pudo conectar. Revisa tu conexión.');
    }
    return _perfilDe(r);
  }

  /// POST /mobile/profile/photo — sube la foto de perfil (la misma que se ve en la web)
  Future<UserProfile> uploadProfilePhoto(File foto) async {
    final server = await _cacheService.getServerUrl();
    final token = await _cacheService.getDeviceToken();
    if (server == null || token == null) throw ApiException('No hay sesión activa');

    final request = http.MultipartRequest('POST', Uri.parse('$server/api/mobile/profile/photo'))
      ..headers.addAll({'Authorization': 'Bearer $token', 'Accept': 'application/json'})
      ..files.add(await http.MultipartFile.fromPath('foto', foto.path));

    final http.Response r;
    try {
      final streamed = await request.send().timeout(const Duration(minutes: 1));
      r = await http.Response.fromStream(streamed);
    } catch (_) {
      throw ApiException('No se pudo subir la foto. Revisa tu conexión.');
    }
    return _perfilDe(r);
  }

  // ───── Perfil de WhatsApp Business ─────
  Future<Map<String, String>> _waHeaders() async {
    final token = await _cacheService.getDeviceToken();
    if (token == null) throw ApiException('No hay sesión activa');
    return _authHeaders(token);
  }

  WhatsappBusinessProfile _waPerfilDe(http.Response r) {
    dynamic body;
    try {
      body = jsonDecode(r.body);
    } catch (_) {}
    if (r.statusCode == 200 && body is Map && body['success'] == true) {
      return WhatsappBusinessProfile.fromJson(body['data'] as Map<String, dynamic>);
    }
    var mensaje = 'No se pudo completar la acción.';
    if (body is Map) {
      final errores = body['errors'];
      if (errores is Map && errores.isNotEmpty && errores.values.first is List && (errores.values.first as List).isNotEmpty) {
        mensaje = (errores.values.first as List).first.toString();
      } else if (body['message'] != null) {
        mensaje = body['message'].toString();
      }
    }
    throw ApiException(mensaje, statusCode: r.statusCode);
  }

  /// GET /mobile/whatsapp-profile
  Future<WhatsappBusinessProfile> getWhatsappProfile() async {
    final server = await _cacheService.getServerUrl();
    if (server == null) throw ApiException('No hay sesión activa');
    final headers = await _waHeaders();
    final http.Response r;
    try {
      r = await http.get(Uri.parse('$server/api/mobile/whatsapp-profile'), headers: headers).timeout(const Duration(seconds: 40));
    } catch (_) {
      throw ApiException('No se pudo conectar. Revisa tu conexión.');
    }
    if (r.statusCode == 401) await _handleUnauthorized();
    return _waPerfilDe(r);
  }

  /// PUT /mobile/whatsapp-profile — devuelve el perfil ya actualizado
  Future<WhatsappBusinessProfile> updateWhatsappProfile(Map<String, dynamic> datos) async {
    final server = await _cacheService.getServerUrl();
    if (server == null) throw ApiException('No hay sesión activa');
    final headers = await _waHeaders();
    final http.Response r;
    try {
      r = await http
          .put(Uri.parse('$server/api/mobile/whatsapp-profile'), headers: headers, body: jsonEncode(datos))
          .timeout(const Duration(seconds: 60));
    } catch (_) {
      throw ApiException('No se pudo conectar. Revisa tu conexión.');
    }
    if (r.statusCode == 401) await _handleUnauthorized();
    return _waPerfilDe(r);
  }

  /// POST /mobile/whatsapp-profile/photo — devuelve el mensaje del servidor
  Future<String> uploadWhatsappPhoto(File foto) async {
    final server = await _cacheService.getServerUrl();
    final token = await _cacheService.getDeviceToken();
    if (server == null || token == null) throw ApiException('No hay sesión activa');
    final request = http.MultipartRequest('POST', Uri.parse('$server/api/mobile/whatsapp-profile/photo'))
      ..headers.addAll({'Authorization': 'Bearer $token', 'Accept': 'application/json'})
      ..files.add(await http.MultipartFile.fromPath('foto', foto.path));
    final http.Response r;
    try {
      final streamed = await request.send().timeout(const Duration(minutes: 1));
      r = await http.Response.fromStream(streamed);
    } catch (_) {
      throw ApiException('No se pudo subir la foto. Revisa tu conexión.');
    }
    dynamic body;
    try {
      body = jsonDecode(r.body);
    } catch (_) {}
    if (r.statusCode == 200 && body is Map && body['success'] == true) {
      return body['message']?.toString() ?? 'Foto enviada.';
    }
    var mensaje = 'No se pudo subir la foto.';
    if (body is Map) {
      final errores = body['errors'];
      if (errores is Map && errores.isNotEmpty && errores.values.first is List && (errores.values.first as List).isNotEmpty) {
        mensaje = (errores.values.first as List).first.toString();
      } else if (body['message'] != null) {
        mensaje = body['message'].toString();
      }
    }
    throw ApiException(mensaje, statusCode: r.statusCode);
  }

  // ───── Resumen de Inicio ─────
  /// GET /mobile/summary
  Future<Map<String, int>> getResumen() async {
    final headers = await _waHeaders();
    final http.Response r;
    try {
      r = await http.get(await _uriMovil('summary'), headers: headers).timeout(const Duration(seconds: 30));
    } catch (_) {
      throw ApiException('No se pudo conectar. Revisa tu conexión.');
    }
    if (r.statusCode == 401) await _handleUnauthorized();
    final body = r.statusCode == 200 ? jsonDecode(r.body) : null;
    if (body is Map && body['success'] == true) {
      final d = body['data'] as Map;
      return {for (final e in d.entries) e.key.toString(): int.tryParse('${e.value}') ?? 0};
    }
    throw ApiException('No se pudo cargar el resumen.', statusCode: r.statusCode);
  }

  // ───── Alertas (las mismas notificaciones de la web) ─────
  Future<Uri> _uriMovil(String ruta) async {
    final server = await _cacheService.getServerUrl();
    if (server == null) throw ApiException('No hay sesión activa');
    return Uri.parse('$server/api/mobile/$ruta');
  }

  /// id del canal de tiempo real de alertas (lo devuelve el servidor al listar)
  static int? usuarioIdNotif;

  Future<List<AppNotification>> getNotifications() async {
    final headers = await _waHeaders();
    final http.Response r;
    try {
      r = await http.get(await _uriMovil('notifications'), headers: headers).timeout(const Duration(seconds: 30));
    } catch (_) {
      throw ApiException('No se pudo conectar. Revisa tu conexión.');
    }
    if (r.statusCode == 401) await _handleUnauthorized();
    final body = r.statusCode == 200 ? jsonDecode(r.body) : null;
    if (body is Map && body['success'] == true) {
      usuarioIdNotif = int.tryParse('${body['data']['usuario_id']}') ?? usuarioIdNotif;
      final items = (body['data']['items'] as List).cast<Map<String, dynamic>>();
      return items.map(AppNotification.fromJson).toList();
    }
    throw ApiException('No se pudieron cargar las alertas.', statusCode: r.statusCode);
  }

  /// id == null marca todas
  Future<void> markNotificationsRead([String? id]) async {
    final headers = await _waHeaders();
    final uri = await _uriMovil(id == null ? 'notifications/read-all' : 'notifications/$id/read');
    try {
      final r = await http.post(uri, headers: headers).timeout(const Duration(seconds: 30));
      if (r.statusCode == 401) await _handleUnauthorized();
      if (r.statusCode != 200) throw ApiException('No se pudo marcar como leída.', statusCode: r.statusCode);
    } on ApiException {
      rethrow;
    } catch (_) {
      throw ApiException('No se pudo conectar. Revisa tu conexión.');
    }
  }

  Map<String, String> _authHeaders(String token) {
    return {
      'Authorization': 'Bearer $token',
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };
  }

  /// GET /chats/{numero} - Obtiene mensajes y datos del contacto
  /// Devuelve un Map con la clave 'messages' (Lista) y 'contacto' (Map)
  Future<Map<String, dynamic>> getChatMessages(
    String numero, {
    int limit = 50,
    String? beforeId,
  }) async {
    final server = await _cacheService.getServerUrl();
    final token = await _cacheService.getDeviceToken();

    if (server == null || token == null) throw Exception('No hay sesión activa');

    // Construir query params
    String queryParams = 'limit=$limit';
    if (beforeId != null) queryParams += '&before_id=$beforeId';

    final url = Uri.parse('$server/api/mobile/chats/$numero?$queryParams');
    debugPrint('💬 Consultando mensajes de $numero');

    final response = await http.get(url, headers: _authHeaders(token));
    debugPrint('📦 STATUS: ${response.statusCode}');
    debugPrint('📦 LEN: ${response.body.length}');
    debugPrint('📦 BYTES INICIO: ${response.bodyBytes.take(10).toList()}');

    if (response.statusCode == 200) {
      if (response.body.trim().isEmpty) {
        throw Exception('El servidor devolvió una respuesta vacía');
      }
      final body = jsonDecode(response.body);
      if (body['success'] == true) {
        // Tu controlador devuelve 'data' (mensajes) y 'contacto' por separado
        return {
          'messages': ((body['data'] ?? []) as List).map((m) => _conUrlAbsoluta(m, server)).toList(),
          'contacto': body['contacto'],
        };
      }
      throw Exception(body['message'] ?? 'Error al obtener mensajes');
    } else {
      debugPrint('❌ ERROR ${response.statusCode} al cargar mensajes: ${response.body}');
      throw Exception('Error de conexión: ${response.statusCode}');
    }
  }

  /// POST /chats/{numero}/messages - Enviar mensaje de texto
  Future<Message> sendMessage(String numero, String mensaje) async {
    final server = await _cacheService.getServerUrl();
    final token = await _cacheService.getDeviceToken();

    if (server == null || token == null) throw ApiException('No hay sesión activa');

    final url = Uri.parse('$server/api/mobile/chats/$numero/messages');
    debugPrint('📤 Enviando mensaje a $numero');

    final http.Response response;
    try {
      response = await http
          .post(url, headers: _authHeaders(token), body: jsonEncode({'mensaje': mensaje}))
          .timeout(const Duration(seconds: 30));
    } catch (_) {
      throw ApiException('Sin conexión con el servidor. Revisa tu internet.');
    }

    if (response.statusCode == 401) await _handleUnauthorized();

    if (response.statusCode == 200 || response.statusCode == 201) {
      final body = jsonDecode(response.body);
      if (body['success'] == true) {
        return Message.fromJson(body['data']);
      }
      throw ApiException(body['message']?.toString() ?? 'Error al enviar mensaje');
    }

    debugPrint('❌ ERROR ${response.statusCode} al enviar: ${response.body}');
    throw _errorFrom(response, 'No se pudo enviar el mensaje.');
  }

  /// POST /chats/{numero}/media - Enviar imagen, video, audio o documento (multipart)
  Future<Message> sendMedia(String numero, File file, {String? caption}) async {
    final server = await _cacheService.getServerUrl();
    final token = await _cacheService.getDeviceToken();

    if (server == null || token == null) throw ApiException('No hay sesión activa');

    final request = http.MultipartRequest('POST', Uri.parse('$server/api/mobile/chats/$numero/media'))
      ..headers.addAll({'Authorization': 'Bearer $token', 'Accept': 'application/json'})
      ..files.add(await http.MultipartFile.fromPath('archivo', file.path));
    if (caption != null && caption.trim().isNotEmpty) {
      request.fields['caption'] = caption.trim();
    }

    final http.Response response;
    try {
      final streamed = await request.send().timeout(const Duration(minutes: 3));
      response = await http.Response.fromStream(streamed);
    } catch (_) {
      throw ApiException('No se pudo subir el archivo. Revisa tu conexión.');
    }

    if (response.statusCode == 401) await _handleUnauthorized();

    if (response.statusCode == 200 || response.statusCode == 201) {
      final body = jsonDecode(response.body);
      if (body['success'] == true) {
        return Message.fromJson(_conUrlAbsoluta(body['data'], server));
      }
      throw ApiException(body['message']?.toString() ?? 'Error al enviar el archivo');
    }

    debugPrint('❌ ERROR ${response.statusCode} al enviar archivo: ${response.body}');
    throw _errorFrom(response, 'No se pudo enviar el archivo.');
  }

  /// POST /chats/{numero}/read - Marcar mensajes como leídos
  Future<bool> markAsRead(String numero) async {
    final server = await _cacheService.getServerUrl();
    final token = await _cacheService.getDeviceToken();

    if (server == null || token == null) throw Exception('No hay sesión activa');

    final url = Uri.parse('$server/api/mobile/chats/$numero/read');

    // Se llama sin esperar respuesta: nunca debe lanzar excepciones. Si la conexión se cae, reintenta una vez.
    for (var intento = 0; intento < 2; intento++) {
      try {
        final response = await http.post(url, headers: _authHeaders(token)).timeout(const Duration(seconds: 15));
        if (response.statusCode == 200) {
          final body = jsonDecode(response.body);
          return body['success'] == true;
        }
        return false;
      } catch (e) {
        debugPrint('⚠️ markAsRead intento ${intento + 1} falló: $e');
        if (intento == 0) await Future.delayed(const Duration(seconds: 2));
      }
    }
    return false;
  }
}