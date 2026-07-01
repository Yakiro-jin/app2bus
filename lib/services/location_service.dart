import 'dart:async';
import 'package:geolocator/geolocator.dart';

/// Servicio de ayuda para gestionar permisos y recibir actualizaciones de ubicación.
class LocationService {
  // Suscripción activa al stream de ubicación.
  StreamSubscription<Position>? _sub;

  /// Verifica si el servicio de ubicación está habilitado y si la app tiene permiso.
  /// Devuelve true si la app puede seguir la ubicación.
  Future<bool> checkPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  /// Inicia el stream de ubicación y delega cada nuevo dato a la función recibida.
  void startStream(void Function(Position) onData) {
    // Se usa la máxima precisión posible para obtener actualizaciones en tiempo real.
    final settings = const LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 0,
    );

    _sub = Geolocator.getPositionStream(
      locationSettings: settings,
    ).listen(onData);
  }

  /// Detiene la suscripción activa al stream de ubicaciones.
  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
  }
}
