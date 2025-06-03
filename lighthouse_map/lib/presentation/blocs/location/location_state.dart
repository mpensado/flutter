part of 'location_bloc.dart';

abstract class LocationState extends Equatable {
  const LocationState();

  @override
  List<Object> get props => [];
}

class LocationInitial extends LocationState {}

class LocationLoading extends LocationState {}

class LocationLoaded extends LocationState {
  final double latitude;
  final double longitude;
  final List<LocationModel> historicalLocations; // <--- ¡NUEVO CAMPO!

  const LocationLoaded({
    required this.latitude,
    required this.longitude,
    this.historicalLocations = const [], // Inicializa como lista vacía
  });

  @override
  List<Object> get props => [latitude, longitude, historicalLocations];
}

class LocationError extends LocationState {
  final String message;

  const LocationError({required this.message});

  @override
  List<Object> get props => [message];
}