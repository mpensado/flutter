import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:async';
import 'package:flutter/foundation.dart'; // Importa debugPrint para mejor logging

class ConnectivityService {
  final Connectivity _connectivity = Connectivity();

  final StreamController<ConnectivityResult> _connectivityStatusController =
      StreamController<ConnectivityResult>.broadcast();

  Stream<ConnectivityResult> get connectivityStream => _connectivityStatusController.stream;

  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription; // <--- CAMBIO AQUÍ: Ahora es List<ConnectivityResult>

  ConnectivityService() {
    _initConnectivity();
  }

  void _initConnectivity() {
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      (List<ConnectivityResult> results) { // <--- CAMBIO AQUÍ: El parámetro es una LISTA
        // Tomamos el primer resultado o ConnectivityResult.none si la lista está vacía
        // Puedes refinar la lógica si quieres manejar múltiples resultados de red.
        final ConnectivityResult currentResult = results.isNotEmpty ? results.first : ConnectivityResult.none;

        debugPrint('Cambio de conectividad detectado: $currentResult');
        _connectivityStatusController.add(currentResult);
      },
      // Elimina la cast 'as void Function(List<ConnectivityResult> event)?'
      // Ya no es necesaria una vez que el tipo del listener coincide.
    );
    // Elimina la cast 'as StreamSubscription<ConnectivityResult>?'
    // Ya no es necesaria una vez que el tipo de _connectivitySubscription coincide.
  }

  // Método para obtener el estado de conectividad actual de forma inmediata
  Future<ConnectivityResult> checkConnectivity() async {
    final List<ConnectivityResult> results = await _connectivity.checkConnectivity(); // <--- CAMBIO AQUÍ: Ahora devuelve una LISTA
    return results.isNotEmpty ? results.first : ConnectivityResult.none; // Toma el primer resultado o none
  }

  void dispose() {
    _connectivitySubscription?.cancel();
    _connectivityStatusController.close();
    debugPrint('ConnectivityService disposed.');
  }
}