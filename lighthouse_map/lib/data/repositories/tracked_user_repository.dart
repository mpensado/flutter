import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/tracked_user_model.dart';

class TrackedUserRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'tracked_users';

  Future<void> addTrackedUser(TrackedUserModel trackedUser) async {
    try {
      await _firestore.collection(_collection).doc().set(trackedUser.toMap()); // Firestore genera el ID automáticamente
    } catch (e) {
      debugPrint('[MYLOG]Error adding tracked user: $e');
    }
  }

  Future<void> deleteTrackedUser(String trackedUserId) async {
    try {
      await _firestore.collection(_collection).doc(trackedUserId).delete();
    } catch (e) {
      debugPrint('[MYLOG]Error deleting tracked user: $e');
    }
  }

  Future<List<TrackedUserModel>> getTrackedUsersForTracker(String trackerUserId) async {
    try {
      final querySnapshot = await _firestore
          .collection(_collection)
          .where('tracker_user_id', isEqualTo: trackerUserId)
          .get();
      return querySnapshot.docs.map((doc) => TrackedUserModel.fromMap(doc.data())).toList();
    } catch (e) {
      debugPrint('[MYLOG]Error getting tracked users for tracker: $e');
      return [];
    }
  }

  Future<TrackedUserModel?> getTrackingRelation(String trackerUserId, String trackedUserId) async {
    try {
      final querySnapshot = await _firestore
          .collection(_collection)
          .where('tracker_user_id', isEqualTo: trackerUserId)
          .where('tracked_user_id', isEqualTo: trackedUserId)
          .limit(1)
          .get();
      if (querySnapshot.docs.isNotEmpty) {
        return TrackedUserModel.fromMap(querySnapshot.docs.first.data());
      }
      return null;
    } catch (e) {
      debugPrint('[MYLOG]Error getting tracking relation: $e');
      return null;
    }
  }

  Future<void> updateTrackingRelation(TrackedUserModel trackedUser, String documentId) async {
    try {
      await _firestore.collection(_collection).doc(documentId).update(trackedUser.toMap());
    } catch (e) {
      debugPrint('[MYLOG]Error updating tracking relation: $e');
    }
  }

  // Puedes añadir más métodos si es necesario
}