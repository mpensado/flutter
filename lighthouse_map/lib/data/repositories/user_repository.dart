import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:lighthouse_map/data/models/user_model.dart';

class UserRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'users';

  Future<UserModel?> getUser(String userId) async {
    try {
      final doc = await _firestore.collection(_collection).doc(userId).get();
      if (doc.exists) {
        return UserModel.fromMap(doc.data() as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      debugPrint('[MYLOG]Error getting user: $e');
      return null;
    }
  }

  Future<void> createUser(UserModel user) async {
    try {
      await _firestore.collection(_collection).doc(user.userId).set(user.toMap());
    } catch (e) {
      debugPrint('[MYLOG]Error creating user: $e');
    }
  }

  Future<List<UserModel>> getAllUsers() async {
  try {
    final snapshot = await _firestore.collection(_collection).get();

    if (snapshot.docs.isEmpty) {
      return [];
    }
    return snapshot.docs.map((doc) {
      return UserModel.fromMap(doc.data());
    }).toList();

  } catch (e) {
    debugPrint('[MYLOG]Error getting users: $e');
    return [];
  }
}
}