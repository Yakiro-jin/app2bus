import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/background_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with SingleTickerProviderStateMixin {
  bool _isRunning = false;
  String _lastUpdate = '--:--:--';
  String _coordinates = '0.000000, 0.000000';
  String _lastApiResponse = 'Esperando inicio...';
  late AnimationController _animationController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await initializeService();
      _checkServiceStatus();
      _listenToService();
    });
  }

  Future<void> _checkServiceStatus() async {
    final service = FlutterBackgroundService();
    final isRunning = await service.isRunning();
    setState(() {
      _isRunning = isRunning;
      if (_isRunning) {
        _animationController.repeat(reverse: true);
      }
    });

    // Recover last known data from SharedPreferences if needed
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _lastUpdate = prefs.getString('last_update') ?? '--:--:--';
      _coordinates = prefs.getString('last_coords') ?? '0.000000, 0.000000';
    });
  }

  void _listenToService() {
    FlutterBackgroundService().on('update').listen((event) async {
      if (event != null) {
        final lat = event['latitude'];
        final lon = event['longitude'];
        final ts = DateTime.parse(event['timestamp']);
        final timeString = DateFormat('HH:mm:ss').format(ts);
        final coordString = '${lat.toStringAsFixed(6)}, ${lon.toStringAsFixed(6)}';

        if (mounted) {
          setState(() {
            _lastUpdate = timeString;
            _coordinates = coordString;
            _lastApiResponse = event['last_response'] ?? 'Sin respuesta';
          });
        }

        // Persist for app restarts
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('last_update', timeString);
        await prefs.setString('last_coords', coordString);
      }
    });
  }

  Future<void> _toggleConnection() async {
    final service = FlutterBackgroundService();
    final isRunning = await service.isRunning();

    if (!isRunning) {
      // Check permissions first
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

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        backgroundColor: _isRunning ? Colors.redAccent : Colors.greenAccent.withAlpha(200),
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
              // TEST AREA
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
              const Spacer(),
              _buildFooter(),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLargeCircularButton() {
    return GestureDetector(
      onTap: _toggleConnection,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer Glow/Pulse
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Container(
                width: 200 * _pulseAnimation.value,
                height: 200 * _pulseAnimation.value,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isRunning
                      ? Colors.blue.withAlpha((40 / _pulseAnimation.value).round())
                      : Colors.transparent,
                ),
              );
            },
          ),
          // Sub-outer ring
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
          // Main Button
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
