import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:lighthouse_map/app.dart';
import 'package:lighthouse_map/firebase_options.dart';
import 'package:lighthouse_map/services/background_service_handler.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeService();
  
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const AppState()); // Asegúrate de que MyApp() sea tu widget raíz
}

Future<void> initializeService() async {
  final service = FlutterBackgroundService();
  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      isForegroundMode: true,
      autoStart: false,
      notificationChannelId: 'lighthouse_map_service',
      initialNotificationTitle: 'Lighthouse Map',
      initialNotificationContent: 'Servicio de ubicación activo.',
      foregroundServiceNotificationId: 888,
    ),
    iosConfiguration: IosConfiguration(
      autoStart: false,
      onForeground: onStart,
    ),
  );
}


//qwen 2.0
//minimax 01
//kimi 1.5
//deep seek 