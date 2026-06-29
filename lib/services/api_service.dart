import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/device_info.dart';

class ApiService {
  final String endpoint;

  ApiService({required this.endpoint});

  /// Sends location data as PATCH JSON to [endpoint]/viajes/Actualizar-viaje/:id.
  /// Returns a map with keys `response` (http.Response?) and `url` (String).
  Future<Map<String, dynamic>?> sendLocation(
    DeviceInfo device,
    double latitude,
    double longitude, {
    String id = '10',
  }) async {
    // Construct the endpoint path: e.g. base_url/viajes/Actualizar-viaje/10
    final url =
        '${endpoint.replaceAll(RegExp(r'/$'), '')}/viajes/Actualizar-viaje/$id';
    final uri = Uri.parse(url);

    final bodyData = {
      'latitud': latitude,
      'lactitud': latitude,
      'longitud': longitude,
    };

    print('ApiService: PATCH $url');
    print('ApiService: Body: ${json.encode(bodyData)}');

    try {
      final resp = await http
          .patch(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: json.encode(bodyData),
          )
          .timeout(const Duration(seconds: 15));
      print('ApiService: Response status: ${resp.statusCode}');
      print('ApiService: Response body: ${resp.body}');
      return {'response': resp, 'url': url};
    } catch (e) {
      print('ApiService: Error sending location: $e');
      return {'response': null, 'url': url};
    }
  }

  /// Sends an incidence report with current location data.
  Future<bool> sendIncidence(
    DeviceInfo device,
    double latitude,
    double longitude,
    String incidence,
  ) async {
    final uri = Uri.parse(endpoint);

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

    print('ApiService: Sending Incidence: ${uriWithQuery.toString()}');

    try {
      final resp = await http
          .get(uriWithQuery)
          .timeout(const Duration(seconds: 15));
      return resp.statusCode == 200 || resp.statusCode == 201;
    } catch (e) {
      print('ApiService: Error sending incidence: $e');
      return false;
    }
  }
}
