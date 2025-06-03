import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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
  bool _isTracking = false; // Bandera para controlar si el tracking está activo

  @override
  void initState() {
    super.initState();
    // ¡IMPORTANTE! QUITAR LA LLAMADA A StartTrackingLocation() AQUÍ.
    // El seguimiento se iniciará solo al presionar el botón "Play".
    // El mapa se centrará inicialmente en (0,0) hasta que se reciba la primera ubicación después de Play.
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lighthouse Map - Mi Ubicación'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              context.read<AuthBloc>().add(LoggedOut());
            },
          ),
        ],
      ),
      body: BlocConsumer<LocationBloc, LocationState>(
        listener: (context, state) {
          if (state is LocationError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message)),
            );
            // Si hay un error, el tracking puede haberse detenido
            if (_isTracking) {
                setState(() {
                    _isTracking = false; // Actualiza la bandera en caso de error
                });
            }
          }
          if (state is LocationLoaded) {
            _currentLatLng = LatLng(state.latitude, state.longitude);
            _updateMap();
            _updateMarker(); // El pin SIEMPRE se actualizará con cada LocationLoaded

            // ¡La polilínea SÓLO se actualizará si _isTracking es true!
            if (_isTracking) {
                _updatePolyline(state.historicalLocations);
            } else {
                // Si no estamos haciendo tracking, aseguramos que la polilínea esté limpia.
                _polylines.clear();
                if (mounted) {
                    setState(() {});
                }
            }
          }
        },
        builder: (context, state) {
          return GoogleMap(
            mapType: MapType.normal,
            initialCameraPosition: CameraPosition(
              target: _currentLatLng ?? const LatLng(0, 0), // Centra en (0,0) si no hay ubicación aún
              zoom: 15,
            ),
            onMapCreated: (GoogleMapController controller) {
              _mapController = controller;
              // Si _currentLatLng ya está disponible (por ejemplo, desde una sesión anterior),
              // centramos el mapa aquí para evitar empezar en (0,0)
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
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: <Widget>[
          FloatingActionButton(
            heroTag: "startBtn",
            onPressed: () {
              if (!_isTracking) { // Solo iniciar si no está ya en seguimiento
                context.read<LocationBloc>().add(StartTrackingLocation());
                setState(() {
                  _isTracking = true; // Activa la bandera de seguimiento
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Iniciando seguimiento...')),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('El seguimiento ya está activo.')),
                );
              }
            },
            child: Icon(_isTracking ? Icons.play_arrow : Icons.play_arrow), // Icono por ahora
          ),
          const SizedBox(height: 10),
          FloatingActionButton(
            heroTag: "stopBtn",
            onPressed: () {
              if (_isTracking) { // Solo detener si está en seguimiento
                context.read<LocationBloc>().add(StopTrackingLocation());
                setState(() {
                  _isTracking = false; // Desactiva la bandera
                  _polylines.clear(); // Limpia la polilínea al detener el seguimiento
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Deteniendo seguimiento...')),
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

  void _updatePolyline(List<LocationModel> locations) {
    // La bandera _isTracking ya controla si se llega a este método desde el listener
    _polylines.clear(); // Limpiar polilíneas existentes

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
        color: Colors.red, // Color visible
        width: 10, // Ancho visible
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
    super.dispose();
  }
}