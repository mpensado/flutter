import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';

part 'location_event.dart';
part 'location_state.dart';

    class LocationBloc extends Bloc<LocationEvent, LocationState> {
      LocationBloc() : super(LocationInitial()) {
        on<StartTrackingLocation>((event, emit) async {
          emit(LocationLoading());
          try {
            final position = await Geolocator.getCurrentPosition(
              desiredAccuracy: LocationAccuracy.high,
            );
            emit(LocationLoaded(latitude: position.latitude, longitude: position.longitude));
            // Aquí deberías iniciar un Stream para escuchar actualizaciones continuas
          } catch (e) {
            emit(LocationError(message: 'Error al obtener la ubicación: $e'));
          }
        });

        on<StopTrackingLocation>((event, emit) {
          // Lógica para detener el Stream de ubicación si lo estás usando
          emit(LocationInitial()); // Volver al estado inicial al detener
        });

        on<LocationUpdated>((event, emit) {
          emit(LocationLoaded(latitude: event.latitude, longitude: event.longitude));
        });
      }
    }