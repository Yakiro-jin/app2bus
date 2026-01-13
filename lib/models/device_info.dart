class DeviceInfo {
  final String id;
  final String name;

  const DeviceInfo({required this.id, required this.name});

  Map<String, dynamic> toJson() => {'id': id, 'name': name};
}
