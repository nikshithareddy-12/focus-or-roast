import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/group_model.dart';
import '../models/message_model.dart';
import '../models/document_model.dart';
import '../services/group_service.dart';

class GroupProvider with ChangeNotifier {
  final GroupService _groupService = GroupService();

  List<GroupModel> _myGroups = [];
  List<GroupModel> _publicGroups = [];
  List<GroupModel> _filteredPublicGroups = [];
  List<MessageModel> _activeChatMessages = [];
  List<DocumentModel> _activeGroupDocuments = [];

  bool _isLoading = false;
  String? _errorMessage;
  String _searchQuery = '';

  StreamSubscription<List<GroupModel>>? _myGroupsSub;
  StreamSubscription<List<GroupModel>>? _publicGroupsSub;
  StreamSubscription<List<Map<String, dynamic>>>? _chatMessagesSub;
  StreamSubscription<List<Map<String, dynamic>>>? _groupDocumentsSub;

  List<GroupModel> get myGroups => _myGroups;
  List<GroupModel> get publicGroups => _searchQuery.isEmpty ? _publicGroups : _filteredPublicGroups;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  List<MessageModel> get activeChatMessages => _activeChatMessages;
  List<DocumentModel> get activeGroupDocuments => _activeGroupDocuments;

  void listenToChatMessages(String groupId) {
    _chatMessagesSub?.cancel();
    _chatMessagesSub = _groupService.getChatMessages(groupId).listen((list) {
      _activeChatMessages = list.map((m) => MessageModel.fromMap(m, m['id'] ?? '')).toList();
      notifyListeners();
    });
  }

  void listenToGroupDocuments(String groupId) {
    _groupDocumentsSub?.cancel();
    _groupDocumentsSub = _groupService.getGroupDocuments(groupId).listen((list) {
      _activeGroupDocuments = list.map((d) => DocumentModel.fromMap(d, d['id'] ?? '')).toList();
      notifyListeners();
    });
  }

