import 'dart:io';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async'; // Necesario para StreamController

class LocationService {
  // Este StreamController nos permitirá enviar actualizaciones de ubicación a los Blocs.
  // .broadcast() permite que múltiples escuchadores (listeners) se suscriban.
  final StreamController<Position> _locationStreamController =
      StreamController<Position>.broadcast();

  // Getter para el stream, los Blocs se suscribirán a este.
  Stream<Position> get locationStream => _locationStreamController.stream;

  // Almacenará la suscripción al stream de geolocator para poder cancelarla.
  StreamSubscription<Position>? _positionStreamSubscription;

  // Constructor
  LocationService();

  // Método para gestionar los permisos de ubicación
  Future<bool> handleLocationPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Comprueba si los servicios de ubicación están habilitados en el dispositivo.
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      debugPrint('[MYLOG]Los servicios de ubicación están deshabilitados en el dispositivo.');
      _locationStreamController.addError('Los servicios de ubicación están deshabilitados.');
      return false;
    }

    // Comprueba el estado de los permisos de ubicación de la aplicación.
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      // Si los permisos fueron denegados, solicita al usuario.
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        debugPrint('[MYLOG]Permisos de ubicación denegados por el usuario.');
        _locationStreamController.addError('Permisos de ubicación denegados.');
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      // Si los permisos fueron denegados permanentemente, informa al usuario.
      debugPrint('[MYLOG]Permisos de ubicación denegados permanentemente. Habilitar desde la configuración de la app.');
      _locationStreamController.addError('Permisos de ubicación denegados permanentemente.');
      return false;
    }

    // Permisos concedidos
    return true;
  }

  // Método para iniciar el seguimiento de la ubicación
  Future<void> startLocationUpdates({
    LocationAccuracy accuracy = LocationAccuracy.high,
    int distanceFilter = 5, // Actualizar cada 5 metros de cambio
    int intervalDurationMs = 5000, // Intervalo para Android, 5 segundos
  }) async {
    final hasPermission = await handleLocationPermission();
    if (!hasPermission) {
      return; // No se puede iniciar si no hay permisos
    }

    // Detiene cualquier suscripción anterior para evitar duplicados
    await stopLocationUpdates();

    final LocationSettings locationSettings;

    if (Platform.isAndroid) {
      // Reemplaza con una forma más robusta de detectar la plataforma si esto da problemas
      locationSettings = AndroidSettings(
        accuracy: accuracy,
        distanceFilter: distanceFilter,
        forceLocationManager: true,
        intervalDuration: Duration(milliseconds: intervalDurationMs),
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: '',
          notificationText: 'Rastreo de ubicación activo en segundo plano', // Texto de la notificación
          notificationChannelName: 'location_tracking_channel_name', // Nombre del canal de notificación (crear en Android)
          enableWifiLock: true, // Mantiene el WiFi activo mientras rastrea
          enableWakeLock: true, // Mantiene el dispositivo despierto mientras rastrea
        ),
      );
    } else if (Platform.isIOS) {
      locationSettings = AppleSettings(
        accuracy: accuracy,
        activityType: ActivityType.automotiveNavigation, // O el que mejor se adapte
        distanceFilter: distanceFilter,
        pauseLocationUpdatesAutomatically: true,
        allowBackgroundLocationUpdates: true, // Requiere configuración en Info.plist y Capabilities
        showBackgroundLocationIndicator: false, // Muestra la barra azul en iOS 11+
      );
    } else {
      locationSettings = LocationSettings(
        accuracy: accuracy,
        distanceFilter: distanceFilter,
      );
    }

    _positionStreamSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(
      (Position position) {
        _locationStreamController.add(position);
      },
      onError: (e) {
        debugPrint('[MYLOG]Error en el stream de ubicación: $e');
        _locationStreamController.addError('Error al obtener la ubicación: $e');
      },
    );
    debugPrint('[MYLOG]Seguimiento de ubicación iniciado.');
  }

  // Método para detener el seguimiento de la ubicación
  Future<void> stopLocationUpdates() async {
  if (_positionStreamSubscription != null) {
    await _positionStreamSubscription!.cancel();
    _positionStreamSubscription = null;
    debugPrint('[MYLOG]Seguimiento de ubicación detenido.');
  } else {
    debugPrint('[MYLOG]Advertencia: No hay un stream de ubicación activo para cancelar.');
  }
}

  // Limpia los recursos del StreamController cuando el servicio ya no se necesite
  void dispose() {
    stopLocationUpdates(); // Asegura que el stream de geolocator se cancele
    _locationStreamController.close();
  }
}