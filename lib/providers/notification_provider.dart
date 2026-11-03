import 'dart:async';

import 'package:flutter/foundation.dart';
import '../models/notification_model.dart';
import '../services/group_service.dart';
import '../services/notification_service.dart';

class NotificationProvider with ChangeNotifier {

  final GroupService _groupService = GroupService();
  final NotificationService _notificationService = NotificationService();

  List<NotificationModel> _notifications = [];
  bool _isLoading = false;
  StreamSubscription<List<NotificationModel>>? _subscription;

  List<NotificationModel> get notifications => _notifications;
  int get unreadCount =>
      _notifications.where((n) => !n.read && n.status == 'pending').length;
  bool get isLoading => _isLoading;

  void listenToNotifications(String uid) {
    _subscription?.cancel();
    _isLoading = true;
    notifyListeners();

    _subscription = _notificationService.getUserNotificationsStream(uid).listen(
      (data) {
        _notifications = data;
        _isLoading = false;
        notifyListeners();
      },
      onError: (err) {
        _isLoading = false;
        notifyListeners();
      },
    );
  }

  // Alias for compatibility
  void fetchNotifications(String uid) {
    listenToNotifications(uid);
  }

  Future<void> acceptInvitation(NotificationModel notification, String uid, {String? username}) async {
    _isLoading = true;
    notifyListeners();

    try {
      // Add user B to group members & post group activity
      await _groupService.joinGroup(notification.groupId, uid, username: username);

      // Update invitation status = accepted & mark as read
      await _notificationService.updateInvitationStatus(uid, notification.notificationId, 'accepted');

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> acceptGroupInvite(NotificationModel notification, String uid, {String? username}) async {
    await acceptInvitation(notification, uid, username: username);
  }

  Future<void> declineInvitation(NotificationModel notification, String uid) async {
    _isLoading = true;
    notifyListeners();

    try {
      // Update invitation status = declined & mark as read
      await _notificationService.updateInvitationStatus(uid, notification.notificationId, 'declined');

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> declineGroupInvite(NotificationModel notification, String uid) async {
    await declineInvitation(notification, uid);
  }

  void resetState() {
    _subscription?.cancel();
    _subscription = null;
    _notifications = [];
    _isLoading = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
