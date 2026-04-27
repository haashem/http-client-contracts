import 'dart:async';

import 'package:flutter/material.dart';

import '../features/auth/presentation/auth_refresh_controller.dart';
import '../features/workout_feed/presentation/workout_feed_controller.dart';
import 'demo_runtime.dart';
import 'presentation/fitness_home_shell.dart';

class FitnessCompanionApp extends StatefulWidget {
  const FitnessCompanionApp({super.key});

  @override
  State<FitnessCompanionApp> createState() => _FitnessCompanionAppState();
}

class _FitnessCompanionAppState extends State<FitnessCompanionApp> {
  late final DemoRuntime _runtime;
  late final AuthRefreshController _authController;
  late final WorkoutFeedController _feedController;
  late final Future<void> _initialization;

  @override
  void initState() {
    super.initState();
    _runtime = DemoRuntime();
    _authController = AuthRefreshController(runtime: _runtime);
    _feedController = WorkoutFeedController(runtime: _runtime);
    _initialization = _runtime.initialize();
  }

  @override
  void dispose() {
    unawaited(_runtime.disposeRuntime());
    _authController.dispose();
    _feedController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fitness Companion',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0B8F7B)),
      ),
      home: FutureBuilder<void>(
        future: _initialization,
        builder: (BuildContext context, AsyncSnapshot<void> snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Scaffold(
              body: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Restoring session...'),
                  ],
                ),
              ),
            );
          }

          if (snapshot.hasError) {
            return Scaffold(
              body: Center(
                child: Text('Initialization failed: ${snapshot.error}'),
              ),
            );
          }

          return FitnessHomeShell(
            runtime: _runtime,
            authController: _authController,
            feedController: _feedController,
          );
        },
      ),
    );
  }
}
