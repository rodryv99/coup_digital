import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';

class AuthService {
  static const _tokenKey = 'access_token';
  static const _refreshKey = 'refresh_token';
  static const _userIdKey = 'user_id';
  static const _usernameKey = 'username';
  static const _roleKey = 'role';

  Future<Map<String, dynamic>> register(
      String username, String email, String password) async {
    final res = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username, 'email': email, 'password': password}),
    );
    final data = jsonDecode(res.body);
    if (res.statusCode != 201 && res.statusCode != 200) {
      throw Exception(data['message'] ?? 'Error al registrar');
    }
    return data;
  }

  Future<void> login(String identifier, String password) async {
    final res = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'identifier': identifier, 'password': password}),
    );
    final data = jsonDecode(res.body);
    if (res.statusCode != 200 && res.statusCode != 201) {
      throw Exception(data['message'] ?? 'Credenciales invalidas');
    }

    final token = data['accessToken'] as String;
    final refreshToken = data['refreshToken'] as String?;
    final payload = _decodeJwt(token);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    if (refreshToken != null) await prefs.setString(_refreshKey, refreshToken);
    await prefs.setString(_userIdKey, payload['sub'] ?? '');
    await prefs.setString(_usernameKey, payload['username'] ?? identifier);
    await prefs.setString(_roleKey, data['role'] ?? payload['role'] ?? 'Free');
  }

  // Intenta refrescar el access token usando el refresh token.
  // El backend espera el refreshToken en el BODY (campo 'refreshToken').
  Future<bool> tryRefresh() async {
    final prefs = await SharedPreferences.getInstance();
    final refreshToken = prefs.getString(_refreshKey);
    if (refreshToken == null || refreshToken.isEmpty) return false;

    try {
      final res = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/auth/refresh'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refreshToken': refreshToken}),
      );
      if (res.statusCode != 200 && res.statusCode != 201) return false;

      final data = jsonDecode(res.body);
      final newToken = data['accessToken'] as String?;
      final newRefresh = data['refreshToken'] as String?;
      if (newToken == null) return false;

      final payload = _decodeJwt(newToken);
      await prefs.setString(_tokenKey, newToken);
      if (newRefresh != null) await prefs.setString(_refreshKey, newRefresh);
      await prefs.setString(_userIdKey, payload['sub'] ?? prefs.getString(_userIdKey) ?? '');
      await prefs.setString(_usernameKey, payload['username'] ?? prefs.getString(_usernameKey) ?? '');
      await prefs.setString(_roleKey, data['role'] ?? payload['role'] ?? prefs.getString(_roleKey) ?? 'Free');
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  Future<String?> getRefreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_refreshKey);
  }

  Future<String?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userIdKey);
  }

  Future<String?> getUsername() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_usernameKey);
  }

  Future<String?> getRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_roleKey);
  }

  Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  Map<String, dynamic> _decodeJwt(String token) {
    final parts = token.split('.');
    if (parts.length != 3) return {};
    final payload = parts[1];
    final normalized = base64.normalize(payload);
    final decoded = utf8.decode(base64.decode(normalized));
    return jsonDecode(decoded);
  }
}