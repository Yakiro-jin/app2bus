import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/device_info.dart';

/// Clase encargada de comunicar la app con el backend.
/// Se usa para enviar posiciones y reportes de incidencias.
class ApiService {
  /// URL base del backend.
  final String endpoint;

  ApiService({required this.endpoint});

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
            headers: {'Content-Type': 'application/json'},
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
