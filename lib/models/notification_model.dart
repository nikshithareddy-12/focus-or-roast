import 'package:cloud_firestore/cloud_firestore.dart';

enum NotificationStatus { pending, accepted, declined }

class NotificationModel {
  final String notificationId;
  final String recipientUid;
  final String senderUid;
  final String senderUsername;
  final String groupId;
  final String groupName;
  final String type; // "group_invitation"
  final DateTime createdAt;
  final bool read;
  final String status; // "pending", "accepted", "declined"

  NotificationModel({
    required this.notificationId,
    required this.recipientUid,
    required this.senderUid,
    required this.senderUsername,
    required this.groupId,
    required this.groupName,
    this.type = 'group_invitation',
    required this.createdAt,
    this.read = false,
    this.status = 'pending',
  });

  // Compatibility getters for legacy code
  DateTime get timestamp => createdAt;
  String get senderName => senderUsername;
  bool get isRead => read;

  Map<String, dynamic> toMap() {
    return {
      'notificationId': notificationId,
      'recipientUid': recipientUid,
      'senderUid': senderUid,
      'senderUsername': senderUsername,
      'groupId': groupId,
      'groupName': groupName,
      'type': type,
      'createdAt': createdAt.toIso8601String(),
      'read': read,
      'status': status,
    };
  }

  Map<String, dynamic> toFirestoreMap() {
    return {
      'notificationId': notificationId,
      'recipientUid': recipientUid,
      'senderUid': senderUid,
      'senderUsername': senderUsername,
      'groupId': groupId,
      'groupName': groupName,
      'type': type,
      'createdAt': Timestamp.fromDate(createdAt),
      'read': read,
      'status': status,
    };
  }

  factory NotificationModel.fromMap(Map<String, dynamic> map, String id) {
    DateTime parseDate() {
      final raw = map['createdAt'] ?? map['timestamp'];
      if (raw is Timestamp) return raw.toDate();
      if (raw is String) return DateTime.tryParse(raw) ?? DateTime.now();
      if (raw is int) return DateTime.fromMillisecondsSinceEpoch(raw);
      return DateTime.now();
    }

    return NotificationModel(
      notificationId: id.isNotEmpty ? id : (map['notificationId'] ?? ''),
      recipientUid: map['recipientUid'] ?? '',
      senderUid: map['senderUid'] ?? '',
      senderUsername: map['senderUsername'] ?? '',
      groupId: map['groupId'] ?? '',
      groupName: map['groupName'] ?? '',
      type: map['type'] ?? 'group_invitation',
      createdAt: parseDate(),
      read: map['read'] ?? map['isRead'] ?? false,
      status: map['status'] ?? 'pending',
    );
  }
}
