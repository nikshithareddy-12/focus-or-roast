import 'package:flutter_test/flutter_test.dart';
import 'package:focus_roast/providers/timer_provider.dart';

/// Phase 2 — authoritative focus-session state tests.
///
/// These exercise the synchronous session state machine in [TimerProvider]
/// without Firebase. Persistence is attempted inside try/catch, so the
/// Firestore calls made by cancel/complete are safely swallowed here.
void main() {
  group('TimerProvider session ownership', () {
    late TimerProvider provider;
    late List<String> lastStartApps;
    late String lastStartSubject;
    late int lastStartDuration;
    late int monitoringStartCalls;
    late int monitoringStopCalls;

    setUp(() {
      provider = TimerProvider();
      monitoringStartCalls = 0;
      monitoringStopCalls = 0;
      lastStartApps = const [];
      lastStartSubject = '';
      lastStartDuration = -1;
      provider.bindMonitoring(
        onStart: (apps, subject, durationMinutes) {
          monitoringStartCalls++;
          lastStartApps = apps;
          lastStartSubject = subject;
          lastStartDuration = durationMinutes;
        },
        onStop: () => monitoringStopCalls++,
      );
    });

    test('captures config into immutable session values at start', () {
      provider.setSubject('Physics');
      provider.setFocusDuration(15);
      provider.setNumberOfBreaks(2);
      provider.setBreakDuration(10);

      final started = provider.startFocusSession(
        uid: 'user-1',
        distractionApps: const ['com.instagram.android'],
      );

      expect(started, isTrue);
      expect(provider.isSessionActive, isTrue);
      expect(provider.state, TimerState.focusRunning);
      expect(provider.sessionSubject, 'Physics');
      expect(provider.sessionFocusDurationMinutes, 15);
      expect(provider.sessionNumberOfBreaks, 2);
      expect(provider.sessionBreakDurationMinutes, 10);
      expect(provider.focusRemainingSeconds, 15 * 60);
      expect(provider.breakRemainingSeconds, 10 * 60);
    });

    test('regression: selected duration belongs to the active session (no 5->30 drift)', () {
      provider.setFocusDuration(5);
      provider.startFocusSession(uid: 'user-1', distractionApps: const []);

      // The running timer, the session value and the native monitor must all
      // agree on 5 minutes — this was the historical "UI shows 5, timer runs
      // 30" bug.
      expect(provider.sessionFocusDurationMinutes, 5);
      expect(provider.focusRemainingSeconds, 5 * 60);
      expect(lastStartDuration, 5);
    });

    test('monitoring hook receives captured subject and duration exactly once', () {
      provider.setSubject('Maths');
      provider.setFocusDuration(20);
      provider.startFocusSession(uid: 'user-1', distractionApps: const ['a', 'b']);

      expect(monitoringStartCalls, 1);
      expect(lastStartSubject, 'Maths');
      expect(lastStartDuration, 20);
      expect(lastStartApps, ['a', 'b']);
    });

    test('starting twice is idempotent — no duplicate timer or monitor', () {
      provider.setFocusDuration(10);
      final first = provider.startFocusSession(uid: 'user-1', distractionApps: const []);
      provider.incrementDistractionCount();

      final second = provider.startFocusSession(uid: 'user-1', distractionApps: const []);

      expect(first, isTrue);
      expect(second, isFalse);
      expect(monitoringStartCalls, 1, reason: 'monitoring must not start twice');
      // The in-flight session must not be reset by the second call.
      expect(provider.distractionCount, 1);
      expect(provider.sessionFocusDurationMinutes, 10);
    });

    test('config setters are locked while a session is active', () {
      provider.setFocusDuration(5);
      provider.setSubject('Original');
      provider.startFocusSession(uid: 'user-1', distractionApps: const []);

      // Attempts to mutate config mid-session must be ignored entirely.
      provider.setFocusDuration(30);
      provider.incrementFocusDuration();
      provider.decrementFocusDuration();
      provider.setSubject('Hijacked');
      provider.setNumberOfBreaks(5);
      provider.setBreakDuration(30);

      expect(provider.sessionFocusDurationMinutes, 5);
      expect(provider.sessionSubject, 'Original');
      expect(provider.focusRemainingSeconds, lessThanOrEqualTo(5 * 60));
      expect(lastStartDuration, 5);
    });

    test('incrementDistractionCount only counts while active and returns new count', () {
      expect(provider.incrementDistractionCount(), 0, reason: 'idle: no count');
      expect(provider.distractionCount, 0);

      provider.startFocusSession(uid: 'user-1', distractionApps: const []);
      expect(provider.incrementDistractionCount(), 1);
      expect(provider.incrementDistractionCount(), 2);
      expect(provider.distractionCount, 2);
    });

    test('pause and resume transition between focus phases', () {
      provider.startFocusSession(uid: 'user-1', distractionApps: const []);
      expect(provider.isFocusRunning, isTrue);

      provider.pauseTimer();
      expect(provider.state, TimerState.focusPaused);
      expect(provider.isFocusRunning, isFalse);

      provider.resumeTimer();
      expect(provider.state, TimerState.focusRunning);
      expect(provider.isFocusRunning, isTrue);
    });

    test('cancelSession stops monitoring and returns to idle without praise', () async {
      provider.startFocusSession(uid: 'user-1', distractionApps: const []);
      expect(monitoringStopCalls, 0);

      await provider.cancelSession();

      expect(provider.state, TimerState.idle);
      expect(provider.isSessionActive, isFalse);
      expect(monitoringStopCalls, 1, reason: 'cancellation must stop monitoring');
      expect(provider.latestAchievement, isNull, reason: 'cancel must never produce praise');
    });

    test('cancelSession is a safe no-op when already idle', () async {
      await provider.cancelSession();
      expect(provider.state, TimerState.idle);
      expect(monitoringStopCalls, 0);
    });

    test('monitoring stop is idempotent across repeated cancels', () async {
      provider.startFocusSession(uid: 'user-1', distractionApps: const []);
      await provider.cancelSession();
      await provider.cancelSession();
      expect(monitoringStopCalls, 1);
    });

    test('dismissCompleted returns to idle and clears runtime', () {
      provider.startFocusSession(uid: 'user-1', distractionApps: const []);
      provider.incrementDistractionCount();

      provider.dismissCompleted();

      expect(provider.state, TimerState.idle);
      expect(provider.distractionCount, 0);
      expect(monitoringStopCalls, 1);
    });

    test('config is editable again after the session ends', () async {
      provider.setFocusDuration(5);
      provider.startFocusSession(uid: 'user-1', distractionApps: const []);
      await provider.cancelSession();

      provider.setFocusDuration(45);
      expect(provider.focusDurationMinutes, 45);

      // A fresh start captures the new config.
      provider.startFocusSession(uid: 'user-1', distractionApps: const []);
      expect(provider.sessionFocusDurationMinutes, 45);
    });

    test('resetState tears down monitoring and returns to defaults', () {
      provider.setFocusDuration(50);
      provider.startFocusSession(uid: 'user-1', distractionApps: const []);

      provider.resetState();

      expect(provider.state, TimerState.idle);
      expect(monitoringStopCalls, 1);
      expect(provider.focusDurationMinutes, 30);
    });
  });
}
