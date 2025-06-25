import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/foundation.dart'; // <--- ¡ASEGÚRATE DE QUE ESTA IMPORTACIÓN ESTÉ AQUÍ!
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:lighthouse_map/presentation/blocs/location/location_bloc.dart';
import 'package:lighthouse_map/presentation/blocs/auth/auth_bloc.dart';
import 'package:lighthouse_map/data/models/location_model.dart';

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

  // Definir la altura inicial y mínima del DraggableScrollableSheet
  final double _initialSheetHeight = 0.3; // Más grande para visibilidad-
  final double _minSheetHeight = 0.1;    // Tamaño mínimo

  // Controlador para el DraggableScrollableSheet
  final DraggableScrollableController _sheetController = DraggableScrollableController();
  // Variable para almacenar la altura actual del sheet (como ratio 0.0-1.0)
  double _currentSheetHeightRatio = 0.3; // Inicializar con initialChildSize para la primera renderización

  @override
  void initState() {
    super.initState();
    debugPrint('[MYLOG] HomeScreen: initState llamado.'); // <--- Añadido log
    _sheetController.addListener(_onSheetChanged);
  }

  // Método que se llama cuando la altura del sheet cambia
  void _onSheetChanged() {
    if (_sheetController.isAttached) { // Asegurarse de que el controlador esté adjunto
      setState(() {
        _currentSheetHeightRatio = _sheetController.size; // <--- ¡CORRECCIÓN CRUCIAL AQUÍ!
        debugPrint('[MYLOG] HomeScreen: _onSheetChanged - _currentSheetHeightRatio actualizado a: $_currentSheetHeightRatio'); // <--- Añadido log
      });
    }
    // Elimina 'return false;' si estaba aquí. Esta función no es un NotificationListener callback.
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    // <--- ¡NUEVOS LOGS AQUÍ EN EL BUILD!
    debugPrint('[MYLOG] HomeScreen: build - screenHeight: $screenHeight');
    debugPrint('[MYLOG] HomeScreen: build - _currentSheetHeightRatio (en build): $_currentSheetHeightRatio');
    debugPrint('[MYLOG] HomeScreen: build - FAB bottom calculado: ${(screenHeight * _currentSheetHeightRatio) + 30.0}'); // Margen de 30 para los FABs
    // Fin de nuevos logs en build.

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
          // 1. Mapa de Google (primer hijo, se pinta abajo)
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
                
                if (_isTracking) {
                  _updatePolyline(state.historicalLocations);
                } else {
                  _polylines.clear();
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
                },
                markers: _markers,
                polylines: _polylines,
                myLocationEnabled: false,
                compassEnabled: true,
                zoomControlsEnabled: false,
              );
            },
          ),

          // 2. Botones flotantes dinámicos (Segundo hijo, se pintan encima del mapa)
          // Su `bottom` está ahora basado en la altura del panel deslizable.
          Positioned(
            right: 20,
            bottom: (screenHeight * _currentSheetHeightRatio) + 30, // Usamos la variable calculada
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
                  child: Icon(_isTracking ? Icons.play_arrow : Icons.play_arrow),
                ),
                const SizedBox(height: 12),
                FloatingActionButton(
                  heroTag: "stopBtn",
                  onPressed: () {
                    if (_isTracking) {
                      context.read<LocationBloc>().add(StopTrackingLocation());
                      setState(() {
                        _isTracking = false;
                        _polylines.clear();
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

          // 3. Panel deslizable (Tercer hijo, se pinta encima de todo lo anterior)
          DraggableScrollableSheet(
            controller: _sheetController,
            initialChildSize: _initialSheetHeight, // Usar la variable
            minChildSize: _minSheetHeight,
            maxChildSize: 0.5,
            snap: true,
            snapSizes: const [0.1, 0.3, 0.5],
            builder: (BuildContext context, ScrollController scrollController) {
              return Container(
                decoration: BoxDecoration(
                  color: Colors.blue[800]!.withAlpha(127), // Tu color actual
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
                  child: const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(child: DragHandle()),
                        SizedBox(height: 10),
                        Text(
                          'Controles de Seguimiento',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 20),
                        PlaceholderContent(), // Tu contenido de placeholder
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
      if (mounted) setState(() {});
    }
  }

  void _updatePolyline(List<LocationModel> locations) {
    _polylines.clear();

    debugPrint('[MYLOG] _updatePolyline: Ubicaciones recibidas (sin filtrar): ${locations.length}');

    final List<LocationModel> validLocations = locations.where((loc) =>
        (loc.latitude != 0.0 || loc.longitude != 0.0) && loc.timestamp != null
    ).toList();

    debugPrint('[MYLOG] _updatePolyline: Ubicaciones válidas después de filtrar (no 0,0 y con timestamp): ${validLocations.length}');


    if (validLocations.length < 2) {
      debugPrint('[MYLOG] _updatePolyline: No hay suficientes ubicaciones válidas (${validLocations.length}) para dibujar la polilínea (se necesitan al menos 2).');
      if (mounted) {
        setState(() {});
      }
      return;
    }

    validLocations.sort((a, b) => a.timestamp!.compareTo(b.timestamp!));

    final List<LatLng> points = validLocations.map((loc) => LatLng(loc.latitude, loc.longitude)).toList();

    _polylines.add(
      Polyline(
        polylineId: const PolylineId('myRoute'),
        points: points,
        color: Colors.red,
        width: 10,
        geodesic: true,
      ),
    );
    if (mounted) {
      setState(() {});
      debugPrint('[MYLOG] _updatePolyline: Polilínea añadida con ${points.length} puntos.');
    }
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

class PlaceholderContent extends StatelessWidget {
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