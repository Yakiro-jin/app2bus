/// Modelo simple que representa al vehículo o conductor que reporta la ubicación.
class DeviceInfo {
  /// Identificador único del dispositivo o vehículo.
  final String id;

  /// Nombre visible del conductor o unidad.
  final String name;

  const DeviceInfo({required this.id, required this.name});

  /// Convierte el objeto a un mapa JSON para enviarlo al backend.
  Map<String, dynamic> toJson() => {'id': id, 'name': name};
}
