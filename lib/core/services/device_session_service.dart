import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class DeviceSession {
  const DeviceSession({required this.token, required this.server});

  final String token;
  final String server;

  Map<String, dynamic> toJson() => {'token': token, 'server': server};

  factory DeviceSession.fromJson(Map<String, dynamic> json) => DeviceSession(
        token: json['token'] as String,
        server: json['server'] as String,
      );
}

class DeviceSessionService {
  static const String _key = 'device_session';

  Future<void> save(DeviceSession session) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(session.toJson()));
  }

  Future<DeviceSession?> get() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return null;
    return DeviceSession.fromJson(jsonDecode(raw));
  }

  Future<bool> hasSession() async => (await get()) != null;

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}