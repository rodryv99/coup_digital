import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import 'auth_service.dart';

class ApiService {
  final AuthService _auth = AuthService();

  Future<Map<String, String>> _headers() async {
    final token = await _auth.getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // Envuelve una peticion. Si devuelve 401, intenta refrescar el token y reintenta una vez.
  Future<http.Response> _request(Future<http.Response> Function() send) async {
    var res = await send();
    if (res.statusCode == 401) {
      final ok = await _auth.tryRefresh();
      if (ok) {
        res = await send();
      }
    }
    return res;
  }

  Future<Map<String, dynamic>> createRoom({
    required String name,
    required int maxPlayers,
    required String reactionMode,
    required int reactionTimeSeconds,
  }) async {
    final res = await _request(() async => http.post(
      Uri.parse('${ApiConfig.baseUrl}/rooms'),
      headers: await _headers(),
      body: jsonEncode({
        'name': name,
        'maxPlayers': maxPlayers,
        'reactionMode': reactionMode,
        'reactionTimeSeconds': reactionTimeSeconds,
      }),
    ));
    final data = jsonDecode(res.body);
    if (res.statusCode != 200 && res.statusCode != 201) {
      throw Exception(data['message'] ?? 'Error al crear mesa');
    }
    return data;
  }

  Future<Map<String, dynamic>> joinRoom(String code) async {
    final res = await _request(() async => http.post(
      Uri.parse('${ApiConfig.baseUrl}/rooms/join'),
      headers: await _headers(),
      body: jsonEncode({'code': code}),
    ));
    final data = jsonDecode(res.body);
    if (res.statusCode != 200 && res.statusCode != 201) {
      throw Exception(data['message'] ?? 'Error al unirse');
    }
    return data;
  }

  Future<Map<String, dynamic>> getMyStats() async {
    final res = await _request(() async => http.get(
      Uri.parse('${ApiConfig.baseUrl}/stats/me'),
      headers: await _headers(),
    ));
    return jsonDecode(res.body);
  }

  Future<Map<String, dynamic>> getMyHistory({int page = 1}) async {
    final res = await _request(() async => http.get(
      Uri.parse('${ApiConfig.baseUrl}/history?page=$page&limit=20'),
      headers: await _headers(),
    ));
    return jsonDecode(res.body);
  }

  Future<Map<String, dynamic>> getHealth() async {
    final res = await http.get(Uri.parse('${ApiConfig.baseUrl}/health'));
    return jsonDecode(res.body);
  }
}