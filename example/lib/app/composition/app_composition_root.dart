import 'package:http_client_contracts/http_client_contracts.dart';
import 'package:http_client_dio/http_client_dio.dart';
import 'package:http_client_http/http_client_http.dart';

import '../../features/auth/infrastructure/auth_service.dart';
import '../../features/auth/infrastructure/auth_session.dart';
import '../../features/workout_feed/infrastructure/workout_feed_repository_http.dart';
import '../../shared/network/backend/demo_backend_server.dart';
import '../../shared/network/decorators/auth_http_client.dart';
import '../../shared/network/decorators/flaky_http_client.dart';
import '../../shared/network/decorators/logging_http_client.dart';
import '../../shared/network/decorators/retry_http_client.dart';
import 'composed_dependencies.dart';
import 'transport_mode.dart';

class AppCompositionRoot {
  AppCompositionRoot._(this._backend, this._authSession);

  final DemoBackendServer _backend;
  final AuthSession _authSession;
  ComposedDependencies? _active;

  static Future<AppCompositionRoot> create() async {
    final backend = await DemoBackendServer.start();
    return AppCompositionRoot._(
      backend,
      AuthSession(refreshToken: 'refresh-token-1'),
    );
  }

  Future<ComposedDependencies> activate({required TransportMode mode}) async {
    _active?.close();
    final deps = _compose(mode: mode);
    _active = deps;
    return deps;
  }

  ComposedDependencies composeTemporary({required TransportMode mode}) {
    return _compose(mode: mode);
  }

  Future<void> dispose() async {
    _active?.close();
    await _backend.close();
  }

  ComposedDependencies _compose({required TransportMode mode}) {
    final transport = _createTransport(mode);
    final flaky = FlakyHttpClient(inner: transport);

    final authService = AuthService(
      client: flaky,
      baseUri: _backend.baseUri,
      session: _authSession,
    );

    final auth = AuthHttpClient(
      inner: flaky,
      accessTokenProvider: authService.accessToken,
      refreshOnUnauthorized: authService.refreshAccessToken,
    );

    final retry = RetryHttpClient(inner: auth);
    final logging = LoggingHttpClient(inner: retry);

    final workoutFeedRepository = WorkoutFeedRepositoryHttp(
      client: logging,
      baseUri: _backend.baseUri,
    );

    return ComposedDependencies(
      workoutFeedRepository: workoutFeedRepository,
      authGateway: authService,
      flakyClient: flaky,
      backend: _backend,
      close: logging.close,
    );
  }

  HttpClient _createTransport(TransportMode mode) {
    switch (mode) {
      case TransportMode.packageHttp:
        return HttpPackageClient();
      case TransportMode.dio:
        return DioHttpClient();
    }
  }
}
