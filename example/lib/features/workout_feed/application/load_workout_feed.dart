import 'package:http_client_contracts/http_client_contracts.dart';

import '../domain/feed_result.dart';
import '../domain/workout_feed_repository.dart';

class LoadWorkoutFeed {
  LoadWorkoutFeed({required WorkoutFeedRepository repository})
    : _repository = repository;

  final WorkoutFeedRepository _repository;

  Future<FeedResult> execute({
    required int page,
    required bool slowMode,
  }) async {
    final timeout = slowMode
        ? const Duration(milliseconds: 120)
        : const Duration(milliseconds: 300);

    try {
      final workouts = await _repository.fetchWorkoutFeed(
        page: page,
        timeout: timeout,
      );
      return FeedResult(
        workouts: workouts,
        usedFallback: false,
        message: 'Loaded page $page successfully.',
      );
    } on HttpException catch (error) {
      final cached = _repository.cachedWorkoutFeed();
      if (cached.isNotEmpty) {
        return FeedResult(
          workouts: cached,
          usedFallback: true,
          message: 'Feed fallback used after network issue: ${error.message}',
        );
      }
      rethrow;
    }
  }
}
