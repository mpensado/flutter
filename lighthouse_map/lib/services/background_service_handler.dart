import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:lighthouse_map/data/data_sources/local/local_location_data_source.dart';
import 'package:lighthouse_map/data/models/location_model.dart';
import 'package:lighthouse_map/data/repositories/location_repository.dart';
import 'package:lighthouse_map/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:firebase_core/firebase_core.dart';

// Este es el punto de entrada para el servicio en segundo plano.
// Debe ser una función global o un método estático.
@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  // --- INICIALIZACIÓN CRÍTICA PARA EL ISOLATE ---
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  // ---------------------------------------------

  // Ahora podemos instanciar nuestras dependencias de forma segura
  final LocationRepository locationRepository = LocationRepository(
    localLocationDataSource: LocalLocationDataSource(),
  );
  final AuthService authService = AuthService();
  final Uuid uuid = Uuid();
  StreamSubscription<Position>? positionStream;

  debugPrint('[MYLOG-BackgroundService] Servicio iniciado e inicializado.');
  service.on('startTracking').listen((event) async {
    debugPrint('[MYLOG-BackgroundService] Comando "startTracking" recibido.');

    positionStream?.cancel();
    positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen((position) async {
      debugPrint(
        '[MYLOG-BackgroundService] Nueva posición recibida: ${position.latitude}',
      );

      final userId = await authService.getCurrentUserId();
      final prefs = await SharedPreferences.getInstance();
      final deviceId = prefs.getString('device_id');

      if (userId == null || deviceId == null) {
        debugPrint(
          '[MYLOG-BackgroundService] ERROR: UserID o DeviceID es nulo.',
        );
        return;
      }

      final newLocation = LocationModel(
        locationId: uuid.v4(),
        userId: userId,
        deviceId: deviceId,
        latitude: position.latitude,
        longitude: position.longitude,
        timestamp: position.timestamp,
        createdAt: DateTime.now(),
      );

      await locationRepository.addLocation(newLocation);
      debugPrint(
        '[MYLOG-BackgroundService] Ubicación guardada en el repositorio local.',
      );

      // Este es el mensaje que el LocationBloc está escuchando
      service.invoke('update', {
        "latitude": position.latitude,
        "longitude": position.longitude,
      });
    }, onError: (error) {
      // --- AÑADE ESTO ---
      // Si hay algún error en el stream de Geolocator, lo veremos aquí.
      debugPrint('[MYLOG-BackgroundService] ERROR en el stream de Geolocator: $error');
    });
  });

  service.on('stopTracking').listen((event) {
    debugPrint('[MYLOG-BackgroundService] Comando "stopTracking" recibido.');
    positionStream?.cancel();
    positionStream = null;
  });
}
