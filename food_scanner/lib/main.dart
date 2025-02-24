import 'package:flutter/material.dart';
import 'package:food_scanner/screens/camera_screen.dart';
import 'package:food_scanner/screens/settings_screen.dart';
import 'package:provider/provider.dart'; // Importa Provider
import 'package:food_scanner/providers/allergy_provider.dart';

void main() {
  runApp(
    MultiProvider( // Usa MultiProvider para varios providers si los necesitas
      providers: [
        ChangeNotifierProvider(create: (context) => AllergyProvider()),
        // Agrega otros providers aquí si los tienes
      ],
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FoodScanner',
      theme: ThemeData(
        primarySwatch: Colors.blue, // Cambia esto a tu tema preferido
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      initialRoute: '/camera', // Ruta inicial a la pantalla de la cámara
      routes: {
        '/camera': (context) => CameraScreen(),
        '/settings': (context) => SettingsScreen(),
      },
    );
  }
}