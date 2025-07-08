part of 'location_bloc.dart';

abstract class LocationEvent extends Equatable {
  const LocationEvent();

  @override
  List<Object> get props => [];
}

class StartTrackingLocation extends LocationEvent {}

class StartCurrentLocation extends LocationEvent {}

class StopTrackingLocation extends LocationEvent {}

class LocationUpdated extends LocationEvent {
  final double latitude;
  final double longitude;

  const LocationUpdated({
    required this.latitude,
    required this.longitude,
  });

  @override
  List<Object> get props => [latitude, longitude];
}

class SyncLocationsRequested extends LocationEvent {} // <--- ¡VERIFICA QUE ESTA LÍNEA ESTÉ AQUÍ!