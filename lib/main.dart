import 'package:flutter/material.dart';
import 'pages/login_page.dart';
import 'pages/home_page.dart';
import 'services/auth_service.dart';

/// Punto de entrada principal de la aplicación.
/// Aquí se inicializa Flutter y se carga la pantalla inicial del proyecto.
void main() async {
  // Asegura que los bindings de Flutter estén listos antes de ejecutar la app.
  WidgetsFlutterBinding.ensureInitialized();

  // Verifica si hay una sesión activa para decidir la pantalla inicial.
  final isLoggedIn = await AuthService.isLoggedIn();

  // Inicia la aplicación con el widget principal.
  runApp(MainApp(isLoggedIn: isLoggedIn));
}

/// Widget raíz de la aplicación.
/// Define el tema visual, el título y la pantalla inicial.
class MainApp extends StatelessWidget {
  /// Indica si el usuario ya tiene una sesión activa.
  final bool isLoggedIn;

  const MainApp({super.key, required this.isLoggedIn});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'App2Bus',
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: const Color(0xFF2D62FF),
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2D62FF),
          brightness: Brightness.dark,
          secondary: const Color(0xFF00D2FF),
        ),
        useMaterial3: true,
        textTheme: const TextTheme(
          headlineMedium: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      ),
      // Si hay sesión activa va directo al home, si no muestra el login.
      home: isLoggedIn ? const HomePage() : const LoginPage(),
    );
  }
}

