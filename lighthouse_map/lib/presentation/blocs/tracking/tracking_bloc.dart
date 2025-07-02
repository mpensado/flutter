import 'package:equatable/equatable.dart';
// Para debugPrint
import 'package:flutter/material.dart';
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
  }) : _userRepository = userRepository,
       _trackedUserRepository = trackedUserRepository,
       _locationRepository = locationRepository,
       _authService = authService,
       super(TrackingInitial()) {
    on<LoadTrackableUsers>(_onLoadTrackableUsers);
    on<SelectTrackedUser>(_onSelectTrackedUser);
    on<SetTrackingDate>(_onSetSelectedDate);
    on<LoadAllUsersForSelection>(_onLoadAllUsersForSelection);
    on<TrackingTimeRangeChanged>(_onTrackingTimeRangeChanged);
  }

Future<void> _onLoadTrackableUsers(LoadTrackableUsers event, Emitter<TrackingState> emit) async {
  emit(TrackingLoading());
  try {
    final currentUserId = await _authService.getCurrentUserId();
    if (currentUserId == null) {
      emit(const TrackingError(message: 'Usuario no autenticado.'));
      return;
    }

    // ... (toda tu lógica para obtener los trackedRelations y la lista de 'users' se queda igual)
    final trackedRelations = await _trackedUserRepository.getTrackedUsersForTracker(currentUserId);
    final List<String> trackedUserIds = trackedRelations.map((tr) => tr.trackedUserId).toList();

    List<UserModel> users = [];
    for (String userId in trackedUserIds) {
      final user = await _userRepository.getUser(userId);
      if (user != null) {
        users.add(user);
      }
    }

    final currentUserModel = await _userRepository.getUser(currentUserId);
    if (currentUserModel != null && !users.any((u) => u.userId == currentUserModel.userId)) {
        users.insert(0, currentUserModel);
    }

    final previousState = state;
    UserModel? currentSelectedUser;
    DateTime currentDate = DateTime.now();
    
    // --- AÑADIMOS VARIABLES PARA LA HORA ---
    TimeOfDay currentStartHour = const TimeOfDay(hour: 0, minute: 0);
    TimeOfDay currentEndHour = const TimeOfDay(hour: 23, minute: 59);

    if (previousState is TrackingUsersLoaded) {
      currentSelectedUser = previousState.selectedUser;
      currentDate = previousState.selectedDate;
      // --- OBTENEMOS LAS HORAS DEL ESTADO ANTERIOR ---
      currentStartHour = previousState.startHour;
      currentEndHour = previousState.endHour;
      
      if (currentSelectedUser != null && !users.any((u) => u.userId == currentSelectedUser!.userId)) {
        currentSelectedUser = null; 
      }
    }

    emit(TrackingUsersLoaded(
      trackableUsers: users,
      selectedUser: currentSelectedUser,
      selectedDate: currentDate,
      // --- PASAMOS LAS HORAS AL NUEVO ESTADO ---
      startHour: currentStartHour,
      endHour: currentEndHour,
    ));

    // --- LLAMADA CORREGIDA Y COMPLETA ---
    if (currentSelectedUser != null) {
      await _fetchTrackedLocations(
        currentSelectedUser,
        currentDate,
        currentStartHour, // <-- Parámetro añadido
        currentEndHour,   // <-- Parámetro añadido
        emit,
      );
    }
  } catch (e) {
    debugPrint('[MYLOG]TrackingBloc Error al cargar usuarios rastreables: $e');
    emit(TrackingError(message: 'Error al cargar usuarios: $e'));
  }
}

  Future<void> _onSelectTrackedUser(
    SelectTrackedUser event,
    Emitter<TrackingState> emit,
  ) async {
    if (state is TrackingUsersLoaded) {
      final currentState = state as TrackingUsersLoaded;
      emit(TrackingLoading()); // Emitir Loading mientras se cargan los datos
      emit(
        TrackingUsersLoaded(
          // Actualizar el usuario seleccionado primero
          trackableUsers: currentState.trackableUsers,
          selectedUser: event.selectedUser,
          selectedDate: currentState.selectedDate,
        ),
      );

      if (event.selectedUser != null) {
        //await _fetchTrackedLocations(event.selectedUser!, currentState.selectedDate, emit);
        await _fetchTrackedLocations(
          event.selectedUser!,
          currentState.selectedDate,
          currentState.startHour,
          currentState.endHour,
          emit,
        );
      } else {
        // Si se deselecciona el usuario, emitir un estado sin datos de ubicación
        emit(
          TrackingDataLoaded(
            trackableUsers: currentState.trackableUsers,
            selectedUser: null,
            selectedDate: currentState.selectedDate,
            trackedLocations: [], // Vaciar la lista de ubicaciones
          ),
        );
      }
    }
  }

  Future<void> _onSetSelectedDate(
    SetTrackingDate event,
    Emitter<TrackingState> emit,
  ) async {
    if (state is TrackingUsersLoaded) {
      final currentState = state as TrackingUsersLoaded;
      emit(TrackingLoading()); // Emitir Loading
      emit(
        TrackingUsersLoaded(
          // Actualizar la fecha seleccionada primero
          trackableUsers: currentState.trackableUsers,
          selectedUser: currentState.selectedUser,
          selectedDate: event.selectedDate,
        ),
      );

      if (currentState.selectedUser != null) {
        //await _fetchTrackedLocations(currentState.selectedUser!, event.selectedDate, emit);
        await _fetchTrackedLocations(
          currentState.selectedUser!,
          event.selectedDate,
          currentState.startHour,
          currentState.endHour,
          emit,
        );
      } else {
        // Si no hay usuario seleccionado, pero se cambió la fecha, solo actualizar el estado
        emit(
          TrackingDataLoaded(
            trackableUsers: currentState.trackableUsers,
            selectedUser: null,
            selectedDate: event.selectedDate,
            trackedLocations: [],
          ),
        );
      }
    }
  }

  // Método auxiliar para obtener las ubicaciones históricas y emitir el estado
  Future<void> _fetchTrackedLocations(
    UserModel user,
    DateTime date,
    TimeOfDay startHour,
    TimeOfDay endHour,
    Emitter<TrackingState> emit,
  ) async {
    try {
      // NOTA: Este método ahora dará error porque aún no existe en el repositorio. ¡Es nuestro siguiente paso!
      final locations = await _locationRepository
          .getLocationsForUserByTimeRange(
            user.userId,
            date,
            startHour,
            endHour,
          );

      // Emitir el estado con las ubicaciones cargadas
      emit(
        TrackingDataLoaded(
          trackableUsers: (state as TrackingUsersLoaded).trackableUsers,
          selectedUser: user,
          selectedDate: date,
          startHour: startHour, // <-- Pasar la hora al estado final
          endHour: endHour, // <-- Pasar la hora al estado final
          trackedLocations: locations,
        ),
      );
      debugPrint(
        '[MYLOG]TrackingBloc: Ubicaciones cargadas para ${user.nombre ?? user.email} en ${date.toIso8601String()}: ${locations.length} puntos.',
      );
    } catch (e) {
      debugPrint(
        '[MYLOG]TrackingBloc Error al cargar ubicaciones del usuario rastreado: $e',
      );
      emit(TrackingError(message: 'Error al cargar historial: $e'));
    }
  }

  Future<void> _onLoadAllUsersForSelection(
    LoadAllUsersForSelection event,
    Emitter<TrackingState> emit,
  ) async {
    emit(TrackingLoading());
    try {
      final List<UserModel> allUsers = await _userRepository.getAllUsers();

      final previousState = state;
      UserModel? currentSelectedUser;
      DateTime currentDate = DateTime.now();

      // --- AÑADIMOS VARIABLES PARA LA HORA ---
      TimeOfDay currentStartHour = const TimeOfDay(hour: 0, minute: 0);
      TimeOfDay currentEndHour = const TimeOfDay(hour: 23, minute: 59);

      if (previousState is TrackingUsersLoaded) {
        currentSelectedUser = previousState.selectedUser;
        currentDate = previousState.selectedDate;
        // --- OBTENEMOS LAS HORAS DEL ESTADO ANTERIOR ---
        currentStartHour = previousState.startHour;
        currentEndHour = previousState.endHour;

        if (currentSelectedUser != null &&
            !allUsers.any((u) => u.userId == currentSelectedUser!.userId)) {
          currentSelectedUser = null;
        }
      }

      emit(
        TrackingUsersLoaded(
          trackableUsers: allUsers,
          selectedUser: currentSelectedUser,
          selectedDate: currentDate,
          // --- PASAMOS LAS HORAS AL NUEVO ESTADO ---
          startHour: currentStartHour,
          endHour: currentEndHour,
        ),
      );

      // --- LLAMADA CORREGIDA Y COMPLETA ---
      if (currentSelectedUser != null) {
        await _fetchTrackedLocations(
          currentSelectedUser,
          currentDate,
          currentStartHour, // <-- Parámetro añadido
          currentEndHour, // <-- Parámetro añadido
          emit,
        );
      }
    } catch (e) {
      debugPrint('[MYLOG]TrackingBloc Error al cargar todos los usuarios: $e');
      emit(
        TrackingError(
          message: 'Error al cargar la lista de todos los usuarios: $e',
        ),
      );
    }
  }

  Future<void> _onTrackingTimeRangeChanged(
    TrackingTimeRangeChanged event,
    Emitter<TrackingState> emit,
  ) async {
    if (state is TrackingUsersLoaded) {
      final currentState = state as TrackingUsersLoaded;

      // 1. Emitimos un estado con las horas actualizadas para que la UI (etiquetas del slider) reaccione
      emit(TrackingUsersLoaded(
        trackableUsers: currentState.trackableUsers,
        selectedUser: currentState.selectedUser,
        selectedDate: currentState.selectedDate,
        startHour: event.startHour, // <-- La nueva hora del evento
        endHour: event.endHour,     // <-- La nueva hora del evento
      ));

      // 2. Si hay un usuario seleccionado, volvemos a buscar sus datos con el nuevo filtro de hora
      if (currentState.selectedUser != null) {
        await _fetchTrackedLocations(
          currentState.selectedUser!,
          currentState.selectedDate,
          event.startHour, // <-- Usamos la nueva hora
          event.endHour,   // <-- Usamos la nueva hora
          emit,
        );
      }
    }
  }
}
