import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lighthouse_map/data/repositories/user_repository.dart';
import 'package:lighthouse_map/services/auth_service.dart';

part 'auth_event.dart';
part 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthService _authService = AuthService();
  final UserRepository _userRepository = UserRepository(); // Asegúrate de tener esta importación si la usas directamente

  AuthBloc() : super(AuthInitial()) {
    on<AppStarted>((event, emit) async {
      final isSignedIn = await _authService.isSignedIn();
      if (isSignedIn) {
        final user = await _authService.getCurrentUser();
        if (user != null) {
          emit(AuthAuthenticated());
        } else {
          emit(AuthUnauthenticated());
        }
      } else {
        emit(AuthUnauthenticated());
      }
    });

    on<LoggedIn>((event, emit) {
      emit(AuthAuthenticated());
    });

    on<LoggedOut>((event, emit) async {
      await _authService.signOut();
      emit(AuthUnauthenticated());
    });

    on<RegisterRequested>((event, emit) async {
      emit(AuthLoading());
      final user = await _authService.signUpWithEmailAndPassword(event.email, event.password);
      if (user != null) {
        emit(AuthAuthenticated());
      } else {
        emit(const AuthFailure(message: 'Error al registrar el usuario.'));
      }
    });

    on<LoginRequested>((event, emit) async {
      emit(AuthLoading());
      final user = await _authService.signInWithEmailAndPassword(event.email, event.password);
      if (user != null) {
        emit(AuthAuthenticated());
      } else {
        emit(const AuthFailure(message: 'Correo electrónico o contraseña incorrectos.'));
      }
    });
  }
}