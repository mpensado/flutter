import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/location_model.dart';

class LocationRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'locations';

  Future<void> addLocation(LocationModel location) async {
    try {
      await _firestore.collection(_collection).doc(location.locationId).set(location.toMap());
    } catch (e) {
      print('Error adding location: $e');
    }
  }

  Future<List<LocationModel>> getLocationsForUser(String userId, DateTime date) async {
    try {
      final startOfDay = DateTime(date.year, date.month, date.day, 0, 0, 0);
      final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59, 999, 999);

      final querySnapshot = await _firestore
          .collection(_collection)
          .where('user_id', isEqualTo: userId)
          .where('created_at', isGreaterThanOrEqualTo: startOfDay)
          .where('created_at', isLessThanOrEqualTo: endOfDay)
          .orderBy('created_at')
          .get();

      return querySnapshot.docs.map((doc) => LocationModel.fromMap(doc.data())).toList();
    } catch (e) {
      print('Error getting locations for user on date: $e');
      return [];
    }
  }

  // Puedes añadir más métodos para obtener ubicaciones en tiempo real, etc.
}