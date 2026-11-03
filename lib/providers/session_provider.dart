import 'dart:async';
import 'package:flutter/material.dart';
import '../models/focus_session.dart';
import '../services/session_service.dart';

class SessionProvider with ChangeNotifier {
  final SessionService _sessionService = SessionService();
  List<FocusSession> _userSessions = [];
  bool _isLoading = false;
  StreamSubscription<List<FocusSession>>? _subscription;

  List<FocusSession> get userSessions => _userSessions;
  bool get isLoading => _isLoading;

  void fetchSessions(String userId) {
    _subscription?.cancel();
    _isLoading = true;
    notifyListeners();

    _subscription = _sessionService.getUserSessionsStream(userId).listen((sessions) {
      _userSessions = sessions;
      _isLoading = false;
      notifyListeners();
    });
  }

  void resetState() {
    _subscription?.cancel();
    _subscription = null;
    _userSessions = [];
    _isLoading = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
