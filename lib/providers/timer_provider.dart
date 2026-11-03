import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/achievement_model.dart';
import '../models/focus_session.dart';
import '../services/achievement_service.dart';
import '../services/firestore_service.dart';

/// Lifecycle phase of the single authoritative focus session.
///
/// Only [TimerProvider] mutates this. Screens observe it and never own a
/// competing copy of the session state.
enum TimerState { idle, focusRunning, focusPaused, breakRunning, breakPaused, completed }

/// Wired by the composition root (HomeScreen) so that [TimerProvider] can start
/// and stop native distraction monitoring on every lifecycle transition, even
/// when no screen is currently mounted.
typedef MonitoringStartHandler = void Function(
  List<String> apps,
  String subject,
  int durationMinutes,
);
typedef MonitoringStopHandler = void Function();

class TimerProvider with ChangeNotifier {
  // Lazily created so constructing the provider never touches Firebase eagerly;
  // every use site is wrapped in try/catch, so persistence failures are
  // swallowed without corrupting session state.
  FirestoreService? _firestoreServiceInstance;
  FirestoreService get _firestoreService =>
      _firestoreServiceInstance ??= FirestoreService();

  // ---- Configuration (the NEXT session's preferences; editable only while idle) ----
  String _selectedSubject = 'General';
  int _focusDurationMinutes = 30;
  int _numberOfBreaks = 1;
  int _breakDurationMinutes = 5;

  // ---- Captured, immutable config for the ACTIVE session ----
  // Snapshot taken at start so the running timer, the progress UI and the
  // native monitor can never diverge from what the user actually selected.
  String _sessionSubject = 'General';
  int _sessionFocusDurationMinutes = 30;
  int _sessionNumberOfBreaks = 1;
  int _sessionBreakDurationMinutes = 5;

  // ---- Runtime state ----
  TimerState _state = TimerState.idle;
  int _focusRemainingSeconds = 30 * 60;
  int _breakRemainingSeconds = 5 * 60;
  int _currentBreakIndex = 0;
  int _breaksCompleted = 0;
  int _distractionCount = 0;

  DateTime? _sessionStartTime;
  String? _currentSessionId;
  String? _userId;
  AchievementModel? _latestAchievement;

  Timer? _ticker;

  // Guarantees a session is written to Firestore at most once.
  bool _sessionPersisted = false;

  // Native monitoring lifecycle, owned here so stop always runs.
  MonitoringStartHandler? _onMonitoringStart;
  MonitoringStopHandler? _onMonitoringStop;
  bool _monitoringActive = false;

  // ---- Getters: configuration ----
  String get selectedSubject => _selectedSubject;
  int get focusDurationMinutes => _focusDurationMinutes;
  int get numberOfBreaks => _numberOfBreaks;
  int get breakDurationMinutes => _breakDurationMinutes;

  // ---- Getters: active-session (captured) config ----
  String get sessionSubject => _sessionSubject;
  int get sessionFocusDurationMinutes => _sessionFocusDurationMinutes;
  int get sessionNumberOfBreaks => _sessionNumberOfBreaks;
  int get sessionBreakDurationMinutes => _sessionBreakDurationMinutes;

  // ---- Getters: runtime ----
  TimerState get state => _state;
  int get focusRemainingSeconds => _focusRemainingSeconds;
  int get breakRemainingSeconds => _breakRemainingSeconds;
  int get currentBreakIndex => _currentBreakIndex;
  int get breaksCompleted => _breaksCompleted;
  int get distractionCount => _distractionCount;
  AchievementModel? get latestAchievement => _latestAchievement;

  bool get isFocusRunning => _state == TimerState.focusRunning;
  bool get isBreakRunning => _state == TimerState.breakRunning;

  /// True while a session is live (running or paused, focus or break).
  bool get isSessionActive =>
      _state == TimerState.focusRunning ||
      _state == TimerState.focusPaused ||
      _state == TimerState.breakRunning ||
      _state == TimerState.breakPaused;

  /// Bind the native monitoring start/stop hooks. Idempotent; the composition
  /// root calls this once. [TimerProvider] then drives monitoring itself.
  void bindMonitoring({
    required MonitoringStartHandler onStart,
    required MonitoringStopHandler onStop,
  }) {
    _onMonitoringStart = onStart;
    _onMonitoringStop = onStop;
  }

  // ---- Configuration updates (locked while a session is active) ----
  void setSubject(String subject) {
    if (isSessionActive) return;
    _selectedSubject = subject.trim().isEmpty ? 'General' : subject.trim();
    notifyListeners();
  }

