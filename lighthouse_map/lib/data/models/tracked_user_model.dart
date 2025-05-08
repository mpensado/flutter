import 'package:cloud_firestore/cloud_firestore.dart';

class TrackedUserModel {
  final String trackedUserId;
  final String trackerUserId;
  final DateTime? startTime;
  final DateTime? endTime;
  final DateTime? createdAt;
  final int? stopNotificationTimeout;
  final int? stopNotificationRadius;

  TrackedUserModel({
    required this.trackedUserId,
    required this.trackerUserId,
    this.startTime,
    this.endTime,
    this.createdAt,
    this.stopNotificationTimeout,
    this.stopNotificationRadius,
  });

  factory TrackedUserModel.fromMap(Map<String, dynamic> map) {
    return TrackedUserModel(
      trackedUserId: map['tracked_user_id'] ?? '',
      trackerUserId: map['tracker_user_id'] ?? '',
      startTime: map['start_time'] != null ? (map['start_time'] as Timestamp).toDate() : null,
      endTime: map['end_time'] != null ? (map['end_time'] as Timestamp).toDate() : null,
      createdAt: map['created_at'] != null ? (map['created_at'] as Timestamp).toDate() : null,
      stopNotificationTimeout: map['stop_notification_timeout'] as int?,
      stopNotificationRadius: map['stop_notification_radius'] as int?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'tracked_user_id': trackedUserId,
      'tracker_user_id': trackerUserId,
      'start_time': startTime,
      'end_time': endTime,
      'created_at': createdAt,
      'stop_notification_timeout': stopNotificationTimeout,
      'stop_notification_radius': stopNotificationRadius,
    };
  }

  @override
  String toString() {
    return 'TrackedUserModel{trackedUserId: $trackedUserId, trackerUserId: $trackerUserId, startTime: $startTime, endTime: $endTime, createdAt: $createdAt, stopNotificationTimeout: $stopNotificationTimeout, stopNotificationRadius: $stopNotificationRadius}';
  }
}