import 'dart:async';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
// import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';
import '../models/device_info.dart';

Future<void> initializeService() async {
  final service = FlutterBackgroundService();

  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'app2bus_foreground',
    'App2Bus Foreground Service',
    description: 'This channel is used for important notifications.',
    importance: Importance.low,
  );

  try {
    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
        FlutterLocalNotificationsPlugin();

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );

    await flutterLocalNotificationsPlugin.initialize(initializationSettings);

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  } catch (e) {
    debugPrint("Error initializing notifications: $e");
  }

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: false,
      isForegroundMode: true,
      notificationChannelId: 'app2bus_foreground',
      initialNotificationTitle: 'Conexión iniciada',
      initialNotificationContent: 'Enviando ubicación en segundo plano',
      foregroundServiceNotificationId: 888,
    ),
    iosConfiguration: IosConfiguration(
      autoStart: false,
      onForeground: onStart,
      onBackground: onIosBackground,
    ),
  );
}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  return true;
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // Inicialización necesaria para el proceso de segundo plano
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  await flutterLocalNotificationsPlugin.initialize(
    const InitializationSettings(android: initializationSettingsAndroid),
  );

  final ApiService apiService = ApiService(
    endpoint:
        'https://margaritavillage-n8n.eteqzh.easypanel.host/webhook/eba29058-3ba3-498d-9c70-dd5b7817b432',
  );
  const DeviceInfo device = DeviceInfo(
    id: 'vehiculo-123',
    name: 'Conductor 1',
  );

  StreamSubscription<Position>? positionStream;

  if (service is AndroidServiceInstance) {
    service.on('setAsForeground').listen((event) {
      service.setAsForegroundService();
    });

    service.on('setAsBackground').listen((event) {
      service.setAsBackgroundService();
    });
  }

  service.on('stopService').listen((event) {
    positionStream?.cancel();
    service.stopSelf();
  });

  // Start tracking
  positionStream = Geolocator.getPositionStream(
    locationSettings: const LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 5,
    ),
  ).listen((Position position) async {
    final _ = await apiService.sendLocation(
      device,
      position.latitude,
      position.longitude,
    );

    // Update notification if on Android
    if (service is AndroidServiceInstance) {
      if (await service.isForegroundService()) {
        flutterLocalNotificationsPlugin.show(
          888,
          'Ruta Iniciada',
          'Última actualización: ${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}',
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'app2bus_foreground',
              'App2Bus Foreground Service',
              ongoing: true,
            ),
          ),
        );
      }
    }

    // Send data to foreground
    service.invoke('update', {
      "latitude": position.latitude,
      "longitude": position.longitude,
      "timestamp": DateTime.now().toIso8601String(),
      "last_response": "API OK (${DateTime.now().second}s)", // Simulado para el test
    });
  });
}
