import '../../features/auth/domain/auth_gateway.dart';
import '../../features/workout_feed/domain/workout_feed_repository.dart';
import '../../shared/network/backend/demo_backend_server.dart';
import '../../shared/network/decorators/flaky_http_client.dart';

class ComposedDependencies {
  ComposedDependencies({
    required this.workoutFeedRepository,
    required this.authGateway,
    required this.flakyClient,
    required this.backend,
    required this.close,
  });

  final WorkoutFeedRepository workoutFeedRepository;
  final AuthGateway authGateway;
  final FlakyHttpClient flakyClient;
  final DemoBackendServer backend;
  final void Function() close;
}
