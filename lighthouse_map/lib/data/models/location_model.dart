import 'package:cloud_firestore/cloud_firestore.dart';

class LocationModel {
  final String locationId;
  final String userId;
  final String deviceId;
  final double latitude;
  final double longitude;
  final DateTime? timestamp;
  final DateTime? createdAt;

  LocationModel({
    required this.locationId,
    required this.userId,
    required this.deviceId,
    required this.latitude,
    required this.longitude,
    this.timestamp,
    this.createdAt,
  });

  factory LocationModel.fromMap(Map<String, dynamic> map) {
    return LocationModel(
      locationId: map['location_id'] ?? '',
      userId: map['user_id'] ?? '',
      deviceId: map['device_id'] ?? '',
      latitude: (map['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 0.0,
      timestamp: map['timestamp'] != null ? (map['timestamp'] as Timestamp).toDate() : null,
      createdAt: map['created_at'] != null ? (map['created_at'] as Timestamp).toDate() : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'location_id': locationId,
      'user_id': userId,
      'device_id': deviceId,
      'latitude': latitude,
      'longitude': longitude,
      'timestamp': timestamp,
      'created_at': createdAt,
    };
  }
}