import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/location_service.dart';
import '../services/api_service.dart';
import '../models/device_info.dart';
import 'package:geolocator/geolocator.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final LocationService _locationService = LocationService();
  // Replace with your actual endpoint URL
  final ApiService _apiService = ApiService(
    endpoint:
        'https://margaritavillage-n8n.eteqzh.easypanel.host/webhook/eba29058-3ba3-498d-9c70-dd5b7817b432',
  );
  final DeviceInfo _device = const DeviceInfo(
    id: 'vehiculo-123',
    name: 'Conductor 1',
  );

  bool _running = false;
  String _status = 'Detenido';
  String _lastPayload = '';
  String _lastResponse = '';
  double? _lastLat;
  double? _lastLon;
  DateTime? _lastUpdate;

  void _toggle() async {
    if (!_running) {
      final ok = await _locationService.checkPermission();
      if (!ok) {
        setState(() => _status = 'Permiso denegado o servicio desactivado');
        return;
      }

      _locationService.startStream((Position pos) async {
        final result = await _apiService.sendLocation(
          _device,
          pos.latitude,
          pos.longitude,
        );

        final requestUrl = result != null && result.containsKey('url')
            ? result['url'] as String
            : '';
        final httpResp = result != null && result.containsKey('response')
            ? result['response']
            : null;

        setState(() {
          _status =
              'Enviando: ${pos.latitude.toStringAsFixed(6)}, ${pos.longitude.toStringAsFixed(6)}';
          _lastLat = pos.latitude;
          _lastLon = pos.longitude;
          _lastUpdate = DateTime.now();
          _lastPayload = requestUrl; // for GET show full URL with query
          _lastResponse = httpResp != null
              ? 'HTTP ${httpResp.statusCode}: ${httpResp.body}'
              : 'Error enviando';
        });
      });

      setState(() {
        _running = true;
        _status = 'Conectado';
      });
    } else {
      await _locationService.stop();
      setState(() {
        _running = false;
        _status = 'Detenido';
      });
    }
  }

  @override
  void dispose() {
    _locationService.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('App de Ubicación')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton(
              onPressed: _toggle,
              child: Text(_running ? 'Detener conexión' : 'Iniciar conexión'),
            ),
            const SizedBox(height: 12),
            Text(_status),
            const SizedBox(height: 8),
            Text('Último payload:'),
            Text(_lastPayload, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            if (_lastLat != null && _lastLon != null) ...[
              const SizedBox(height: 8),
              Text('Coordenadas:'),
              Text(
                '${_lastLat!.toStringAsFixed(6)}, ${_lastLon!.toStringAsFixed(6)}',
              ),
            ],
            if (_lastUpdate != null) ...[
              const SizedBox(height: 8),
              Text('Última actualización:'),
              Text('${_lastUpdate.toString()}'),
            ],
            const SizedBox(height: 8),
            Text('Última respuesta:'),
            Text(_lastResponse, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
