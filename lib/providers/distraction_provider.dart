import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/roast_model.dart';
import '../services/native_usage_service.dart';
import '../services/roast_service.dart';

/// Called when a distraction is detected. The implementation (wired to
/// [TimerProvider.incrementDistractionCount]) owns the authoritative count and
/// returns the new value so this provider never keeps a duplicate counter.
typedef DistractionHandler = int Function(String packageName);

class DistractionProvider with ChangeNotifier {
  final RoastService _roastService = RoastService();
  StreamSubscription<String>? _subscription;

  bool _isQuizActive = false;
  RoastModel? _latestRoast;
  String? _detectedPackage;
  bool _showRoastOverlay = false;
  Set<String> _blockedPackages = {};

  // Active-session context supplied by the authoritative owner (TimerProvider).
  bool _sessionActive = false;
  String _sessionSubject = 'General';
  DistractionHandler? _onDistraction;

  RoastModel? get latestRoast => _latestRoast;
  String? get detectedPackage => _detectedPackage;
  bool get showRoastOverlay => _showRoastOverlay;
  bool get isQuizActive => _isQuizActive;
  Set<String> get blockedPackages => _blockedPackages;

  DistractionProvider() {
    _init();
  }

  void _init() async {
    await _roastService.loadRoasts();
    await _loadBlockedPackages();
  }

  Future<void> _loadBlockedPackages() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String>? list = prefs.getStringList('blocked_packages');
    _blockedPackages = (list ?? []).toSet();
    notifyListeners();
  }

  Future<void> _saveBlockedPackages() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('blocked_packages', _blockedPackages.toList());
  }

  void updateBlockedPackages(Set<String> packages) async {
    _blockedPackages = packages;
    await _saveBlockedPackages();
    notifyListeners();
  }

  void setQuizActive(bool active) {
    _isQuizActive = active;
    notifyListeners();
  }

  /// Start monitoring distraction apps for the active focus session.
  ///
  /// Fully decoupled from [TimerProvider]: the authoritative owner passes the
  /// captured session [subject]/[durationMinutes] and an [onDistraction]
  /// handler that increments (and returns) the authoritative distraction count.
  void startMonitoring(
    List<String> distractionApps, {
    required String subject,
    required int durationMinutes,
    required DistractionHandler onDistraction,
  }) {
    // Combine user-selected blocked packages with the provided list, or sensible defaults
    final Set<String> combined = {...distractionApps, ..._blockedPackages};
    final List<String> packagesToMonitor = combined.isNotEmpty
        ? combined.toList()
        : const [
            'com.instagram.android',
            'com.google.android.youtube',
            'com.whatsapp',
            'com.snapchat.android',
            'com.facebook.katana',
          ];

    _sessionActive = true;
    _sessionSubject = subject;
    _onDistraction = onDistraction;

    print('[FocusRoast_Diag] DistractionProvider: startMonitoring for packages: $packagesToMonitor (subject: $subject, duration: $durationMinutes)');

    NativeUsageService.startMonitoring(
      packagesToMonitor,
      subject: subject,
      durationMinutes: durationMinutes,
    );

    _subscription?.cancel();
    _subscription = NativeUsageService.distractionStream.listen((packageName) {
      print('[FocusRoast_Diag] Distraction stream received event: $packageName');
      _onDistractionEventDetected(packageName);
    });
  }

  /// Handle a distraction package event from the Kotlin detector.
  void _onDistractionEventDetected(String packageName) {
    // Ignore events while the quiz sub-flow is active or no session is live.
    if (_isQuizActive || !_sessionActive) {
      return;
    }

    _detectedPackage = packageName;
    // The authoritative count lives in TimerProvider; use the returned value
    // for roast escalation instead of duplicating state here.
    final newCount = _onDistraction?.call(packageName) ?? 0;
    _latestRoast = _roastService.getRandomRoast(
      distractionCount: newCount,
      subject: _sessionSubject,
    );
    // NOTE: the native BlockActivity is the real roast UI. We intentionally do
    // not raise a competing Flutter roast overlay here; notifyListeners only
    // lets observers react to the updated roast/count.
    notifyListeners();
  }

  void dismissRoastOverlay() {
    _showRoastOverlay = false;
    notifyListeners();
  }

  /// Stop monitoring. Idempotent — safe to call from multiple teardown paths.
  void stopMonitoring() {
    _sessionActive = false;
    _onDistraction = null;
    _subscription?.cancel();
    _subscription = null;
    NativeUsageService.stopMonitoring();
    _showRoastOverlay = false;
    notifyListeners();
  }

  void resetState() {
    stopMonitoring();
    _latestRoast = null;
    _detectedPackage = null;
    _isQuizActive = false;
    _showRoastOverlay = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
