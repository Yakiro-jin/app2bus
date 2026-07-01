import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/background_service.dart';
import '../services/api_service.dart';
import '../models/device_info.dart';
import '../config/api_config.dart';

/// Pantalla principal de la app.
/// Muestra el estado de la conexión, permite iniciar o detener la ruta y reportar incidencias.
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

/// Estado de la pantalla principal.
/// Gestiona la animación del botón, el estado del servicio y la actualización visual de datos.
class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  // Indica si el servicio de seguimiento está activo en este momento.
  bool _isRunning = false;

  // Información visual mostrada en la pantalla.
  String _lastUpdate = '--:--:--';
  String _coordinates = '0.000000, 0.000000';
  String _lastApiResponse = 'Esperando inicio...';

  // Controlador y animación para el efecto de pulso del botón grande.
  late AnimationController _animationController;
  late Animation<double> _pulseAnimation;

  // Servicio para enviar datos a la API.
  final ApiService _apiService = ApiService(endpoint: ApiConfig.baseUrl);

  // Datos del vehículo que se usarán en los reportes.
  final DeviceInfo _device = const DeviceInfo(
    id: 'vehiculo-123',
    name: 'Conductor 1',
  );

  @override
  void initState() {
    super.initState();

    // Crea la animación del botón de inicio/detención.
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    // Cuando la pantalla ya está montada, inicializa el servicio y escucha eventos.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await initializeService();
      _checkServiceStatus();
      _listenToService();
    });
  }

  /// Consulta si el servicio de fondo está corriendo y recupera datos guardados antes.
  Future<void> _checkServiceStatus() async {
    final service = FlutterBackgroundService();
    final isRunning = await service.isRunning();
    setState(() {
      _isRunning = isRunning;
      if (_isRunning) {
        _animationController.repeat(reverse: true);
      }
    });

    // Recupera la última actualización y coordenadas guardadas para mostrarlas al abrir la app.
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _lastUpdate = prefs.getString('last_update') ?? '--:--:--';
      _coordinates = prefs.getString('last_coords') ?? '0.000000, 0.000000';
    });
  }

  /// Se suscribe a los eventos enviados desde el servicio en segundo plano.
  void _listenToService() {
    FlutterBackgroundService().on('update').listen((event) async {
      if (event != null) {
        final lat = event['latitude'];
        final lon = event['longitude'];
        final ts = DateTime.parse(event['timestamp']);
        final timeString = DateFormat('HH:mm:ss').format(ts);
        final coordString =
            '${lat.toStringAsFixed(6)}, ${lon.toStringAsFixed(6)}';

        if (mounted) {
          setState(() {
            _lastUpdate = timeString;
            _coordinates = coordString;
            _lastApiResponse = event['last_response'] ?? 'Sin respuesta';
          });
        }

        // Guarda los datos para que persistan aun si la app se reinicia.
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('last_update', timeString);
        await prefs.setString('last_coords', coordString);
      }
    });
  }

  /// Inicia o detiene la conexión según el estado actual del servicio.
  Future<void> _toggleConnection() async {
    final service = FlutterBackgroundService();
    final isRunning = await service.isRunning();

    if (!isRunning) {
      // Verifica permisos de ubicación antes de iniciar la ruta.
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showSnackBar('Permiso de ubicación denegado');
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _showSnackBar('Los permisos están permanentemente denegados');
        return;
      }

      await service.startService();
      _showSnackBar('Ruta iniciada');
      _animationController.repeat(reverse: true);
    } else {
      service.invoke('stopService');
      _showSnackBar('Ruta terminada');
      _animationController.stop();
      _animationController.reset();
    }

    setState(() {
      _isRunning = !isRunning;
    });
  }

  /// Muestra un mensaje temporal en la parte inferior de la pantalla.
  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        backgroundColor: _isRunning
            ? Colors.redAccent
            : Colors.greenAccent.withAlpha(200),
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 40),
              Text(
                'Bienvenido Conductor',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const Spacer(),
              _buildLargeCircularButton(),
              const SizedBox(height: 30),
              // Panel de estado temporal para mostrar la respuesta reciente de la API.
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.blue.withAlpha(20),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: Colors.blue.withAlpha(40)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.sensors, size: 16, color: Colors.blue.shade300),
                    const SizedBox(width: 8),
                    Text(
                      'ESTADO TEST: $_lastApiResponse',
                      style: TextStyle(
                        color: Colors.blue.shade300,
                        fontSize: 12,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _buildIncidenceButton(),
              const Spacer(),
              _buildFooter(),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  /// Botón para abrir el diálogo de reportar una incidencia.
  Widget _buildIncidenceButton() {
    return ElevatedButton.icon(
      onPressed: _showIncidenceDialog,
      icon: const Icon(Icons.report_problem_outlined, size: 18),
      label: const Text('Reportar Incidencia'),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.orangeAccent.withAlpha(200),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        elevation: 5,
      ),
    );
  }

  /// Muestra un cuadro de diálogo para escribir una incidencia.
  void _showIncidenceDialog() {
    final TextEditingController controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text(
          'Reportar Incidencia',
          style: TextStyle(color: Colors.white),
        ),
        content: TextField(
          controller: controller,
          maxLines: 3,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Escribe aquí lo ocurrido...',
            hintStyle: TextStyle(color: Colors.white.withAlpha(100)),
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Colors.white.withAlpha(50)),
            ),
            focusedBorder: const OutlineInputBorder(
              borderSide: BorderSide(color: Colors.orangeAccent),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancelar',
              style: TextStyle(color: Colors.white70),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              final text = controller.text.trim();
              if (text.isNotEmpty) {
                Navigator.pop(context);
                _sendIncidence(text);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orangeAccent,
            ),
            child: const Text('Enviar'),
          ),
        ],
      ),
    );
  }

  /// Envía la incidencia al backend utilizando la posición actual del dispositivo.
  Future<void> _sendIncidence(String message) async {
    // Obtiene la posición actual para adjuntarla al reporte.
    Position? position;
    try {
      position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    } catch (e) {
      debugPrint('Error getting position for incidence: $e');
    }

    // Si falla la obtención, se envía con valores por defecto para no detener el flujo.
    final lat = position?.latitude ?? 0.0;
    final lon = position?.longitude ?? 0.0;

    final success = await _apiService.sendIncidence(_device, lat, lon, message);

    if (success) {
      _showSnackBar('Incidencia enviada correctamente');
    } else {
      _showSnackBar('Error al enviar la incidencia');
    }
  }

  /// Construye el botón grande que inicia o detiene la ruta.
  Widget _buildLargeCircularButton() {
    return GestureDetector(
      onTap: _toggleConnection,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Efecto de pulso alrededor del botón principal.
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Container(
                width: 200 * _pulseAnimation.value,
                height: 200 * _pulseAnimation.value,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isRunning
                      ? Colors.blue.withAlpha(
                          (40 / _pulseAnimation.value).round(),
                        )
                      : Colors.transparent,
                ),
              );
            },
          ),
          // Anillo exterior del botón.
          Container(
            width: 220,
            height: 220,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: _isRunning ? Colors.blue.withAlpha(100) : Colors.white10,
                width: 2,
              ),
            ),
          ),
          // Botón principal con color según el estado.
          Container(
            width: 180,
            height: 180,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: _isRunning
                    ? [const Color(0xFFEF4444), const Color(0xFFB91C1C)]
                    : [const Color(0xFF3B82F6), const Color(0xFF1D4ED8)],
              ),
              boxShadow: [
                BoxShadow(
                  color: (_isRunning ? Colors.red : Colors.blue).withAlpha(100),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _isRunning ? Icons.stop_rounded : Icons.play_arrow_rounded,
                    size: 60,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _isRunning ? 'DETENER' : 'INICIAR',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Construye la barra inferior con la última actualización y coordenadas.
  Widget _buildFooter() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(10),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withAlpha(20)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildInfoItem('Última actualización', _lastUpdate),
            Container(width: 1, height: 40, color: Colors.white24),
            _buildInfoItem('Coordenadas', _coordinates),
          ],
        ),
      ),
    );
  }

  /// Construye un bloque de texto con título y valor para mostrar datos resumidos.
  Widget _buildInfoItem(String title, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: Colors.white.withAlpha(150),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontFamily: 'monospace',
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
