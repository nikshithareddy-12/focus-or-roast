import 'package:cloud_firestore/cloud_firestore.dart';

class MessageModel {
  final String messageId;
  final String senderId;
  final String senderName;
  final String senderUsername;
  final String content;
  final DateTime timestamp;
  final String? fileUrl;
  final String? fileName;
  final int? fileSize;
  final String? fileType;

  MessageModel({
    required this.messageId,
    required this.senderId,
    required this.senderName,
    required this.senderUsername,
    required this.content,
    required this.timestamp,
    this.fileUrl,
    this.fileName,
    this.fileSize,
    this.fileType,
  });

  bool get isFile => fileUrl != null && fileUrl!.isNotEmpty;

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'messageId': messageId,
      'senderId': senderId,
      'senderName': senderName,
      'senderUsername': senderUsername,
      'content': content,
      'timestamp': timestamp.toIso8601String(),
    };
    if (fileUrl != null) map['fileUrl'] = fileUrl;
    if (fileName != null) map['fileName'] = fileName;
    if (fileSize != null) map['fileSize'] = fileSize;
    if (fileType != null) map['fileType'] = fileType;
    return map;
  }

  Map<String, dynamic> toFirestoreMap() {
    final map = <String, dynamic>{
      'messageId': messageId,
      'senderId': senderId,
      'senderName': senderName,
      'senderUsername': senderUsername,
      'content': content,
      'timestamp': Timestamp.fromDate(timestamp),
    };
    if (fileUrl != null) map['fileUrl'] = fileUrl;
    if (fileName != null) map['fileName'] = fileName;
    if (fileSize != null) map['fileSize'] = fileSize;
    if (fileType != null) map['fileType'] = fileType;
    return map;
  }

  factory MessageModel.fromMap(Map<String, dynamic> map, String id) {
    DateTime parsedTimestamp = DateTime.now();
    final raw = map['timestamp'];
    if (raw is Timestamp) {
      parsedTimestamp = raw.toDate();
    } else if (raw is String) {
      parsedTimestamp = DateTime.tryParse(raw) ?? DateTime.now();
    } else if (raw is int) {
      parsedTimestamp = DateTime.fromMillisecondsSinceEpoch(raw);
    }

    int? parsedSize;
    if (map['fileSize'] is int) {
      parsedSize = map['fileSize'] as int;
    } else if (map['fileSize'] is num) {
      parsedSize = (map['fileSize'] as num).toInt();
    }

    return MessageModel(
      messageId: id.isNotEmpty ? id : (map['messageId'] ?? ''),
      senderId: map['senderId'] ?? '',
      senderName: map['senderName'] ?? 'Anonymous',
      senderUsername: map['senderUsername'] ?? map['senderName'] ?? 'user',
      content: map['content'] ?? '',
      timestamp: parsedTimestamp,
      fileUrl: map['fileUrl'] as String?,
      fileName: map['fileName'] as String?,
      fileSize: parsedSize,
      fileType: map['fileType'] as String?,
    );
  }
}
