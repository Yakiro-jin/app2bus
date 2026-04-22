import 'package:flutter/material.dart';
import 'pages/home_page.dart';
import 'services/background_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

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
      home: const HomePage(),
    );
  }
}
