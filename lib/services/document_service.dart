import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/document_model.dart';

class DocumentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Upload file to Firebase Storage and save document metadata to Firestore
  Future<void> uploadGroupDocument({
    required String groupId,
    required File file,
    required String fileName,
    required String uploaderName,
  }) async {
    final storageRef = _storage
        .ref()
        .child('groups/$groupId/docs/${DateTime.now().millisecondsSinceEpoch}_$fileName');

    final uploadTask = await storageRef.putFile(file);
    final downloadUrl = await uploadTask.ref.getDownloadURL();

    final docRef = _firestore
        .collection('groups')
        .doc(groupId)
        .collection('documents')
        .doc();

    final docModel = DocumentModel(
      documentId: docRef.id,
      fileName: fileName,
      fileUrl: downloadUrl,
      uploadedBy: uploaderName,
      uploaderUsername: uploaderName,
      fileSize: await file.length(),
      timestamp: DateTime.now(),
    );

    await docRef.set(docModel.toMap());
  }

  /// Stream group documents sorted by timestamp descending
  Stream<List<DocumentModel>> getGroupDocuments(String groupId) {
    return _firestore
        .collection('groups')
        .doc(groupId)
        .collection('documents')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => DocumentModel.fromMap(doc.data(), doc.id))
            .toList());
  }
}
