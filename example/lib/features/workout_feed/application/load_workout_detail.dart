import 'package:http_client_contracts/http_client_contracts.dart';

import '../domain/workout_detail_result.dart';
import '../domain/workout_feed_repository.dart';

class LoadWorkoutDetail {
  LoadWorkoutDetail({required WorkoutFeedRepository repository})
    : _repository = repository;

  final WorkoutFeedRepository _repository;

  Future<WorkoutDetailResult> execute({
    required int workoutId,
    required HttpCancellationToken cancellationToken,
  }) async {
    try {
      final detail = await _repository.fetchWorkoutDetail(
        id: workoutId,
        cancellationToken: cancellationToken,
      );
      return WorkoutDetailResult(
        detail: detail,
        usedFallback: false,
        message: 'Loaded workout detail successfully.',
      );
    } on HttpCancelledException {
      rethrow;
    } on HttpException catch (error) {
      final cached = _repository.cachedWorkoutDetail(workoutId);
      if (cached != null) {
        return WorkoutDetailResult(
          detail: cached,
          usedFallback: true,
          message: 'Detail fallback used after network issue: ${error.message}',
        );
      }
      rethrow;
    }
  }
}
