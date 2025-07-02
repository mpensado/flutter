part of 'tracking_bloc.dart';

abstract class TrackingState extends Equatable {
  const TrackingState();

  @override
  List<Object> get props => [];
}

class TrackingInitial extends TrackingState {}

class TrackingLoading extends TrackingState {}

class TrackingUsersLoaded extends TrackingState {
  final List<UserModel> trackableUsers;
  final UserModel? selectedUser;
  final DateTime selectedDate;
  // --- NUEVOS CAMPOS ---
  final TimeOfDay startHour;
  final TimeOfDay endHour;

  const TrackingUsersLoaded({
    required this.trackableUsers,
    this.selectedUser,
    required this.selectedDate,
    // --- VALORES POR DEFECTO PARA LAS HORAS ---
    this.startHour = const TimeOfDay(hour: 0, minute: 0),   // 00:00
    this.endHour = const TimeOfDay(hour: 23, minute: 59), // 23:59
  });

  @override
  List<Object> get props => [
        trackableUsers,
        selectedUser ?? 'null',
        selectedDate,
        startHour,
        endHour,
      ];
}

class TrackingDataLoaded extends TrackingUsersLoaded {
  final List<LocationModel> trackedLocations;

  const TrackingDataLoaded({
    required super.trackableUsers,
    super.selectedUser,
    required super.selectedDate,
    // --- PASAR LAS HORAS AL CONSTRUCTOR PADRE ---
    super.startHour,
    super.endHour,
    required this.trackedLocations,
  });

  // --- AÑADIR NUEVOS CAMPOS A PROPS ---
  @override
  List<Object> get props => [
        trackableUsers,
        selectedUser ?? 'null',
        selectedDate,
        startHour,
        endHour,
        trackedLocations,
      ];
}

// Estado de error del TrackingBloc
class TrackingError extends TrackingState {
  final String message;

  const TrackingError({required this.message});

  @override
  List<Object> get props => [message];
}