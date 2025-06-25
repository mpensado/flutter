part of 'tracking_bloc.dart';

abstract class TrackingEvent extends Equatable {
  const TrackingEvent();

  @override
  List<Object> get props => [];
}

// Evento para cargar la lista de usuarios a los que se puede hacer tracking
class LoadTrackableUsers extends TrackingEvent {}

// Evento para seleccionar un usuario para hacer tracking
class SelectTrackedUser extends TrackingEvent {
  final UserModel? selectedUser; // El usuario seleccionado (puede ser null para "nadie")

  const SelectTrackedUser(this.selectedUser);

  @override
  List<Object> get props => [selectedUser ?? 'null'];
}

// Evento para establecer la fecha para ver el historial
class SetTrackingDate extends TrackingEvent {
  final DateTime selectedDate;

  const SetTrackingDate(this.selectedDate);

  @override
  List<Object> get props => [selectedDate];
}