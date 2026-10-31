import 'dart:convert'; // AGREGAR ESTO
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:gmb/core/models/chat.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/message.dart';

class CacheService {
  static const String _tokenKey = 'device_token';
  static const String _serverKey = 'server_url';
  static const String _tokenExpiryKey = 'token_expiry';
  static const String _profileKey = 'user_profile';

  // --- Token y Server ---
  // El token y el servidor se guardan cifrados (Android Keystore) en vez de SharedPreferences.
  // La sesión no vence localmente: si el servidor la revoca responde 401 y ApiService cierra la sesión.
  static const FlutterSecureStorage _secure = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  /// Pasa a almacenamiento seguro lo que versiones anteriores guardaron en SharedPreferences.
  Future<void> _migrateLegacy() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final oldToken = prefs.getString(_tokenKey);
      final oldServer = prefs.getString(_serverKey);
      if (oldToken != null && await _secure.read(key: _tokenKey) == null) {
        await _secure.write(key: _tokenKey, value: oldToken);
      }
      if (oldServer != null && await _secure.read(key: _serverKey) == null) {
        await _secure.write(key: _serverKey, value: oldServer);
      }
      await prefs.remove(_tokenKey);
      await prefs.remove(_serverKey);
      await prefs.remove(_tokenExpiryKey);
    } catch (e) {
      debugPrint('Error migrando sesión: $e');
    }
  }

  Future<void> saveDeviceToken(String token) async {
    await _secure.write(key: _tokenKey, value: token);
  }

  Future<String?> getDeviceToken() async {
    try {
      await _migrateLegacy();
      return await _secure.read(key: _tokenKey);
    } catch (e) {
      debugPrint('Error leyendo token: $e');
      return null;
    }
  }

  Future<void> saveServerUrl(String serverUrl) async {
    await _secure.write(key: _serverKey, value: serverUrl);
  }

  Future<String?> getServerUrl() async {
    try {
      await _migrateLegacy();
      return await _secure.read(key: _serverKey);
    } catch (e) {
      debugPrint('Error leyendo servidor: $e');
      return null;
    }
  }

  Future<bool> hasDeviceData() async {
    final token = await getDeviceToken();
    final server = await getServerUrl();
    return token != null && server != null;
  }

  Future<void> clearDeviceData() async {
    await _secure.delete(key: _tokenKey);
    await _secure.delete(key: _serverKey);
  }

  // --- Perfil ---

  Future<void> saveProfile(Map<String, dynamic> profileData) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_profileKey, jsonEncode(profileData));
  }

  Future<Map<String, dynamic>?> getProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_profileKey);

    if (jsonString == null) return null;

    try {
      return jsonDecode(jsonString) as Map<String, dynamic>;
    } catch (e) {
      return null;
    }
  }

  Future<void> clearProfile() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_profileKey);
  }

  /// Guardar mensajes en caché por número de teléfono
  Future<void> cacheMessages(String numero, List<Message> messages) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String key = 'chat_messages_$numero';
      // Convertimos la lista de mensajes a un string JSON
      final String jsonString = jsonEncode(
        messages.map((m) => m.toJson()).toList(),
      );
      await prefs.setString(key, jsonString);
    } catch (e) {
      debugPrint('Error guardando caché de mensajes: $e');
    }
  }

  /// Obtener mensajes del caché por número de teléfono
  Future<List<Message>> getCachedMessages(String numero) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String key = 'chat_messages_$numero';
      final String? jsonString = prefs.getString(key);

      if (jsonString == null || jsonString.isEmpty) return [];

      // Convertimos el JSON de vuelta a una lista de objetos Message
      final List<dynamic> jsonList = jsonDecode(jsonString);
      return jsonList.map((json) => Message.fromJson(json)).toList();
    } catch (e) {
      return [];
    }
  }

  /// Guardar lista de chats
  Future<void> cacheChats(List<Chat> chats) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String jsonString = jsonEncode(
        chats.map((c) => c.toJson()).toList(),
      );
      await prefs.setString('cached_chats_list', jsonString);
    } catch (e) {
      debugPrint('Error guardando caché de chats: $e');
    }
  }

  /// Obtener lista de chats
  Future<List<Chat>> getCachedChats() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? jsonString = prefs.getString('cached_chats_list');

      if (jsonString == null || jsonString.isEmpty) return [];

      final List<dynamic> jsonList = jsonDecode(jsonString);
      return jsonList.map((json) => Chat.fromCachedJson(json)).toList();
    } catch (e) {
      return [];
    }
  }
}