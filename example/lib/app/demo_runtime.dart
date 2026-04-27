import 'dart:async';

import 'package:flutter/foundation.dart';

import '../features/auth/domain/auth_gateway.dart';
import '../features/workout_feed/domain/workout_feed_repository.dart';
import 'composition/app_composition_root.dart';
import 'composition/composed_dependencies.dart';
import 'composition/transport_mode.dart';

class DemoRuntime extends ChangeNotifier {
  DemoRuntime();

  AppCompositionRoot? _compositionRoot;
  ComposedDependencies? _deps;

  bool initialized = false;
  bool switchingTransport = false;
  bool sessionRestored = false;
  String startupStatus = 'Restoring session...';

  TransportMode transportMode = TransportMode.packageHttp;
  bool offlineMode = false;
  bool flakyFeedMode = false;
  bool slowFeedMode = false;

  WorkoutFeedRepository get workoutFeedRepository {
    final deps = _deps;
    if (deps == null) {
      throw StateError('Runtime is not initialized.');
    }
    return deps.workoutFeedRepository;
  }

  AuthGateway get authGateway {
    final deps = _deps;
    if (deps == null) {
      throw StateError('Runtime is not initialized.');
    }
    return deps.authGateway;
  }

  Future<void> initialize() async {
    if (initialized) {
      return;
    }

    _compositionRoot = await AppCompositionRoot.create();
    await _activateTransport(mode: transportMode);
    try {
      sessionRestored = await authGateway.restoreSession();
      startupStatus = sessionRestored
          ? 'Session restored from refresh token.'
          : 'No stored session. Continuing unauthenticated.';
    } catch (error) {
      sessionRestored = false;
      startupStatus = 'Session restore failed. Continuing unauthenticated.';
    }
    initialized = true;
    notifyListeners();
  }

  Future<void> switchTransport(TransportMode mode) async {
    if (switchingTransport || mode == transportMode) {
      return;
    }

    switchingTransport = true;
    notifyListeners();

    try {
      transportMode = mode;
      await _activateTransport(mode: mode);
    } finally {
      switchingTransport = false;
      notifyListeners();
    }
  }

  void setOfflineMode(bool value) {
    offlineMode = value;
    _deps?.flakyClient.offlineMode = value;
    notifyListeners();
  }

  void setFlakyFeedMode(bool value) {
    flakyFeedMode = value;
    _deps?.flakyClient.transientFeedFailuresEnabled = value;
    notifyListeners();
  }

  void setSlowFeedMode(bool value) {
    slowFeedMode = value;
    _deps?.backend.slowFeedResponses = value;
    notifyListeners();
  }

  void armTransientFeedFailures(int count) {
    _deps?.flakyClient.armTransientFeedFailures(count);
  }

  Future<void> disposeRuntime() async {
    _deps?.close();
    final root = _compositionRoot;
    if (root != null) {
      await root.dispose();
    }
  }

  Future<void> _activateTransport({required TransportMode mode}) async {
    final root = _compositionRoot;
    if (root == null) {
      return;
    }

    final deps = await root.activate(mode: mode);
    _deps = deps;

    deps.flakyClient.offlineMode = offlineMode;
    deps.flakyClient.transientFeedFailuresEnabled = flakyFeedMode;
    deps.backend.slowFeedResponses = slowFeedMode;
  }
}
