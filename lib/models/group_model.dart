import 'package:cloud_firestore/cloud_firestore.dart';

class GroupModel {
  final String groupId;
  final String name;
  final String description;
  final bool isPublic;
  final String createdBy;
  final DateTime createdAt;
  final List<String> members;

  GroupModel({
    required this.groupId,
    required this.name,
    required this.description,
    this.isPublic = true,
    required this.createdBy,
    required this.createdAt,
    required this.members,
  });

  Map<String, dynamic> toMap() {
    return {
      'groupId': groupId,
      'name': name,
      'description': description,
      'isPublic': isPublic,
      'createdBy': createdBy,
      'createdAt': createdAt.toIso8601String(),
      'members': members,
    };
  }

  Map<String, dynamic> toFirestoreMap() {
    return {
      'groupId': groupId,
      'name': name,
      'description': description,
      'isPublic': isPublic,
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'members': members,
    };
  }

  factory GroupModel.fromMap(Map<String, dynamic> map, String id) {
    DateTime parsedCreatedAt = DateTime.now();
    final raw = map['createdAt'];
    if (raw is Timestamp) {
      parsedCreatedAt = raw.toDate();
    } else if (raw is String) {
      parsedCreatedAt = DateTime.tryParse(raw) ?? DateTime.now();
    } else if (raw is int) {
      parsedCreatedAt = DateTime.fromMillisecondsSinceEpoch(raw);
    }

    return GroupModel(
      groupId: id.isNotEmpty ? id : (map['groupId'] ?? ''),
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      isPublic: map['isPublic'] ?? true,
      createdBy: map['createdBy'] ?? '',
      createdAt: parsedCreatedAt,
      members: List<String>.from(map['members'] ?? []),
    );
  }
}
