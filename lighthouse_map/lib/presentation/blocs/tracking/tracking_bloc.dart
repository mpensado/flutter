import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart'; // Para debugPrint
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:lighthouse_map/data/models/location_model.dart';
import 'package:lighthouse_map/data/models/user_model.dart';
import 'package:lighthouse_map/data/repositories/location_repository.dart'; // Para obtener ubicaciones de otros
import 'package:lighthouse_map/data/repositories/tracked_user_repository.dart'; // Para ver a quién está permitido rastrear
import 'package:lighthouse_map/data/repositories/user_repository.dart';
import 'package:lighthouse_map/services/auth_service.dart'; // Para obtener el ID del usuario actual

part 'tracking_event.dart'; // <--- ¡ASEGÚRATE DE ESTA LÍNEA!
part 'tracking_state.dart'; // <--- ¡Y DE ESTA OTRA!


class TrackingBloc extends Bloc<TrackingEvent, TrackingState> {
  final UserRepository _userRepository;
  final TrackedUserRepository _trackedUserRepository;
  final LocationRepository _locationRepository;
  final AuthService _authService;

  TrackingBloc({
    required UserRepository userRepository,
    required TrackedUserRepository trackedUserRepository,
    required LocationRepository locationRepository,
    required AuthService authService,
  })  : _userRepository = userRepository,
        _trackedUserRepository = trackedUserRepository,
        _locationRepository = locationRepository,
        _authService = authService,
        super(TrackingInitial()) {

    on<LoadTrackableUsers>(_onLoadTrackableUsers);
    on<SelectTrackedUser>(_onSelectTrackedUser);
    on<SetTrackingDate>(_onSetSelectedDate);
  }

  Future<void> _onLoadTrackableUsers(LoadTrackableUsers event, Emitter<TrackingState> emit) async {
    emit(TrackingLoading());
    try {
      final currentUserId = await _authService.getCurrentUserId();
      if (currentUserId == null) {
        emit(const TrackingError(message: 'Usuario no autenticado.'));
        return;
      }

      // Obtener todos los usuarios del sistema (simplificado para la demo)
      // En una app real, aquí filtrarías por usuarios que has autorizado a ver o que te han autorizado a ver a ellos.
      // Por ahora, obtenemos la lista de usuarios que el usuario actual tiene en su lista de 'tracked_users'
      final trackedRelations = await _trackedUserRepository.getTrackedUsersForTracker(currentUserId);
      final List<String> trackedUserIds = trackedRelations.map((tr) => tr.trackedUserId).toList();

      // Obtener los detalles de esos usuarios
      List<UserModel> users = [];
      for (String userId in trackedUserIds) {
        final user = await _userRepository.getUser(userId);
        if (user != null) {
          users.add(user);
        }
      }

      // Puedes añadir el propio usuario a la lista si quieres ver tu propio historial también desde el selector
      final currentUserModel = await _userRepository.getUser(currentUserId);
      if (currentUserModel != null && !users.any((u) => u.userId == currentUserModel.userId)) {
         users.insert(0, currentUserModel); // Añadir el propio usuario al inicio
      }

      final previousState = state;
      UserModel? currentSelectedUser;
      DateTime currentDate = DateTime.now();

      // Mantener la selección si el estado anterior ya tenía datos
      if (previousState is TrackingUsersLoaded) {
        currentSelectedUser = previousState.selectedUser;
        currentDate = previousState.selectedDate;
        // Asegurarse de que el usuario seleccionado todavía esté en la lista
        if (currentSelectedUser != null && !users.any((u) => u.userId == currentSelectedUser!.userId)) {
          currentSelectedUser = null; // Reset si el usuario ya no es rastreable
        }
      }

      emit(TrackingUsersLoaded(
        trackableUsers: users,
        selectedUser: currentSelectedUser,
        selectedDate: currentDate,
      ));

      // Si ya había un usuario seleccionado, cargar sus datos para esa fecha
      if (currentSelectedUser != null) {
        await _fetchTrackedLocations(currentSelectedUser, currentDate, emit);
      }
    } catch (e) {
      debugPrint('[MYLOG]TrackingBloc Error al cargar usuarios rastreables: $e');
      emit(TrackingError(message: 'Error al cargar usuarios: $e'));
    }
  }

  Future<void> _onSelectTrackedUser(SelectTrackedUser event, Emitter<TrackingState> emit) async {
    if (state is TrackingUsersLoaded) {
      final currentState = state as TrackingUsersLoaded;
      emit(TrackingLoading()); // Emitir Loading mientras se cargan los datos
      emit(TrackingUsersLoaded( // Actualizar el usuario seleccionado primero
        trackableUsers: currentState.trackableUsers,
        selectedUser: event.selectedUser,
        selectedDate: currentState.selectedDate,
      ));

      if (event.selectedUser != null) {
        await _fetchTrackedLocations(event.selectedUser!, currentState.selectedDate, emit);
      } else {
        // Si se deselecciona el usuario, emitir un estado sin datos de ubicación
        emit(TrackingDataLoaded(
          trackableUsers: currentState.trackableUsers,
          selectedUser: null,
          selectedDate: currentState.selectedDate,
          trackedLocations: [], // Vaciar la lista de ubicaciones
        ));
      }
    }
  }

  Future<void> _onSetSelectedDate(SetTrackingDate event, Emitter<TrackingState> emit) async {
    if (state is TrackingUsersLoaded) {
      final currentState = state as TrackingUsersLoaded;
      emit(TrackingLoading()); // Emitir Loading
      emit(TrackingUsersLoaded( // Actualizar la fecha seleccionada primero
        trackableUsers: currentState.trackableUsers,
        selectedUser: currentState.selectedUser,
        selectedDate: event.selectedDate,
      ));

      if (currentState.selectedUser != null) {
        await _fetchTrackedLocations(currentState.selectedUser!, event.selectedDate, emit);
      } else {
        // Si no hay usuario seleccionado, pero se cambió la fecha, solo actualizar el estado
        emit(TrackingDataLoaded(
          trackableUsers: currentState.trackableUsers,
          selectedUser: null,
          selectedDate: event.selectedDate,
          trackedLocations: [],
        ));
      }
    }
  }

  // Método auxiliar para obtener las ubicaciones históricas y emitir el estado
  Future<void> _fetchTrackedLocations(UserModel user, DateTime date, Emitter<TrackingState> emit) async {
    try {
      final locations = await _locationRepository.getLocationsForUser(user.userId, date);

      // Emitir el estado con las ubicaciones cargadas
      emit(TrackingDataLoaded(
        trackableUsers: (state as TrackingUsersLoaded).trackableUsers, // Mantener lista de usuarios
        selectedUser: user,
        selectedDate: date,
        trackedLocations: locations,
      ));
      debugPrint('[MYLOG]TrackingBloc: Ubicaciones cargadas para ${user.nombre ?? user.email} en ${date.toIso8601String()}: ${locations.length} puntos.');
    } catch (e) {
      debugPrint('[MYLOG]TrackingBloc Error al cargar ubicaciones del usuario rastreado: $e');
      emit(TrackingError(message: 'Error al cargar historial: $e'));
    }
  }
}