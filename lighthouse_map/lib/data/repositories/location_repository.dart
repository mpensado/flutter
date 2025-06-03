import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart'; // Para debugPrint

import 'package:lighthouse_map/data/models/location_model.dart';
import 'package:lighthouse_map/data/data_sources/local/local_location_data_source.dart';

class LocationRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final LocalLocationDataSource _localLocationDataSource;
  final String _collection = 'locations';

  LocationRepository({
    required LocalLocationDataSource localLocationDataSource,
  }) : _localLocationDataSource = localLocationDataSource;

  Future<void> addLocation(LocationModel location) async {
    try {
      await _localLocationDataSource.insertLocation(location);
      debugPrint('[MYLOG]Ubicación agregada a la cola local: ${location.locationId}');
    } catch (e) {
      debugPrint('[MYLOG]Error al guardar la ubicación localmente: $e');
    }
  }

  Future<void> syncPendingLocations() async {
    debugPrint('[MYLOG]Iniciando sincronización de ubicaciones pendientes...');
    final pendingLocations = await _localLocationDataSource.getPendingLocations();

    if (pendingLocations.isEmpty) {
      debugPrint('[MYLOG]No hay ubicaciones pendientes para sincronizar.');
      return;
    }

    final WriteBatch batch = _firestore.batch();
    List<LocationModel> successfullySynced = [];

    for (var location in pendingLocations) {
      try {
        batch.set(_firestore.collection(_collection).doc(location.locationId), location.toMap());
        successfullySynced.add(location);
      } catch (e) {
        debugPrint('[MYLOG]Error al añadir ubicación ${location.locationId} al batch de sincronización: $e');
      }
    }

    try {
      await batch.commit();
      debugPrint('[MYLOG]Batch de ubicaciones sincronizado exitosamente.');

      for (var location in successfullySynced) {
        await _localLocationDataSource.deleteLocation(location.locationId);
      }
      debugPrint('[MYLOG]Ubicaciones sincronizadas eliminadas de la cola local.');
    } on FirebaseException catch (e) {
      if (e.code == 'unavailable' || e.code == 'internal') {
        debugPrint('[MYLOG]Error de red al sincronizar el batch. Las ubicaciones permanecen localmente: $e');
      } else {
        debugPrint('[MYLOG]Error de Firebase al sincronizar el batch: $e');
      }
    } catch (e) {
      debugPrint('[MYLOG]Error desconocido al sincronizar el batch de ubicaciones: $e');
    }
  }

  Future<List<LocationModel>> getLocationsForUser(String userId, DateTime date) async {
    try {
      final startOfDay = DateTime(date.year, date.month, date.day, 0, 0, 0);
      final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59, 999, 999);
      debugPrint('[MYLOG] LocationRepo: Obteniendo ubicaciones para el usuario $userId en la fecha ${date.toLocal().toIso8601String()}');
      debugPrint('[MYLOG] LocationRepo: Rango de fecha: ${startOfDay.toIso8601String()} a ${endOfDay.toIso8601String()}');


      // Primero, obtener las ubicaciones locales pendientes
      final List<LocationModel> localLocations = await _localLocationDataSource.getPendingLocations();
      debugPrint('[MYLOG] LocationRepo: Total de ubicaciones locales pendientes (antes de filtrar): ${localLocations.length}');

      final List<LocationModel> filteredLocal = localLocations.where((loc) {
        final locDate = loc.createdAt?.toLocal();
        
        if (locDate == null) {
          debugPrint('[MYLOG] LocationRepo: FILTER REASON: createdAt es nulo para ${loc.locationId}.');
          return false;
        }

        final bool isWithinDateRange = locDate.isAfter(startOfDay.subtract(const Duration(seconds: 1))) &&
                                     locDate.isBefore(endOfDay.add(const Duration(seconds: 1)));
        final bool matchesUser = loc.userId == userId;
        
        if (!matchesUser) {
          debugPrint('[MYLOG] LocationRepo: FILTER REASON: ID de usuario no coincide para ${loc.locationId}. Esperado: "$userId", Obtenido: "${loc.userId}".');
        }
        if (!isWithinDateRange) {
          debugPrint('[MYLOG] LocationRepo: FILTER REASON: Fecha no coincide para ${loc.locationId}. Fecha de ubicación: ${locDate.toIso8601String()}, Rango: ${startOfDay.toIso8601String()} a ${endOfDay.toIso8601String()}');
        }

        return isWithinDateRange && matchesUser;
      }).toList();
      debugPrint('[MYLOG] LocationRepo: Ubicaciones locales filtradas para el día/usuario actual: ${filteredLocal.length}');

      // Luego, obtener las ubicaciones de Firestore
      // (Asumiendo que Firestore está vacío, pero la consulta sigue siendo importante para el futuro)
      final querySnapshot = await _firestore
          .collection(_collection)
          .where('user_id', isEqualTo: userId)
          .where('created_at', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('created_at', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
          .orderBy('created_at')
          .get();
      
      final List<LocationModel> firestoreLocations = querySnapshot.docs.map((doc) {
        return LocationModel.fromMap(doc.data());
      }).toList();
      debugPrint('[MYLOG] LocationRepo: Ubicaciones de Firestore: ${firestoreLocations.length}');


      // Combinar y ordenar
      final allLocations = [...firestoreLocations, ...filteredLocal];
      allLocations.sort((a, b) => (a.createdAt ?? DateTime(0)).compareTo(b.createdAt ?? DateTime(0)));
      debugPrint('[MYLOG] LocationRepo: Total de ubicaciones combinadas y ordenadas: ${allLocations.length}');


      return allLocations;

    } catch (e) {
      debugPrint('[MYLOG]Error getting locations for user on date: $e');
      return [];
    }
  }
}