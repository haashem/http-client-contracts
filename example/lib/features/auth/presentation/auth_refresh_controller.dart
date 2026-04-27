import 'package:flutter/foundation.dart';

import '../../../app/demo_runtime.dart';
import '../application/run_login_refresh_scenario.dart';

class AuthRefreshController extends ChangeNotifier {
  AuthRefreshController({required DemoRuntime runtime}) : _runtime = runtime;

  final DemoRuntime _runtime;

  bool busy = false;
  String status = 'Not started';

  Future<void> run() async {
    if (busy || _runtime.switchingTransport) {
      return;
    }

    busy = true;
    status = 'Running login + refresh scenario...';
    notifyListeners();

    try {
      final useCase = RunLoginRefreshScenario(
        authGateway: _runtime.authGateway,
        repository: _runtime.workoutFeedRepository,
      );

      final outcome = await useCase.execute();
      status =
          '${outcome.message} token=${outcome.accessToken} feedCount=${outcome.workoutCount}';
    } catch (error) {
      status = 'Login scenario failed: $error';
    } finally {
      busy = false;
      notifyListeners();
    }
  }
}
