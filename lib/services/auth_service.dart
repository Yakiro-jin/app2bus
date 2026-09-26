import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';

/// Servicio encargado de la autenticación del usuario.
/// Maneja el login, almacenamiento del token JWT y gestión de la sesión.
class AuthService {
  // Claves usadas para almacenar datos en SharedPreferences.
  static const String _tokenKey = 'jwt_token';
  static const String _usernameKey = 'username';

  /// Realiza el login contra el backend.
  /// Envía username y password, y guarda el token JWT si la respuesta es exitosa.
  /// Devuelve un mapa con 'success' (bool) y 'message' (String).
  static Future<Map<String, dynamic>> login(
    String username,
    String password,
  ) async {
    final url =
        '${ApiConfig.baseUrl.replaceAll(RegExp(r'/$'), '')}/auth/login';
    final uri = Uri.parse(url);

    final bodyData = {
      'username': username,
      'password': password,
    };

    debugPrint('AuthService: POST $url');

    try {
      final resp = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: json.encode(bodyData),
          )
          .timeout(const Duration(seconds: 15));

      debugPrint('AuthService: Response status: ${resp.statusCode}');
      debugPrint('AuthService: Response body: ${resp.body}');

      if (resp.statusCode == 200 || resp.statusCode == 201) {
        final data = json.decode(resp.body);
        final token = data['control']?['token'];
        final user = data['control']?['user'];

        if (token != null) {
          // Guarda el token y el username en almacenamiento local.
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_tokenKey, token);
          await prefs.setString(_usernameKey, user ?? username);

          return {
            'success': true,
            'message': data['message'] ?? 'Login exitoso',
          };
        } else {
          return {
            'success': false,
            'message': 'No se recibió el token de autenticación',
          };
        }
      } else {
        // Intenta extraer un mensaje de error del cuerpo de la respuesta.
        String errorMsg = 'Error en el inicio de sesión';
        try {
          final data = json.decode(resp.body);
          errorMsg = data['message'] ?? errorMsg;
        } catch (_) {}

        return {
          'success': false,
          'message': errorMsg,
        };
      }
    } catch (e) {
      debugPrint('AuthService: Error en login: $e');
      return {
        'success': false,
        'message': 'Error de conexión: no se pudo contactar al servidor',
      };
    }
  }

  /// Devuelve el token JWT almacenado, o null si no hay sesión activa.
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  /// Devuelve el username del usuario con sesión activa, o null si no hay sesión.
  static Future<String?> getUsername() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_usernameKey);
  }

  /// Verifica si hay una sesión activa (token almacenado).
  static Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  /// Cierra la sesión eliminando el token y username almacenados.
  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_usernameKey);
  }
}
