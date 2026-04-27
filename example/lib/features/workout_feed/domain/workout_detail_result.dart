import 'workout_detail.dart';

class WorkoutDetailResult {
  const WorkoutDetailResult({
    required this.detail,
    required this.usedFallback,
    required this.message,
  });

  final WorkoutDetail detail;
  final bool usedFallback;
  final String message;
}
