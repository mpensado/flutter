import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:lighthouse_map/app.dart';
import 'package:lighthouse_map/firebase_options.dart'; // Este archivo se generará
//import 'app.dart'; // Si creaste un archivo app.dart

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp()); // Asegúrate de que MyApp() sea tu widget raíz
}