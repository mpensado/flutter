import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/device_model.dart';

class DeviceRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'devices';

  Future<DeviceModel?> getDevice(String deviceId) async {
    try {
      final doc = await _firestore.collection(_collection).doc(deviceId).get();
      if (doc.exists) {
        return DeviceModel.fromMap(doc.data() as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      debugPrint('[MYLOG]Error getting device: $e');
      return null;
    }
  }

  Future<void> createDevice(DeviceModel device) async {
    try {
      await _firestore.collection(_collection).doc(device.deviceId).set(device.toMap());
    } catch (e) {
      debugPrint('[MYLOG]Error creating device: $e');
    }
  }

  Future<void> updateDevice(DeviceModel device) async {
    try {
      await _firestore.collection(_collection).doc(device.deviceId).update(device.toMap());
    } catch (e) {
      debugPrint('[MYLOG]Error updating device: $e');
    }
  }

  Future<List<DeviceModel>> getDevicesForUser(String userId) async {
    try {
      final querySnapshot = await _firestore.collection(_collection).where('user_id', isEqualTo: userId).get();
      return querySnapshot.docs.map((doc) => DeviceModel.fromMap(doc.data())).toList();
    } catch (e) {
      debugPrint('[MYLOG]Error getting devices for user: $e');
      return [];
    }
  }

  // Puedes añadir más métodos si es necesario
}