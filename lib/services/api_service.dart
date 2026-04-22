// import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/device_info.dart';

class ApiService {
  final String endpoint;

  ApiService({required this.endpoint});

  /// Sends location data as GET query parameters to [endpoint].
  /// Returns a map with keys `response` (http.Response?) and `url` (String).
  Future<Map<String, dynamic>?> sendLocation(
    DeviceInfo device,
    double latitude,
    double longitude,
  ) async {
    final uri = Uri.parse(endpoint);

    final params = {
      ...device.toJson(),
      'latitude': latitude.toString(),
      'longitude': longitude.toString(),
      'timestamp': DateTime.now().toIso8601String(),
    };

    final uriWithQuery = uri.replace(
      queryParameters: params.map((k, v) => MapEntry(k, v.toString())),
    );
    final url = uriWithQuery.toString();

    print('ApiService: GET $url');

    try {
      final resp = await http
          .get(uriWithQuery)
          .timeout(const Duration(seconds: 15));
      print('ApiService: Response status: ${resp.statusCode}');
      print('ApiService: Response body: ${resp.body}');
      return {'response': resp, 'url': url};
    } catch (e) {
      print('ApiService: Error sending location: $e');
      return {'response': null, 'url': url};
    }
  }
}
