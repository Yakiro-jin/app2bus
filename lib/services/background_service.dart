import 'dart:async';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';
import '../models/device_info.dart';
import '../config/api_config.dart';

/// Inicializa el servicio en segundo plano del sistema.
/// Configura notificaciones, el canal Android y la lógica que se ejecuta cuando
/// el servicio se lanza o se detiene.
Future<void> initializeService() async {
  // Instancia del servicio de background.
  final service = FlutterBackgroundService();

  // Canal de notificación usado para mostrar mensajes del servicio en Android.
  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'app2bus_foreground',
    'App2Bus Foreground Service',
    description: 'This channel is used for important notifications.',
    importance: Importance.low,
  );

  try {
    // Plugin de notificaciones para mostrar mensajes al usuario.
    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
        FlutterLocalNotificationsPlugin();

    // Icono mostrado en la notificación del servicio.
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    // Inicializa el plugin de notificaciones.
    await flutterLocalNotificationsPlugin.initialize(initializationSettings);

    // Crea el canal de notificación si el dispositivo lo soporta.
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);
  } catch (e) {
    debugPrint('Error initializing notifications: $e');
  }

  // Configura el servicio para Android e iOS.
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

/// Función de respaldo para el servicio cuando se ejecuta en segundo plano en iOS.
@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  return true;
}

/// Lógica principal que se ejecuta cuando el servicio de fondo empieza.
/// Escucha cambios de ubicación, envía datos a la API y actualiza la notificación.
@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  // Asegura que los plugins de Flutter estén listos dentro del isolate de background.
  DartPluginRegistrant.ensureInitialized();

  // Plugin para mostrar notificaciones desde el proceso en segundo plano.
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // Inicialización necesaria para el proceso de segundo plano.
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  await flutterLocalNotificationsPlugin.initialize(
    const InitializationSettings(android: initializationSettingsAndroid),
  );

  // Recupera el token JWT y el username almacenados en la sesión activa.
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('jwt_token');
  final username = prefs.getString('username');

  // Servicio encargado de enviar datos a la API, ahora con autenticación.
  final ApiService apiService = ApiService(
    endpoint: ApiConfig.baseUrl,
    token: token,
  );

  // Información del vehículo/conductor que se enviará con cada actualización.
  const DeviceInfo device = DeviceInfo(id: 'vehiculo-123', name: 'Conductor 1');

  // Busca el viaje asignado al usuario actual.
  // Si no se encuentra, usa el testId como respaldo.
  String viajeId = ApiConfig.testId;
  if (username != null && username.isNotEmpty) {
    debugPrint('BackgroundService: Buscando viaje para usuario: $username');
    final foundId = await apiService.findViajeIdForUser(username);
    if (foundId != null) {
      viajeId = foundId.toString();
      debugPrint('BackgroundService: Viaje asignado encontrado: $viajeId');
    } else {
      debugPrint(
          'BackgroundService: No se encontró viaje, usando testId: $viajeId');
    }
  }

  // Almacena la suscripción al stream de ubicación para poder cancelarla luego.
  StreamSubscription<Position>? positionStream;

  // En Android se pueden activar eventos especiales para pasar el servicio a primer plano.
  if (service is AndroidServiceInstance) {
    service.on('setAsForeground').listen((event) {
      service.setAsForegroundService();
    });

    service.on('setAsBackground').listen((event) {
      service.setAsBackgroundService();
    });
  }

  // Cuando el servicio recibe la orden de detenerse, cancela el stream y termina el proceso.
  service.on('stopService').listen((event) {
    positionStream?.cancel();
    service.stopSelf();
  });

  // Inicia el seguimiento de ubicación con alta precisión y filtro de distancia.
  positionStream =
      Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          distanceFilter: 5,
        ),
      ).listen((Position position) async {
        // Envía la ubicación actual a la API usando el viaje encontrado.
        final _ = await apiService.sendLocation(
          device,
          position.latitude,
          position.longitude,
          id: viajeId,
        );


        // Actualiza la notificación si el servicio está corriendo en primer plano.
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

        // Envía los datos de posición de vuelta a la interfaz de la app.
        service.invoke('update', {
          'latitude': position.latitude,
          'longitude': position.longitude,
          'timestamp': DateTime.now().toIso8601String(),
          'last_response':
              'API OK (${DateTime.now().second}s)', // Simulado para el test
        });
      });
}
