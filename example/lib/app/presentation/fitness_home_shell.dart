import 'package:flutter/material.dart';

import '../../features/auth/presentation/auth_refresh_controller.dart';
import '../../features/auth/presentation/login_refresh_screen.dart';
import '../../features/settings/presentation/runtime_settings_screen.dart';
import '../../features/workout_feed/domain/workout.dart';
import '../../features/workout_feed/presentation/workout_feed_controller.dart';
import '../../features/workout_feed/presentation/workout_detail_screen.dart';
import '../../features/workout_feed/presentation/workout_feed_screen.dart';
import '../demo_runtime.dart';

class FitnessHomeShell extends StatefulWidget {
  const FitnessHomeShell({
    super.key,
    required this.runtime,
    required this.authController,
    required this.feedController,
  });

  final DemoRuntime runtime;
  final AuthRefreshController authController;
  final WorkoutFeedController feedController;

  @override
  State<FitnessHomeShell> createState() => _FitnessHomeShellState();
}

class _FitnessHomeShellState extends State<FitnessHomeShell> {
  int _index = 1;

  static const List<String> _titles = <String>[
    'Login + Refresh',
    'Workout Feed',
    'Settings',
  ];

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(widget.feedController.loadInitialPageIfNeeded);
  }

  @override
  Widget build(BuildContext context) {
    final screens = <Widget>[
      LoginRefreshScreen(controller: widget.authController),
      WorkoutFeedScreen(
        controller: widget.feedController,
        onOpenWorkout: _openWorkoutDetail,
      ),
      RuntimeSettingsScreen(runtime: widget.runtime),
    ];

    return AnimatedBuilder(
      animation: widget.runtime,
      builder: (BuildContext context, Widget? child) {
        return Scaffold(
          appBar: AppBar(title: Text('Fitness Companion • ${_titles[_index]}')),
          body: IndexedStack(index: _index, children: screens),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: (int value) {
              setState(() {
                _index = value;
              });
            },
            destinations: const <NavigationDestination>[
              NavigationDestination(icon: Icon(Icons.login), label: 'Auth'),
              NavigationDestination(icon: Icon(Icons.list_alt), label: 'Feed'),
              NavigationDestination(
                icon: Icon(Icons.settings),
                label: 'Settings',
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openWorkoutDetail(Workout workout) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) =>
            WorkoutDetailScreen(runtime: widget.runtime, workout: workout),
      ),
    );
  }
}
