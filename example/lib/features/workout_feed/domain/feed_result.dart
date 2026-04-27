import 'workout.dart';

class FeedResult {
  const FeedResult({
    required this.workouts,
    required this.usedFallback,
    required this.message,
  });

  final List<Workout> workouts;
  final bool usedFallback;
  final String message;
}
