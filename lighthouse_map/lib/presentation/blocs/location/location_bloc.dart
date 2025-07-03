import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

import 'package:lighthouse_map/data/models/location_model.dart';
import 'package:lighthouse_map/data/repositories/location_repository.dart';
import 'package:lighthouse_map/data/repositories/device_repository.dart';
import 'package:lighthouse_map/data/data_sources/local/local_location_data_source.dart';
import 'package:lighthouse_map/services/location_service.dart';
import 'package:lighthouse_map/services/auth_service.dart';
import 'package:lighthouse_map/services/connectivity_service.dart';
import 'package:uuid/uuid.dart';

part 'location_event.dart';
part 'location_state.dart';

class LocationBloc extends Bloc<LocationEvent, LocationState> {
  final LocationService _locationService;
  final LocationRepository _locationRepository;
  final AuthService _authService;
  final DeviceRepository _deviceRepository;
  final ConnectivityService _connectivityService;
  final LocalLocationDataSource _localLocationDataSource;
  final Uuid _uuid = Uuid();

  StreamSubscription<Position>? _positionStreamSubscription;
  StreamSubscription<ConnectivityResult>? _connectivitySubscription; // El tipo de la suscripción es ConnectivityResult (singular)

  LocationBloc({
    required LocationService locationService,
    required LocationRepository locationRepository,
    required AuthService authService,
    required DeviceRepository deviceRepository,
    required ConnectivityService connectivityService,
    required LocalLocationDataSource localLocationDataSource,
  })  : _locationService = locationService,
        _locationRepository = locationRepository,
        _authService = authService,
        _deviceRepository = deviceRepository,
        _connectivityService = connectivityService,
        _localLocationDataSource = localLocationDataSource,
        super(LocationInitial()) {
    
    _connectivitySubscription = _connectivityService.connectivityStream.listen(
      (ConnectivityResult result) { // <--- ¡CAMBIO AQUÍ! Espera UN SOLO 'ConnectivityResult'
        if (result != ConnectivityResult.none) {
          add(SyncLocationsRequested());
        }
      },
      // Elimina cualquier "as void Function(...)" aquí, ya no es necesario
    );

    on<StartTrackingLocation>((event, emit) async {
      debugPrint('[MYLOG]on<StartTrackingLocation>.');
      emit(LocationLoading());
      try {
        final hasPermission = await _locationService.handleLocationPermission();
        if (!hasPermission) {
          emit(const LocationError(message: 'Permisos de ubicación no concedidos.'));
          return;
        }

        final initialPosition = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
        final String? userId = await _authService.getCurrentUserId();
        final List<LocationModel> historicalLocations = (userId != null)
            ? await _locationRepository.getLocationsForUser(userId, DateTime.now())
            : [];

        emit(LocationLoaded(
          latitude: initialPosition.latitude,
          longitude: initialPosition.longitude,
          historicalLocations: historicalLocations,
        ));
        debugPrint('[MYLOG]Ubicación inicial cargada: Lat ${initialPosition.latitude}, Lng ${initialPosition.longitude}');

        await _locationService.startLocationUpdates(
          accuracy: LocationAccuracy.high,
          distanceFilter: 5,
          intervalDurationMs: 2500,
        );

        _positionStreamSubscription = _locationService.locationStream.listen((Position position) {
          add(LocationUpdated(latitude: position.latitude, longitude: position.longitude, position: position));
        }, onError: (e) {
          debugPrint('[MYLOG]Error en el stream de ubicación: $e');
          emit(LocationError(message: 'Error en el stream de ubicación: $e'));
        });

        add(SyncLocationsRequested());

      } catch (e) {
        debugPrint('[MYLOG]Error al iniciar el seguimiento de ubicación: $e');
        emit(LocationError(message: 'Error al iniciar el seguimiento de ubicación: $e'));
      }
    });

    on<StopTrackingLocation>((event, emit) async {
      await _locationService.stopLocationUpdates();
      if (_positionStreamSubscription != null) {
        await _positionStreamSubscription!.cancel();
        _positionStreamSubscription = null;
      }
      emit(LocationInitial());
    });

    on<LocationUpdated>((event, emit) async {
      debugPrint('[MYLOG]on<LocationUpdated>.');
      try {
        final String? userId = await _authService.getCurrentUserId();
        if (userId == null) {
          debugPrint('[MYLOG]LocationBloc: Usuario no autenticado, no se guarda ubicación.');
          return;
        }

        final prefs = await SharedPreferences.getInstance();
        final String? deviceId = prefs.getString('device_id');

        if (deviceId == null) {
          debugPrint('[MYLOG]LocationBloc: ID de dispositivo no encontrado, no se guarda ubicación.');
          return;
        }

        final newLocation = LocationModel(
          locationId: _uuid.v4(),
          userId: userId,
          deviceId: deviceId,
          latitude: event.latitude,
          longitude: event.longitude,
          timestamp: event.position.timestamp,
          createdAt: DateTime.now(),
        );

        await _locationRepository.addLocation(newLocation);

        final List<LocationModel> historicalLocations = await _locationRepository.getLocationsForUser(userId, DateTime.now());
        
        emit(LocationLoaded(
          latitude: event.latitude,
          longitude: event.longitude,
          historicalLocations: historicalLocations,
        ));
        debugPrint('[MYLOG]Ubicación agregada a la cola local y historial cargado: Lat ${event.latitude}, Lng ${event.longitude}');
      } catch (e) {
        debugPrint('[MYLOG]Error al agregar ubicación a la cola local o cargar historial: $e');
        emit(LocationError(message: 'Error al agregar ubicación a la cola local o cargar historial: $e'));
      }
    });

    on<SyncLocationsRequested>((event, emit) async {
      debugPrint('[MYLOG]LocationBloc: Recibido SyncLocationsRequested.');
      final connectivityResult = await _connectivityService.checkConnectivity();
      if (connectivityResult != ConnectivityResult.none) {
        try {
          await _locationRepository.syncPendingLocations();
          final String? userId = await _authService.getCurrentUserId();
          if (userId != null) {
            final List<LocationModel> historicalLocations = await _locationRepository.getLocationsForUser(userId, DateTime.now());
            if (state is LocationLoaded) {
              emit(LocationLoaded(
                latitude: (state as LocationLoaded).latitude,
                longitude: (state as LocationLoaded).longitude,
                historicalLocations: historicalLocations,
              ));
            }
          }
        } catch (e) {
          debugPrint('[MYLOG]LocationBloc Error al sincronizar ubicaciones: $e');
        }
      } else {
        debugPrint('[MYLOG]LocationBloc: No hay conexión a internet para sincronizar.');
      }
    });
  }

  @override
  Future<void> close() {
    _positionStreamSubscription?.cancel();
    _connectivitySubscription?.cancel();
    _locationService.dispose();
    _connectivityService.dispose();
    return super.close();
  }
}