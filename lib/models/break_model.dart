class BreakModel {
  final int breakIndex;
  final int durationMinutes;
  final bool isCompleted;

  BreakModel({
    required this.breakIndex,
    required this.durationMinutes,
    this.isCompleted = false,
  });

  BreakModel copyWith({
    bool? isCompleted,
  }) {
    return BreakModel(
      breakIndex: breakIndex,
      durationMinutes: durationMinutes,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }
}
