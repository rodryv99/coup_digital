import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import 'auth_service.dart';

class AdminService {
  final AuthService _auth = AuthService();

  Future<Map<String, String>> _headers() async {
    final token = await _auth.getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

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

  Future<Map<String, dynamic>> listUsers({int page = 1, String? search}) async {
    final query = StringBuffer('?page=$page&limit=20');
    if (search != null && search.isNotEmpty) query.write('&search=$search');
    final res = await _request(() async => http.get(
      Uri.parse('${ApiConfig.baseUrl}/users$query'),
      headers: await _headers(),
    ));
    if (res.statusCode != 200) {
      throw Exception('Error al cargar usuarios');
    }
    return jsonDecode(res.body);
  }

  Future<void> updateUser(String id, {String? role, String? status}) async {
    final body = <String, dynamic>{};
    if (role != null) body['role'] = role;
    if (status != null) body['status'] = status;
    final res = await _request(() async => http.patch(
      Uri.parse('${ApiConfig.baseUrl}/users/$id'),
      headers: await _headers(),
      body: jsonEncode(body),
    ));
    if (res.statusCode != 200) {
      throw Exception('Error al actualizar usuario');
    }
  }

  Future<void> deleteUser(String id) async {
    final res = await _request(() async => http.delete(
      Uri.parse('${ApiConfig.baseUrl}/users/$id'),
      headers: await _headers(),
    ));
    if (res.statusCode != 200) {
      throw Exception('Error al eliminar usuario');
    }
  }
}