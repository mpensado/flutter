part of 'tracking_bloc.dart';

abstract class TrackingState extends Equatable {
  const TrackingState();

  @override
  List<Object> get props => [];
}

// Estado inicial del Bloc
class TrackingInitial extends TrackingState {}

// Estado de carga para cualquier operación del TrackingBloc
class TrackingLoading extends TrackingState {}

// Estado cuando la lista de usuarios rastreables ha sido cargada
class TrackingUsersLoaded extends TrackingState {
  final List<UserModel> trackableUsers;
  final UserModel? selectedUser;
  final DateTime selectedDate;

  const TrackingUsersLoaded({
    required this.trackableUsers,
    this.selectedUser,
    required this.selectedDate,
  });

  @override
  List<Object> get props => [trackableUsers, selectedUser ?? 'null', selectedDate];
}

// Estado cuando las ubicaciones históricas para un usuario/fecha han sido cargadas
class TrackingDataLoaded extends TrackingUsersLoaded {
  final List<LocationModel> trackedLocations;

  const TrackingDataLoaded({
    required super.trackableUsers,
    super.selectedUser,
    required super.selectedDate,
    required this.trackedLocations,
  });

  @override
  List<Object> get props => [trackableUsers, selectedUser ?? 'null', selectedDate, trackedLocations];
}

// Estado de error del TrackingBloc
class TrackingError extends TrackingState {
  final String message;

  const TrackingError({required this.message});

  @override
  List<Object> get props => [message];
}