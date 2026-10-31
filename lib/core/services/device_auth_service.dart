import 'dart:convert';
import 'package:http/http.dart' as http;

class DeviceAuthService {
  Future<Map<String, dynamic>> linkDevice({
    required String server,
    required String token,
  }) async {
    final url = Uri.parse('$server/api/device/link');

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'token': token}),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }

    throw Exception(
      'No se pudo vincular el dispositivo (${response.statusCode}): ${response.body}',
    );
  }
}