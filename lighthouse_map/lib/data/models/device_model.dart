import 'package:cloud_firestore/cloud_firestore.dart';


class DeviceModel {
  final String deviceId;
  final String userId;
  final String? fcmToken;
  final String? platform;
  final String? model;
  final DateTime? createdAt;

  DeviceModel({
    required this.deviceId,
    required this.userId,
    this.fcmToken,
    this.platform,
    this.model,
    this.createdAt,
  });

  factory DeviceModel.fromMap(Map<String, dynamic> map) {
    return DeviceModel(
      deviceId: map['device_id'] ?? '',
      userId: map['user_id'] ?? '',
      fcmToken: map['fcm_token'],
      platform: map['platform'],
      model: map['model'],
      createdAt: map['created_at'] != null ? (map['created_at'] as Timestamp).toDate() : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'device_id': deviceId,
      'user_id': userId,
      'fcm_token': fcmToken,
      'platform': platform,
      'model': model,
      'created_at': createdAt,
    };
  }
}