  void setFocusDuration(int minutes) {
    if (isSessionActive) return;
    _focusDurationMinutes = minutes.clamp(1, 300);
    _focusRemainingSeconds = _focusDurationMinutes * 60;
    notifyListeners();
  }

  void incrementFocusDuration() {
    if (isSessionActive) return;
    if (_focusDurationMinutes < 300) {
      _focusDurationMinutes += 5;
      _focusRemainingSeconds = _focusDurationMinutes * 60;
      notifyListeners();
    }
  }

  void decrementFocusDuration() {
    if (isSessionActive) return;
    if (_focusDurationMinutes > 5) {
      _focusDurationMinutes -= 5;
      _focusRemainingSeconds = _focusDurationMinutes * 60;
      notifyListeners();
    }
  }

  void setNumberOfBreaks(int breaks) {
    if (isSessionActive) return;
    _numberOfBreaks = breaks.clamp(0, 5);
    notifyListeners();
  }

  void setBreakDuration(int minutes) {
    if (isSessionActive) return;
    _breakDurationMinutes = minutes.clamp(1, 30);
    _breakRemainingSeconds = _breakDurationMinutes * 60;
    notifyListeners();
  }

  void setUserId(String uid) {
    _userId = uid;
  }

  // ---- Session lifecycle ----

  /// Start the one authoritative focus session.
  ///
  /// Idempotent: if a session is already active this is a no-op and returns
  /// false, so a second call can never create a duplicate timer or monitor.
  /// Captures the current configuration into immutable session values, then
  /// starts native monitoring (via the bound hook) and the ticker.
  bool startFocusSession({required String uid, required List<String> distractionApps}) {
    if (isSessionActive) return false;
    if (uid.trim().isEmpty) return false;

    _userId = uid;

    // Snapshot config for this session — the source of truth from here on.
    _sessionSubject = _selectedSubject;
    _sessionFocusDurationMinutes = _focusDurationMinutes;
    _sessionNumberOfBreaks = _numberOfBreaks;
    _sessionBreakDurationMinutes = _breakDurationMinutes;

    _state = TimerState.focusRunning;
    _focusRemainingSeconds = _sessionFocusDurationMinutes * 60;
    _breakRemainingSeconds = _sessionBreakDurationMinutes * 60;
    _distractionCount = 0;
    _breaksCompleted = 0;
    _currentBreakIndex = 0;
    _latestAchievement = null;
    _sessionPersisted = false;
    _sessionStartTime = DateTime.now();
    _currentSessionId = 'sess_${_sessionStartTime!.millisecondsSinceEpoch}';

    _startMonitoring(distractionApps);
    _startTicker();
    notifyListeners();
    return true;
  }

  void pauseTimer() {
    if (_state == TimerState.focusRunning) {
      _state = TimerState.focusPaused;
      _ticker?.cancel();
      notifyListeners();
    } else if (_state == TimerState.breakRunning) {
      _state = TimerState.breakPaused;
      _ticker?.cancel();
      notifyListeners();
    }
  }

  void resumeTimer() {
    if (_state == TimerState.focusPaused) {
      _state = TimerState.focusRunning;
      _startTicker();
      notifyListeners();
    } else if (_state == TimerState.breakPaused) {
      _state = TimerState.breakRunning;
      _startTicker();
      notifyListeners();
    }
  }

