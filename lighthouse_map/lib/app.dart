import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lighthouse_map/presentation/blocs/auth/auth_bloc.dart';
import 'package:lighthouse_map/presentation/screens/home_screen.dart';
import 'package:lighthouse_map/presentation/screens/login_screen.dart';
import 'package:lighthouse_map/presentation/blocs/location/location_bloc.dart';
import 'package:lighthouse_map/presentation/blocs/tracking/tracking_bloc.dart'; // <--- NUEVA IMPORTACIÓN
import 'package:lighthouse_map/services/location_service.dart';
import 'package:lighthouse_map/data/repositories/location_repository.dart';
import 'package:lighthouse_map/services/auth_service.dart';
import 'package:lighthouse_map/data/repositories/device_repository.dart';
import 'package:lighthouse_map/data/repositories/user_repository.dart'; // <--- NUEVA IMPORTACIÓN
import 'package:lighthouse_map/data/repositories/tracked_user_repository.dart'; // <--- NUEVA IMPORTACIÓN
import 'package:lighthouse_map/services/connectivity_service.dart';
import 'package:lighthouse_map/data/data_sources/local/local_location_data_source.dart';


class AppState extends StatelessWidget {
  const AppState({super.key});

  @override
  Widget build(BuildContext context) {
    // Instancias de servicios y repositorios (se crean una única vez aquí)
    final LocalLocationDataSource localLocationDataSource = LocalLocationDataSource();
    final LocationRepository locationRepository = LocationRepository(
      localLocationDataSource: localLocationDataSource,
    );
    final AuthService authService = AuthService();
    final DeviceRepository deviceRepository = DeviceRepository();
    final UserRepository userRepository = UserRepository(); // <--- NUEVA INSTANCIA
    final TrackedUserRepository trackedUserRepository = TrackedUserRepository(); // <--- NUEVA INSTANCIA
    final LocationService locationService = LocationService();
    final ConnectivityService connectivityService = ConnectivityService();

    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>(create: ( _ ) => AuthBloc()),
        BlocProvider<LocationBloc>(
          create: (context) => LocationBloc(
            locationService: locationService,
            locationRepository: locationRepository,
            authService: authService,
            deviceRepository: deviceRepository,
            connectivityService: connectivityService,
            localLocationDataSource: localLocationDataSource,
          ),
        ),
        // ¡NUEVO: TrackingBloc!
        BlocProvider<TrackingBloc>(
          create: (context) => TrackingBloc(
            userRepository: userRepository,
            trackedUserRepository: trackedUserRepository,
            locationRepository: locationRepository,
            authService: authService,
          )..add(LoadTrackableUsers()), // Cargar usuarios al iniciar el Bloc
        ),
      ],
      child: const MyApp(),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key}); // Asegúrate de que MyApp sea const

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lighthouse Map',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: BlocConsumer<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthUnauthenticated) {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (context) => LoginScreen()),
              (route) => false,
            );
          }
        },
        builder: (context, state) {
          if (state is AuthAuthenticated) {
            return const HomeScreen(); // Asegúrate de que HomeScreen sea const
          } else {
            return LoginScreen();
          }
        },
      ),
    );
  }
}