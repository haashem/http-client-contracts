import '../../workout_feed/domain/workout_feed_repository.dart';
import '../domain/auth_gateway.dart';
import '../domain/login_refresh_outcome.dart';

class RunLoginRefreshScenario {
  RunLoginRefreshScenario({
    required AuthGateway authGateway,
    required WorkoutFeedRepository repository,
  }) : _authGateway = authGateway,
       _repository = repository;

  final AuthGateway _authGateway;
  final WorkoutFeedRepository _repository;

  Future<LoginRefreshOutcome> execute() async {
    await _authGateway.login();

    final workouts = await _repository.fetchWorkoutFeed(
      page: 1,
      timeout: const Duration(milliseconds: 300),
    );

    return LoginRefreshOutcome(
      message: 'Login succeeded, token auto-refreshed, and feed loaded.',
      accessToken: _authGateway.accessToken(),
      workoutCount: workouts.length,
    );
  }
}