  /// Increment the authoritative distraction count. Only counts while a
  /// session is live. Returns the new count so callers (roast flavour text)
  /// never need to keep a duplicate counter.
  int incrementDistractionCount() {
    if (!isSessionActive) return _distractionCount;
    _distractionCount++;
    notifyListeners();
    return _distractionCount;
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_state == TimerState.focusRunning) {
        if (_focusRemainingSeconds > 0) {
          _focusRemainingSeconds--;

          if (_sessionNumberOfBreaks > 0 && _breaksCompleted < _sessionNumberOfBreaks) {
            final interval = (_sessionFocusDurationMinutes * 60) / (_sessionNumberOfBreaks + 1);
            final nextBreakPoint = (_sessionFocusDurationMinutes * 60) - (interval * (_breaksCompleted + 1));
            if (_focusRemainingSeconds <= nextBreakPoint && _focusRemainingSeconds > 5) {
              startBreak();
              return;
            }
          }
          notifyListeners();
        } else {
          _completeSession();
        }
      } else if (_state == TimerState.breakRunning) {
        if (_breakRemainingSeconds > 0) {
          _breakRemainingSeconds--;
          notifyListeners();
        } else {
          _completeBreak();
        }
      }
    });
  }

  void startBreak() {
    if (_state != TimerState.focusRunning) return;
    _state = TimerState.breakRunning;
    _breakRemainingSeconds = _sessionBreakDurationMinutes * 60;
    notifyListeners();
  }

  void _completeBreak() {
    _breaksCompleted++;
    _currentBreakIndex++;
    _breakRemainingSeconds = _sessionBreakDurationMinutes * 60;
    _state = TimerState.focusRunning;
    notifyListeners();
  }

  void skipBreak() {
    if (_state == TimerState.breakRunning || _state == TimerState.breakPaused) {
      _completeBreak();
    }
  }

  /// Genuine completion: the focus timer reached zero. Produces exactly one
  /// completion flow (achievement + praise) and always stops monitoring.
  Future<void> _completeSession() async {
    _ticker?.cancel();
    _ticker = null;
    if (_state == TimerState.completed) return; // idempotent
    _state = TimerState.completed;
    _stopMonitoring();

    final achievement = AchievementService().getCompletionAchievement(
      focusMinutes: _sessionFocusDurationMinutes,
      distractionCount: _distractionCount,
    );
    _latestAchievement = achievement;

    notifyListeners();

    await _saveSession(completed: true);
    final uid = _userId;
    if (uid != null && uid.isNotEmpty) {
      try {
        await _firestoreService.saveAchievement(uid, achievement);
      } catch (_) {}
    }
  }

  /// User-initiated cancellation. Deterministic: ACTIVE -> idle, monitoring and
  /// ticker stopped, session saved once as interrupted. NEVER produces the
  /// praise/completion flow. Safe to call when already idle (no-op).
  Future<void> cancelSession() async {
    _ticker?.cancel();
    _ticker = null;
    if (_state == TimerState.idle) return;

    final wasCompleted = _state == TimerState.completed;
    _stopMonitoring();
    _state = TimerState.idle;
    notifyListeners();

    if (!wasCompleted) {
      await _saveSession(completed: false);
    }
    _resetRuntime();
  }

  /// Leave the praise screen after a genuine completion. The session was
  /// already persisted in [_completeSession], so this only returns to idle.
  void dismissCompleted() {
    _ticker?.cancel();
    _ticker = null;
    _stopMonitoring();
    _state = TimerState.idle;
    _resetRuntime();
    notifyListeners();
  }

  /// Full teardown on logout: stops monitoring, clears runtime AND config.
  void resetState() {
    _ticker?.cancel();
    _ticker = null;
    _stopMonitoring();
    _state = TimerState.idle;
    _selectedSubject = 'General';
    _focusDurationMinutes = 30;
    _numberOfBreaks = 1;
    _breakDurationMinutes = 5;
    _userId = null;
    _resetRuntime();
    notifyListeners();
  }

  void _resetRuntime() {
    _sessionStartTime = null;
    _currentSessionId = null;
    _sessionPersisted = false;
    _distractionCount = 0;
    _breaksCompleted = 0;
    _currentBreakIndex = 0;
    _latestAchievement = null;
    _focusRemainingSeconds = _focusDurationMinutes * 60;
    _breakRemainingSeconds = _breakDurationMinutes * 60;
  }

  void _startMonitoring(List<String> apps) {
    if (_monitoringActive) return; // idempotent — never start twice
    _monitoringActive = true;
    _onMonitoringStart?.call(apps, _sessionSubject, _sessionFocusDurationMinutes);
  }

  void _stopMonitoring() {
    if (!_monitoringActive) return; // idempotent — safe to call repeatedly
    _monitoringActive = false;
    _onMonitoringStop?.call();
  }

  Future<void> _saveSession({required bool completed}) async {
    if (_sessionPersisted) return; // exactly-once guard
    if (_userId == null || _sessionStartTime == null || _currentSessionId == null) return;
    _sessionPersisted = true;

    final endTime = DateTime.now();
    final actualDurationMinutes =
        (endTime.difference(_sessionStartTime!).inSeconds / 60).round().clamp(1, 300);

    final session = FocusSession(
      sessionId: _currentSessionId!,
      userId: _userId!,
      subject: _sessionSubject,
      plannedDuration: _sessionFocusDurationMinutes,
      actualDuration: actualDurationMinutes,
      numberOfBreaks: _sessionNumberOfBreaks,
      breakDuration: _sessionBreakDurationMinutes,
      breaksCompleted: _breaksCompleted,
      distractionCount: _distractionCount,
      completed: completed,
      startTime: _sessionStartTime!,
      endTime: endTime,
    );

    try {
      await _firestoreService.saveFocusSession(session);
    } catch (_) {}
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _ticker = null;
    super.dispose();
  }
}
