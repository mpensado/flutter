import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

import 'package:lighthouse_map/data/models/location_model.dart';
import 'package:lighthouse_map/data/repositories/location_repository.dart';
import 'package:lighthouse_map/services/auth_service.dart';
import 'package:lighthouse_map/services/connectivity_service.dart';

part 'location_event.dart';
part 'location_state.dart';

class LocationBloc extends Bloc<LocationEvent, LocationState> {
  final LocationRepository _locationRepository;
  final AuthService _authService;
  final ConnectivityService _connectivityService;

  final _service = FlutterBackgroundService();
  StreamSubscription<Map<String, dynamic>?>? _serviceSubscription;
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;
  
  LocationBloc({
    required LocationRepository locationRepository,
    required AuthService authService,
    required ConnectivityService connectivityService,
  })  : _locationRepository = locationRepository,
        _authService = authService,
        _connectivityService = connectivityService,
        super(LocationInitial()) {
    
    // Escuchar actualizaciones que vienen del servicio de fondo
    _serviceSubscription = _service.on('update').listen((event) {
      if (event != null && event.containsKey('latitude')) {
        add(LocationUpdated(
          latitude: event["latitude"],
          longitude: event["longitude"], 
        ));
      }
    });

    // Escuchar la conectividad para sincronizar
    _connectivitySubscription = _connectivityService.connectivityStream.listen(
      (result) {
        if (result != ConnectivityResult.none) {
          add(SyncLocationsRequested());
        }
      },
    );

    on<StartTrackingLocation>((event, emit) async {
      debugPrint('[MYLOG]LocationBloc: Recibido StartTrackingLocation.');
      await _service.startService();
      // Ahora solo le decimos al servicio que inicie el tracking
      _service.invoke('startTracking');
      emit(LocationLoading());
    });

    on<StopTrackingLocation>((event, emit) async {
      debugPrint('[MYLOG]LocationBloc: Recibido StopTrackingLocation.');
      // Le decimos al servicio que detenga el tracking
      _service.invoke('stopTracking');
      emit(LocationInitial());
    });

    on<LocationUpdated>((event, emit) async {
      debugPrint('[MYLOG]LocationUpdated: Recibido LocationUpdated.');
      // La lógica para emitir el estado LocationLoaded se mantiene,
      // pero ahora se activa por los mensajes del servicio.
      final String? userId = await _authService.getCurrentUserId();
      debugPrint('[MYLOG]LocationUpdated: userId: ${userId ?? 'null'}');
      if (userId == null) return;

      final historicalLocations = await _locationRepository.getLocationsForUserByTimeRange(
          userId,
          DateTime.now(),
          const TimeOfDay(hour: 0, minute: 0),
          const TimeOfDay(hour: 23, minute: 59),
      );
      debugPrint('[MYLOG]LocationBloc: Emitiendo LocationLoaded con latitud: ${event.latitude}, longitud: ${event.longitude}.');
      emit(LocationLoaded(
        latitude: event.latitude,
        longitude: event.longitude,
        historicalLocations: historicalLocations,
      ));
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
    _serviceSubscription?.cancel();
    _connectivitySubscription?.cancel();
    return super.close();
  }
}