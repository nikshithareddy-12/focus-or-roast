import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/group_model.dart';
import '../models/user_model.dart';

class GroupService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Create a new study group
  Future<GroupModel> createGroup({
    required String name,
    required String description,
    required bool isPublic,
    required String creatorUid,
  }) async {
    final docRef = _firestore.collection('groups').doc();
    final group = GroupModel(
      groupId: docRef.id,
      name: name.trim(),
      description: description.trim(),
      isPublic: isPublic,
      createdBy: creatorUid,
      createdAt: DateTime.now(),
      members: [creatorUid],
    );

    await docRef.set(group.toMap());
    return group;
  }

  /// Resolve a user by exact username for invitation.
  /// Uses the public `Usernames/{username}` index for O(1) uid lookup, then the
  /// public `publicProfiles/{uid}` projection for the safe display/privacy
  /// fields. Neither read requires access to another user's private profile,
  /// so this works under the default-deny security rules.
  ///
  /// The returned UserModel carries only public fields (uid, username, name,
  /// totalFocusMinutes, allowGroupInvites); email and distractionApps are empty.
  Future<UserModel?> findUserByUsername(String username) async {
    final clean = username.toLowerCase().trim();
    if (clean.isEmpty) return null;

    final usernameDoc = await _firestore.collection('Usernames').doc(clean).get();
    if (!usernameDoc.exists) return null;

    final uid = usernameDoc.data()?['uid'] as String?;
    if (uid == null || uid.isEmpty) return null;

    final profileDoc = await _firestore.collection('publicProfiles').doc(uid).get();
    if (profileDoc.exists && profileDoc.data() != null) {
      return UserModel.fromMap(profileDoc.data()!, profileDoc.id);
    }

    // Public profile not yet backfilled for this user: fall back to the minimal
    // identity we already have from the username index. allowGroupInvites
    // defaults to true on the model, matching the pre-existing behaviour.
    return UserModel(
      uid: uid,
      name: clean,
      username: clean,
      email: '',
      distractionApps: const [],
      allowGroupInvites: true,
      createdAt: DateTime.now(),
    );
  }

  /// Invite a user to a group by username (creates a notification in invited user's document collection)
  Future<void> inviteUserToGroup({
    required String targetUsername,
    required GroupModel group,
    required String senderUid,
    required String senderUsername,
  }) async {
    final targetUser = await findUserByUsername(targetUsername);

    if (targetUser == null) {
      throw Exception('User "$targetUsername" not found.');
    }

    if (!targetUser.allowGroupInvites) {
      throw Exception('User "$targetUsername" has disabled group invitations in their privacy settings.');
    }

    if (group.members.contains(targetUser.uid)) {
      throw Exception('User "$targetUsername" is already a member of this group.');
    }

    final notifRef = _firestore
        .collection('users')
        .doc(targetUser.uid)
        .collection('notifications')
        .doc();

    await notifRef.set({
      'notificationId': notifRef.id,
      'recipientUid': targetUser.uid,
      'senderUid': senderUid,
      'senderUsername': senderUsername,
      'groupId': group.groupId,
      'groupName': group.name,
      'type': 'group_invitation',
      'createdAt': FieldValue.serverTimestamp(),
      'read': false,
      'status': 'pending',
    });
  }

  /// Stream My Groups (groups where user's uid is in `members` list)
  Stream<List<GroupModel>> getMyGroups(String uid) {
    return _firestore
        .collection('groups')
        .where('members', arrayContains: uid)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => GroupModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  /// Stream Public Groups (groups where `isPublic` == true)
  Stream<List<GroupModel>> getPublicGroups() {
    return _firestore
        .collection('groups')
        .where('isPublic', isEqualTo: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => GroupModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  /// Join a public group
  Future<void> joinGroup(String groupId, String uid, {String? username}) async {
    await _firestore.collection('groups').doc(groupId).update({
      'members': FieldValue.arrayUnion([uid]),
    });
    if (username != null && username.isNotEmpty) {
      await addGroupActivity(
        groupId: groupId,
        userUid: uid,
        message: '@$username joined the group.',
      );
    }
  }

  /// Add activity log to group activities collection
  Future<void> addGroupActivity({
    required String groupId,
    required String userUid,
    required String message,
  }) async {
    await _firestore
        .collection('groups')
        .doc(groupId)
        .collection('activities')
        .add({
      'userUid': userUid,
      'message': message,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Send chat message in group (supports both text and file messages)
  Future<void> sendChatMessage({
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
    final docRef = _firestore
        .collection('groups')
        .doc(groupId)
        .collection('messages')
        .doc();

    final data = <String, dynamic>{
      'messageId': docRef.id,
      'senderId': senderId,
      'senderName': senderName,
      'senderUsername': senderUsername,
      'content': content.trim(),
      // Use Timestamp.now() instead of FieldValue.serverTimestamp() so the
      // message immediately appears in orderBy('timestamp') queries.
      // FieldValue.serverTimestamp() produces a null local value until the
      // server round-trip completes, which excludes the doc from ordered results.
      'timestamp': Timestamp.now(),
    };

    if (fileUrl != null && fileUrl.isNotEmpty) {
      data['fileUrl'] = fileUrl;
      data['fileName'] = fileName ?? 'Attachment';
      data['fileSize'] = fileSize ?? 0;
      data['fileType'] = fileType ?? 'file';
    }

    await docRef.set(data);
  }

  /// Stream group chat messages (ordered by timestamp descending for chat UI)
  Stream<List<Map<String, dynamic>>> getChatMessages(String groupId) {
    return _firestore
        .collection('groups')
        .doc(groupId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
              final data = doc.data();
              data['id'] = doc.id;
              return data;
            }).toList());
  }

  /// Add document metadata to group documents collection
  Future<void> addDocumentMetadata({
    required String groupId,
    required String fileName,
    required String fileUrl,
    required String uploaderId,
    required String uploaderUsername,
    required int fileSize,
  }) async {
    final docRef = _firestore
        .collection('groups')
        .doc(groupId)
        .collection('documents')
        .doc();

    await docRef.set({
      'documentId': docRef.id,
      'fileName': fileName,
      'fileUrl': fileUrl,
      'uploadedBy': uploaderId,
      'uploaderUsername': uploaderUsername,
      'fileSize': fileSize,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  /// Stream group documents (ordered by timestamp descending)
  Stream<List<Map<String, dynamic>>> getGroupDocuments(String groupId) {
    return _firestore
        .collection('groups')
        .doc(groupId)
        .collection('documents')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
              final data = doc.data();
              data['id'] = doc.id;
              return data;
            }).toList());
  }
}