  Future<void> sendMessage({
    required String groupId,
    required String senderId,
    required String senderName,
    required String senderUsername,
    required String content,
    String? fileUrl,
    String? fileName,
    int? fileSize,
    String? fileType,
  }) async {
    try {
      await _groupService.sendChatMessage(
        groupId: groupId,
        senderId: senderId,
        senderName: senderName,
        senderUsername: senderUsername,
        content: content,
        fileUrl: fileUrl,
        fileName: fileName,
        fileSize: fileSize,
        fileType: fileType,
      );
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// Sends a file message directly to the group chat and saves it to documents
  Future<bool> sendFileMessage({
    required String groupId,
    required String senderId,
    required String senderName,
    required String senderUsername,
    required PlatformFile pickedFile,
    String? caption,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final fileName = pickedFile.name;
      final filePath = pickedFile.path;
      int fileSize = pickedFile.size;
      if (fileSize == 0 && filePath != null && filePath.isNotEmpty) {
        try {
          fileSize = File(filePath).lengthSync();
        } catch (_) {}
      }
      final extension = pickedFile.extension?.toLowerCase() ?? 'file';
      final contentType = _getContentType(extension);
      final metadata = SettableMetadata(contentType: contentType);

      final storageRef = FirebaseStorage.instance
          .ref()
          .child('groups/$groupId/files/${DateTime.now().millisecondsSinceEpoch}_$fileName');
          
      print('[FocusRoast_Diag] Firebase Storage path created: ${storageRef.fullPath}');
      print('[FocusRoast_Diag] Firebase Storage bucket: ${storageRef.bucket}');

      TaskSnapshot snapshot;
      if (filePath != null && filePath.isNotEmpty && File(filePath).existsSync()) {
        final file = File(filePath);
        print('[FocusRoast_Diag] Uploading from local file path: $filePath');
        snapshot = await storageRef.putFile(file, metadata);
      } else {
        print('[FocusRoast_Diag] Reading file bytes via pickedFile.readAsBytes()...');
        final fileBytes = await pickedFile.readAsBytes();
        if (fileSize == 0) {
          fileSize = fileBytes.length;
        }
        snapshot = await storageRef.putData(fileBytes, metadata);
      }

      print('[FocusRoast_Diag] Upload complete. Task state: ${snapshot.state}. Requesting download URL...');
      final downloadUrl = await snapshot.ref.getDownloadURL();
      print('[FocusRoast_Diag] Download URL received: $downloadUrl');

      // 1. Save chat message with file attachment
      await _groupService.sendChatMessage(
        groupId: groupId,
        senderId: senderId,
        senderName: senderName,
        senderUsername: senderUsername,
        content: (caption != null && caption.trim().isNotEmpty) ? caption.trim() : fileName,
        fileUrl: downloadUrl,
        fileName: fileName,
        fileSize: fileSize,
        fileType: extension,
      );

      // 2. Also register in group documents for file history
      await _groupService.addDocumentMetadata(
        groupId: groupId,
        fileName: fileName,
        fileUrl: downloadUrl,
        uploaderId: senderId,
        uploaderUsername: senderUsername,
        fileSize: fileSize,
      );

      _isLoading = false;
      notifyListeners();
      return true;
    } on FirebaseException catch (e) {
      print('[FocusRoast_Diag] FirebaseException during upload: code=${e.code}, message=${e.message}');
      if (e.code == 'object-not-found') {
        _errorMessage = 'Firebase Storage bucket (${FirebaseStorage.instance.bucket}) is not provisioned or active in Firebase Console.';
      } else {
        _errorMessage = 'Failed to upload file: ${e.message ?? e.toString()}';
      }
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      print('[FocusRoast_Diag] Upload exception: $e');
      _errorMessage = 'Failed to upload/send file: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  String _getContentType(String extension) {
    switch (extension) {
      case 'pdf':
        return 'application/pdf';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'ppt':
        return 'application/vnd.ms-powerpoint';
      case 'pptx':
        return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
      case 'txt':
        return 'text/plain';
      case 'csv':
        return 'text/csv';
      case 'xls':
        return 'application/vnd.ms-excel';
      case 'xlsx':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      default:
        return 'application/octet-stream';
    }
  }

  /// Opens the Android file picker, uploads the selected file to Firebase Storage,
  /// and saves the real metadata (fileName, downloadUrl, fileSize) to Firestore and Chat.
  Future<bool> uploadDocument({
    required String groupId,
    required String uploaderId,
    required String uploaderName,
  }) async {
    try {
      // 1. Open the real Android file picker â€” supports common document & image formats
      final pickedFile = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: [
          'pdf', 'doc', 'docx', 'ppt', 'pptx',
          'txt', 'xls', 'xlsx', 'csv',
          'jpg', 'jpeg', 'png',
        ],
      );

      // 2. User cancelled the picker — do NOT upload anything.
      if (pickedFile == null) return false;

      return await sendFileMessage(
        groupId: groupId,
        senderId: uploaderId,
        senderName: uploaderName,
        senderUsername: uploaderName,
        pickedFile: pickedFile,
        caption: pickedFile.name,
      );
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  void listenToMyGroups(String uid) {
    _myGroupsSub?.cancel();
    _myGroupsSub = _groupService.getMyGroups(uid).listen((groups) {
      _myGroups = groups;
      notifyListeners();
    });
  }

  void listenToPublicGroups() {
    _publicGroupsSub?.cancel();
    _publicGroupsSub = _groupService.getPublicGroups().listen((groups) {
      _publicGroups = groups;
      _applySearch();
      notifyListeners();
    });
  }

  void searchPublicGroups(String query) {
    _searchQuery = query.toLowerCase().trim();
    _applySearch();
    notifyListeners();
  }

  void _applySearch() {
    if (_searchQuery.isEmpty) {
      _filteredPublicGroups = _publicGroups;
    } else {
      _filteredPublicGroups = _publicGroups
          .where((g) => g.name.toLowerCase().contains(_searchQuery) ||
              g.description.toLowerCase().contains(_searchQuery))
          .toList();
    }
  }

  GroupModel? _lastCreatedGroup;
  GroupModel? get lastCreatedGroup => _lastCreatedGroup;

  Future<bool> createGroup({
    required String name,
    required String description,
    required bool isPublic,
    required String creatorUid,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    _lastCreatedGroup = null;
    notifyListeners();

    try {
      final group = await _groupService.createGroup(
        name: name,
        description: description,
        isPublic: isPublic,
        creatorUid: creatorUid,
      );
      _lastCreatedGroup = group;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> inviteUser({
    required String targetUsername,
    required GroupModel group,
    required String senderUid,
    required String senderUsername,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _groupService.inviteUserToGroup(
        targetUsername: targetUsername,
        group: group,
        senderUid: senderUid,
        senderUsername: senderUsername,
      );
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> joinGroup(String groupId, String uid, {String? username}) async {
    try {
      await _groupService.joinGroup(groupId, uid, username: username);
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  void resetState() {
    _myGroupsSub?.cancel();
    _publicGroupsSub?.cancel();
    _chatMessagesSub?.cancel();
    _groupDocumentsSub?.cancel();
    _myGroupsSub = null;
    _publicGroupsSub = null;
    _chatMessagesSub = null;
    _groupDocumentsSub = null;
    _myGroups = [];
    _publicGroups = [];
    _filteredPublicGroups = [];
    _activeChatMessages = [];
    _activeGroupDocuments = [];
    _searchQuery = '';
    _errorMessage = null;
    _isLoading = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _myGroupsSub?.cancel();
    _publicGroupsSub?.cancel();
    _chatMessagesSub?.cancel();
    _groupDocumentsSub?.cancel();
    super.dispose();
  }
}
