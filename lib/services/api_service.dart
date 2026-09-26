import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/device_info.dart';

/// Clase encargada de comunicar la app con el backend.
/// Se usa para enviar posiciones, reportes de incidencias, y consultar viajes/usuarios.
class ApiService {
  /// URL base del backend.
  final String endpoint;

  /// Token JWT opcional para autenticación en las peticiones.
  String? token;

  ApiService({required this.endpoint, this.token});

  /// Genera los headers estándar para las peticiones HTTP.
  /// Incluye el token JWT si está disponible.
  Map<String, String> _buildHeaders() {
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
    if (token != null && token!.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  /// Envía la ubicación actual al endpoint PATCH del viaje.
  /// Devuelve un mapa con la respuesta HTTP y la URL usada.
  Future<Map<String, dynamic>?> sendLocation(
    DeviceInfo device,
    double latitude,
    double longitude, {
    String id = '10',
  }) async {
    // Construye la ruta con el identificador del viaje.
    final url =
        '${endpoint.replaceAll(RegExp(r'/$'), '')}/viajes/Actualizar-viaje/$id';
    final uri = Uri.parse(url);

    // Cuerpo del mensaje que se envía como JSON.
    final bodyData = {
      'latitud': latitude,
      'lactitud': latitude,
      'longitud': longitude,
    };

    debugPrint('ApiService: PATCH $url');
    debugPrint('ApiService: Body: ${json.encode(bodyData)}');

    try {
      final resp = await http
          .patch(
            uri,
            headers: _buildHeaders(),
            body: json.encode(bodyData),
          )
          .timeout(const Duration(seconds: 15));
      debugPrint('ApiService: Response status: ${resp.statusCode}');
      debugPrint('ApiService: Response body: ${resp.body}');
      return {'response': resp, 'url': url};
    } catch (e) {
      debugPrint('ApiService: Error sending location: $e');
      return {'response': null, 'url': url};
    }
  }

  /// Obtiene la lista de todos los viajes disponibles.
  /// Devuelve una lista de mapas con los datos básicos de cada viaje.
  Future<List<Map<String, dynamic>>> getAllViajes() async {
    final url =
        '${endpoint.replaceAll(RegExp(r'/$'), '')}/viajes/Obtener-Viaje';
    final uri = Uri.parse(url);

    debugPrint('ApiService: GET $url');

    try {
      final resp = await http
          .get(uri, headers: _buildHeaders())
          .timeout(const Duration(seconds: 15));
      debugPrint('ApiService: getAllViajes status: ${resp.statusCode}');

      if (resp.statusCode == 200) {
        final data = json.decode(resp.body);
        // La respuesta puede ser una lista directa o estar dentro de un campo.
        if (data is List) {
          return List<Map<String, dynamic>>.from(data);
        } else if (data is Map && data.containsKey('control')) {
          return List<Map<String, dynamic>>.from(data['control']);
        } else if (data is Map) {
          // Busca cualquier campo que sea una lista.
          for (final value in data.values) {
            if (value is List) {
              return List<Map<String, dynamic>>.from(value);
            }
          }
        }
      }
    } catch (e) {
      debugPrint('ApiService: Error getting viajes: $e');
    }
    return [];
  }

  /// Obtiene los detalles completos de un viaje específico por su ID.
  /// Incluye el username del chofer asignado para poder hacer match.
  Future<Map<String, dynamic>?> getViajeById(int id) async {
    final url =
        '${endpoint.replaceAll(RegExp(r'/$'), '')}/viajes/Obtener-viaje-Id/$id';
    final uri = Uri.parse(url);

    debugPrint('ApiService: GET $url');

    try {
      final resp = await http
          .get(uri, headers: _buildHeaders())
          .timeout(const Duration(seconds: 15));
      debugPrint('ApiService: getViajeById($id) status: ${resp.statusCode}');

      if (resp.statusCode == 200) {
        final data = json.decode(resp.body);
        if (data is Map && data.containsKey('control')) {
          return Map<String, dynamic>.from(data['control']);
        }
        return Map<String, dynamic>.from(data);
      }
    } catch (e) {
      debugPrint('ApiService: Error getting viaje $id: $e');
    }
    return null;
  }

  /// Obtiene la información de un usuario a partir de su username.
  /// Sirve para verificar el rol del usuario (ej. "Chofer").
  Future<Map<String, dynamic>?> getUserByUsername(String username) async {
    final url =
        '${endpoint.replaceAll(RegExp(r'/$'), '')}/usuarios/Obtener-usuario-username/$username';
    final uri = Uri.parse(url);

    debugPrint('ApiService: GET $url');

    try {
      final resp = await http
          .get(uri, headers: _buildHeaders())
          .timeout(const Duration(seconds: 15));
      debugPrint(
          'ApiService: getUserByUsername($username) status: ${resp.statusCode}');

      if (resp.statusCode == 200) {
        final data = json.decode(resp.body);
        if (data is Map && data.containsKey('control')) {
          return Map<String, dynamic>.from(data['control']);
        }
        return Map<String, dynamic>.from(data);
      }
    } catch (e) {
      debugPrint('ApiService: Error getting user $username: $e');
    }
    return null;
  }

  /// Busca el viaje asignado al usuario actual.
  /// Recorre todos los viajes y consulta cada uno por ID hasta encontrar
  /// uno cuyo campo usuario.username coincida con el username dado.
  /// Devuelve el ID del viaje encontrado, o null si no hay coincidencia.
  Future<int?> findViajeIdForUser(String username) async {
    final viajes = await getAllViajes();

    for (final viaje in viajes) {
      final idViaje = viaje['id_viaje'];
      if (idViaje == null) continue;

      // Consulta el viaje individual para obtener el detalle con el usuario.
      final detalle = await getViajeById(idViaje);
      if (detalle == null) continue;

      // Compara el username del chofer asignado al viaje con el usuario actual.
      final usuario = detalle['usuario'];
      if (usuario != null && usuario is Map) {
        final viajeUsername = usuario['username']?.toString().toLowerCase();
        if (viajeUsername == username.toLowerCase()) {
          debugPrint(
              'ApiService: Viaje encontrado para $username: id_viaje=$idViaje');
          return idViaje;
        }
      }
    }

    debugPrint('ApiService: No se encontró viaje para $username');
    return null;
  }

  /// Envía un reporte de incidencia junto con la posición actual.
  Future<bool> sendIncidence(
    DeviceInfo device,
    double latitude,
    double longitude,
    String incidence,
  ) async {
    final uri = Uri.parse(endpoint);

    // Se construye la URL con parámetros de consulta para enviar la información.
    final params = {
      ...device.toJson(),
      'latitude': latitude.toString(),
      'longitude': longitude.toString(),
      'timestamp': DateTime.now().toIso8601String(),
      'incidence': incidence,
    };

    final uriWithQuery = uri.replace(
      queryParameters: params.map((k, v) => MapEntry(k, v.toString())),
    );

    debugPrint('ApiService: Sending Incidence: ${uriWithQuery.toString()}');

    try {
      final resp = await http
          .get(uriWithQuery)
          .timeout(const Duration(seconds: 15));
      return resp.statusCode == 200 || resp.statusCode == 201;
    } catch (e) {
      debugPrint('ApiService: Error sending incidence: $e');
      return false;
    }
  }
}

