import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/foundation.dart'; // Para debugPrint
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:table_calendar/table_calendar.dart'; // <--- ¡NUEVA IMPORTACIÓN!

import 'package:lighthouse_map/presentation/blocs/location/location_bloc.dart';
import 'package:lighthouse_map/presentation/blocs/auth/auth_bloc.dart';
import 'package:lighthouse_map/presentation/blocs/tracking/tracking_bloc.dart'; // <--- ¡NUEVA IMPORTACIÓN!
import 'package:lighthouse_map/data/models/location_model.dart';
import 'package:lighthouse_map/data/models/user_model.dart'; // <--- ¡NUEVA IMPORTACIÓN! 

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  GoogleMapController? _mapController;
  LatLng? _currentLatLng;
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  bool _isTracking = false;
  double _sheetSize = 0.1;

  // Definir la altura inicial y mínima del DraggableScrollableSheet
  final double _initialSheetHeight = 0.8; // Más grande para visibilidad-
  final double _minSheetHeight = 0.1;    // Tamaño mínimo

  final DraggableScrollableController _sheetController = DraggableScrollableController();

  // Para el calendario
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now(); // <--- Almacena la fecha seleccionada

  // Para el usuario seleccionado
  UserModel? _selectedTrackedUser; // <--- Almacena el usuario seleccionado

  @override
  void initState() {
    super.initState();
    debugPrint('[MYLOG] HomeScreen: initState llamado.');
    _sheetController.addListener(_onSheetChanged);
  }

  void _onSheetChanged() {
    if (_sheetController.isAttached) {
      setState(() {
        _sheetSize = _sheetController.size;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lighthouse Map - Mi Ubicación'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => context.read<AuthBloc>().add(LoggedOut()),
          ),
        ],
      ),
      body: Stack(
        children: [
          // 1. Mapa de Google
          BlocConsumer<LocationBloc, LocationState>(
            listener: (context, state) {
              if (state is LocationError) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(state.message)),
                );
                if (_isTracking) setState(() => _isTracking = false);
              }
              if (state is LocationLoaded) {
                _currentLatLng = LatLng(state.latitude, state.longitude);
                _updateMap();
                _updateMarker();

                // Actualizar polilínea del usuario actual SOLO si está en tracking activo
                if (_isTracking) {
                  _updatePolyline(state.historicalLocations, Colors.red, 'myRoute');
                } else {
                  // Si no está en tracking, limpiar la polilínea del usuario actual
                  // (Las polilíneas de otros usuarios se manejarán por el TrackingBloc)
                  _polylines.removeWhere((p) => p.polylineId.value == 'myRoute');
                  if (mounted) setState(() {});
                }
              }
            },
            builder: (context, state) {
              return GoogleMap(
                mapType: MapType.normal,
                initialCameraPosition: CameraPosition(
                  target: _currentLatLng ?? const LatLng(0, 0),
                  zoom: 15,
                ),
                onMapCreated: (controller) {
                  _mapController = controller;
                  if (_currentLatLng != null) {
                    _mapController!.animateCamera(CameraUpdate.newLatLng(_currentLatLng!));
                  }
                  setState(() {}); // Forzar rebuild para DraggableSheet
                },
                markers: _markers,
                polylines: _polylines,
                myLocationEnabled: false,
                compassEnabled: true,
                zoomControlsEnabled: false,
              );
            },
          ),

          // 2. Botones flotantes dinámicos
          Positioned(
            right: 16,
            bottom: 16, //(screenHeight * _sheetSize) + 30, 
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                FloatingActionButton(
                  heroTag: "startBtn",
                  onPressed: () {
                    if (!_isTracking) {
                      context.read<LocationBloc>().add(StartTrackingLocation());
                      setState(() => _isTracking = true);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Iniciando seguimiento...')),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('El seguimiento ya está activo.')),
                      );
                    }
                  },
                  child: Icon(_isTracking ? Icons.pause : Icons.play_arrow),
                ),
                const SizedBox(height: 12),
                FloatingActionButton(
                  heroTag: "stopBtn",
                  onPressed: () {
                    if (_isTracking) {
                      context.read<LocationBloc>().add(StopTrackingLocation());
                      setState(() {
                        _isTracking = false;
                        _polylines.removeWhere((p) => p.polylineId.value == 'myRoute'); // Limpia solo mi ruta
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Seguimiento detenido')),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('El seguimiento ya está detenido.')),
                      );
                    }
                  },
                  child: const Icon(Icons.stop),
                ),
              ],
            ),
          ),

          // 3. Panel deslizable
          DraggableScrollableSheet(
            controller: _sheetController,
            initialChildSize: _initialSheetHeight,
            minChildSize: _minSheetHeight,
            maxChildSize: 0.8,
            snap: true,
            snapSizes: const [0.1, 0.3, 0.5, 0.8],
            builder: (BuildContext context, ScrollController scrollController) {
              return Container(
                decoration: BoxDecoration(
                  color: Colors.blue[800]!.withAlpha(127),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 15,
                      spreadRadius: 0,
                      offset: Offset(0, -5),
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  controller: scrollController,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const Center(child: DragHandle()),
                        const SizedBox(height: 10),
                        Text(
                          'Controles de Seguimiento',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.white),
                        ),
                        const SizedBox(height: 20),
                        // --- Selector de Usuario y Calendario ---
                        BlocConsumer<TrackingBloc, TrackingState>( // <--- NUEVO CONSUMER PARA TRACKINGBLOC
                          listener: (context, state) {
                            if (state is TrackingError) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(state.message)),
                              );
                            }
                            if (state is TrackingUsersLoaded) {
                              _selectedTrackedUser = state.selectedUser; // Actualiza el usuario seleccionado en el estado local
                              _selectedDay = state.selectedDate; // Actualiza la fecha seleccionada en el estado local
                            }
                            if (state is TrackingDataLoaded) {
                              // Cuando se cargan datos de un usuario rastreado, actualizar la polilínea
                              // Asegúrate de no limpiar las mías si yo estoy haciendo tracking
                              _polylines.removeWhere((p) => p.polylineId.value != 'myRoute'); // Limpia solo las de otros
                              _updatePolyline(state.trackedLocations, Colors.green, 'trackedUserRoute'); // Dibuja la de él en verde
                            }
                          },
                          builder: (context, state) {
                            List<UserModel> users = [];
                            UserModel? currentUserSelected;
                            DateTime currentCalendarDay = _selectedDay; // Usa la fecha seleccionada localmente

                            if (state is TrackingUsersLoaded) {
                              users = state.trackableUsers;
                              currentUserSelected = state.selectedUser;
                              currentCalendarDay = state.selectedDate;
                            } else if (state is TrackingLoading) {
                              return const Center(child: CircularProgressIndicator(color: Colors.white));
                            } else if (state is TrackingError) {
                              return Text('Error: ${state.message}', style: const TextStyle(color: Colors.red));
                            }

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Usuario a visualizar:',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white),
                                ),
                                const SizedBox(height: 10),
                                // Selector de Usuario
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<UserModel>(
                                      isExpanded: true,
                                      value: currentUserSelected,
                                      hint: const Text('Seleccionar usuario'),
                                      onChanged: (UserModel? newUser) {
                                        context.read<TrackingBloc>().add(SelectTrackedUser(newUser));
                                      },
                                      items: users.map<DropdownMenuItem<UserModel>>((UserModel user) {
                                        return DropdownMenuItem<UserModel>(
                                          value: user,
                                          child: Text(user.nombre ?? user.email ?? 'Usuario sin nombre'),
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 20),
                                Text(
                                  'Fecha de historial:',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white),
                                ),
                                const SizedBox(height: 10),
                                SizedBox(
                                  height: 250, // Altura deseada
                                  child: TableCalendar(
                                    firstDay: DateTime.utc(2020, 1, 1),
                                    lastDay: DateTime.utc(2030, 12, 31),
                                    focusedDay: currentCalendarDay,
                                    selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                                    onDaySelected: (selectedDay, focusedDay) {
                                      if (!isSameDay(_selectedDay, selectedDay)) {
                                        setState(() {
                                          _selectedDay = selectedDay;
                                          _focusedDay = focusedDay;
                                        });
                                        context.read<TrackingBloc>().add(SetTrackingDate(selectedDay));
                                      }
                                    },
                                    calendarFormat: CalendarFormat.month,
                                    rowHeight: 35.0,
                                    headerStyle: HeaderStyle(
                                      formatButtonVisible: false,
                                      titleCentered: true,
                                      titleTextStyle: Theme.of(context).textTheme.titleMedium!.copyWith(color: Colors.white, fontSize: 16),
                                      leftChevronIcon : const Icon(Icons.chevron_left, color: Colors.white, size: 20),
                                      rightChevronIcon : const Icon(Icons.chevron_right, color: Colors.white, size: 20),
                                    ),
                                    calendarStyle: CalendarStyle(
                                      outsideDaysVisible: false,
                                      defaultTextStyle: const TextStyle(color: Colors.white70, fontSize: 14),
                                      weekendTextStyle: const TextStyle(color: Colors.white54, fontSize: 14),
                                      todayDecoration: BoxDecoration(color: Colors.blue.withAlpha(127), shape: BoxShape.circle),
                                      selectedDecoration: const BoxDecoration(color: Colors.blue, shape: BoxShape.circle),
                                    ),
                                    daysOfWeekStyle: DaysOfWeekStyle(
                                      weekdayStyle: const TextStyle(color: Colors.white70, fontSize: 14),
                                      weekendStyle: const TextStyle(color: Colors.white54, fontSize: 14),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 20),
                                // Placeholder para el filtro de hora
                                Text(
                                  'Filtro por Hora (Próximamente)',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white),
                                ),
                                const SizedBox(height: 100), // Espacio para el scroll
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _updateMap() {
    if (_mapController != null && _currentLatLng != null) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLng(_currentLatLng!),
      );
    }
  }

  void _updateMarker() {
    if (_currentLatLng != null) {
      _markers.clear();
      _markers.add(
        Marker(
          markerId: const MarkerId('currentLocation'),
          position: _currentLatLng!,
          infoWindow: const InfoWindow(title: 'Mi ubicación'),
        ),
      );
      if (mounted) {
        setState(() {});
      }
    }
  }

  // Método _updatePolyline modificado para aceptar color y polylineId
  void _updatePolyline(List<LocationModel> locations, Color color, String id) {
    // No limpiar _polylines.clear() si queremos mostrar múltiples polilíneas de diferentes usuarios
    // Si solo queremos mostrar UNA polilínea a la vez (mi ruta O la de otro), entonces sí limpiar al inicio
    // Para esta etapa, si _isTracking, es mi ruta, si no, la de otro (asumimos una a la vez).
    // Si quiero mostrar ambas, necesitaría IDs únicos para cada usuario/ruta y no limpiar todo.

    // Si la lógica es "solo una ruta a la vez (mi ruta o la de otro)", entonces limpiamos todas las polilíneas
    // exceptuando el caso donde yo estoy en tracking activo y se carga un historial de otro.
    // Una mejor forma sería:
    // 1. Siempre limpiar _polylines al inicio de _updatePolyline
    // 2. Si _isTracking, añadir mi ruta
    // 3. Si se recibe TrackingDataLoaded, limpiar todas y añadir la de ese usuario

    // Dado el requisito de "una persona a la vez", simplificamos la lógica:
    // Este método es llamado por LocationBlocConsumer y TrackingBlocConsumer.
    // Ambos deberían pasar la lista de puntos y el ID/color apropiado.
    // Los clear() los manejamos en los listeners para más control.

    final List<LatLng> points = locations.map((loc) => LatLng(loc.latitude, loc.longitude)).toList();

    _polylines.removeWhere((p) => p.polylineId.value == id); // Limpia solo la polilínea con ese ID

    if (points.length < 2) {
      if (mounted) setState(() {});
      return;
    }

    _polylines.add(
      Polyline(
        polylineId: PolylineId(id),
        points: points,
        color: color,
        width: 10,
        geodesic: true,
      ),
    );
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _mapController?.dispose();
    _sheetController.removeListener(_onSheetChanged);
    _sheetController.dispose();
    super.dispose();
  }
}

class DragHandle extends StatelessWidget {
  const DragHandle({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 5,
      margin: const EdgeInsets.only(top: 8, bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.7),
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }
}

class PlaceholderContent extends StatelessWidget { // <--- Ya no se usa directamente
  const PlaceholderContent({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildPlaceholderItem('Usuario actual', Icons.person),
        const SizedBox(height: 15),
        _buildPlaceholderItem('Historial de rutas', Icons.history),
        const SizedBox(height: 15),
        _buildPlaceholderItem('Configuración', Icons.settings),
        const SizedBox(height: 100),
      ],
    );
  }

  Widget _buildPlaceholderItem(String text, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: Colors.white70, size: 20),
        const SizedBox(width: 10),
        Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
          ),
        ),
      ],
    );
  }
}