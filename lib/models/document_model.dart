import 'package:cloud_firestore/cloud_firestore.dart';

class DocumentModel {
  final String documentId;
  final String fileName;
  final String fileUrl;
  final String uploadedBy;
  final String uploaderUsername;
  final int fileSize;
  final DateTime timestamp;

  DocumentModel({
    required this.documentId,
    required this.fileName,
    required this.fileUrl,
    required this.uploadedBy,
    required this.uploaderUsername,
    required this.fileSize,
    required this.timestamp,
  });

  String get title => fileName;
  String get uploaderName => uploaderUsername.isNotEmpty ? uploaderUsername : uploadedBy;
  DateTime get uploadedAt => timestamp;

  Map<String, dynamic> toMap() {
    return {
      'documentId': documentId,
      'fileName': fileName,
      'fileUrl': fileUrl,
      'uploadedBy': uploadedBy,
      'uploaderUsername': uploaderUsername,
      'fileSize': fileSize,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  Map<String, dynamic> toFirestoreMap() {
    return {
      'documentId': documentId,
      'fileName': fileName,
      'fileUrl': fileUrl,
      'uploadedBy': uploadedBy,
      'uploaderUsername': uploaderUsername,
      'fileSize': fileSize,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }

  factory DocumentModel.fromMap(Map<String, dynamic> map, String id) {
    DateTime parsedTimestamp = DateTime.now();
    final raw = map['timestamp'];
    if (raw is Timestamp) {
      parsedTimestamp = raw.toDate();
    } else if (raw is String) {
      parsedTimestamp = DateTime.tryParse(raw) ?? DateTime.now();
    } else if (raw is int) {
      parsedTimestamp = DateTime.fromMillisecondsSinceEpoch(raw);
    }

    return DocumentModel(
      documentId: id.isNotEmpty ? id : (map['documentId'] ?? ''),
      fileName: map['fileName'] ?? 'Document',
      fileUrl: map['fileUrl'] ?? '',
      uploadedBy: map['uploadedBy'] ?? '',
      uploaderUsername: map['uploaderUsername'] ?? map['uploadedBy'] ?? 'User',
      fileSize: (map['fileSize'] as num?)?.toInt() ?? 0,
      timestamp: parsedTimestamp,
    );
  }
}
