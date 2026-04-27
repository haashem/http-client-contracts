import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../app/demo_runtime.dart';
import '../domain/workout.dart';
import 'workout_detail_controller.dart';

class WorkoutDetailScreen extends StatefulWidget {
  const WorkoutDetailScreen({
    super.key,
    required this.runtime,
    required this.workout,
  });

  final DemoRuntime runtime;
  final Workout workout;

  @override
  State<WorkoutDetailScreen> createState() => _WorkoutDetailScreenState();
}

class _WorkoutDetailScreenState extends State<WorkoutDetailScreen> {
  late final WorkoutDetailController _controller;

  @override
  void initState() {
    super.initState();
    _controller = WorkoutDetailController(
      runtime: widget.runtime,
      workoutId: widget.workout.id,
    );
    unawaited(_controller.load());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, Widget? child) {
        return PopScope(
          onPopInvokedWithResult: (bool didPop, Object? result) {
            _controller.cancel();
          },
          child: Scaffold(
            appBar: AppBar(title: Text('Workout #${widget.workout.id}')),
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Scenario 3: Workout detail + cancellation',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'This request is intentionally slow. Navigating back cancels '
                    'the in-flight call. Detail images are loaded in parallel and '
                    'rendered together only when both complete.',
                  ),
                  const SizedBox(height: 16),
                  Text(_controller.status),
                  const SizedBox(height: 16),
                  if (_controller.detail != null) ...<Widget>[
                    Text(
                      _controller.detail!.name,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Text('${_controller.detail!.minutes} minutes'),
                    const SizedBox(height: 8),
                    Text(_controller.detail!.description),
                  ],
                  const SizedBox(height: 16),
                  Expanded(child: Center(child: _buildImageSection())),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildImageSection() {
    final cover = _controller.coverImageBytes;
    final title = _controller.titleImageBytes;

    if (cover == null || title == null) {
      if (_controller.loading) {
        return const Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            CircularProgressIndicator(),
            SizedBox(height: 12),
            Text('Loading both images...'),
          ],
        );
      }

      return const Text('Images unavailable.');
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const Text('Both images resolved together:'),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            _ImageCard(label: 'Cover', bytes: cover),
            const SizedBox(width: 12),
            _ImageCard(label: 'Title', bytes: title),
          ],
        ),
      ],
    );
  }
}

class _ImageCard extends StatelessWidget {
  const _ImageCard({required this.label, required this.bytes});

  final String label;
  final Uint8List bytes;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            SizedBox(
              width: 72,
              height: 72,
              child: Image.memory(bytes, fit: BoxFit.cover),
            ),
            const SizedBox(height: 8),
            Text(label),
          ],
        ),
      ),
    );
  }
}
