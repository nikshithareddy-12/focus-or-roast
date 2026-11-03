enum TimerState { idle, running, paused, breakTime, completed }

class TimerModel {
  final int focusDurationMinutes;
  final int breakDurationMinutes;
  final int totalBreaks;
  final int currentBreakIndex;
  final int remainingSeconds;
  final TimerState state;
  final String subject;

  TimerModel({
    required this.focusDurationMinutes,
    required this.breakDurationMinutes,
    required this.totalBreaks,
    required this.currentBreakIndex,
    required this.remainingSeconds,
    required this.state,
    required this.subject,
  });

  TimerModel copyWith({
    int? focusDurationMinutes,
    int? breakDurationMinutes,
    int? totalBreaks,
    int? currentBreakIndex,
    int? remainingSeconds,
    TimerState? state,
    String? subject,
  }) {
    return TimerModel(
      focusDurationMinutes: focusDurationMinutes ?? this.focusDurationMinutes,
      breakDurationMinutes: breakDurationMinutes ?? this.breakDurationMinutes,
      totalBreaks: totalBreaks ?? this.totalBreaks,
      currentBreakIndex: currentBreakIndex ?? this.currentBreakIndex,
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
      state: state ?? this.state,
      subject: subject ?? this.subject,
    );
  }
}
