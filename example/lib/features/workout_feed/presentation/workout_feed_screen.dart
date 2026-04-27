import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../domain/workout.dart';
import 'workout_feed_controller.dart';

class WorkoutFeedScreen extends StatefulWidget {
  const WorkoutFeedScreen({
    super.key,
    required this.controller,
    required this.onOpenWorkout,
  });

  final WorkoutFeedController controller;
  final Future<void> Function(Workout workout) onOpenWorkout;

  @override
  State<WorkoutFeedScreen> createState() => _WorkoutFeedScreenState();
}

class _WorkoutFeedScreenState extends State<WorkoutFeedScreen> {
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) {
      return;
    }
    if (_scrollController.position.extentAfter < 500) {
      widget.controller.loadNextPage();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (BuildContext context, Widget? child) {
        final controller = widget.controller;
        final feed = controller.feed;
        final showInitialLoading = controller.refreshing && feed.isEmpty;
        final showEmptyState = !controller.refreshing && feed.isEmpty;

        _scheduleAutoLoadIfUnderfilled(controller);

        return RefreshIndicator(
          onRefresh: controller.refreshFeed,
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(16),
            itemCount:
                1 +
                (showInitialLoading || showEmptyState ? 1 : 0) +
                feed.length +
                (controller.loadingNextPage ? 1 : 0),
            itemBuilder: (BuildContext context, int index) {
              if (index == 0) {
                return _WorkoutFeedHeader(status: controller.status);
              }

              var contentIndex = index - 1;
              if (showInitialLoading || showEmptyState) {
                if (contentIndex == 0) {
                  return SizedBox(
                    height: 320,
                    child: Center(
                      child: showInitialLoading
                          ? const CircularProgressIndicator()
                          : const Text('No workouts loaded yet.'),
                    ),
                  );
                }
                contentIndex -= 1;
              }

              if (contentIndex < feed.length) {
                final workout = feed[contentIndex];
                return _WorkoutTile(
                  key: ValueKey<String>(
                    '${workout.id}:${controller.thumbnailReloadVersion}',
                  ),
                  workout: workout,
                  controller: controller,
                  onTap: () => widget.onOpenWorkout(workout),
                );
              }

              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CircularProgressIndicator()),
              );
            },
          ),
        );
      },
    );
  }

  void _scheduleAutoLoadIfUnderfilled(WorkoutFeedController controller) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) {
        return;
      }
      final position = _scrollController.position;
      final underfilled = position.maxScrollExtent <= 0;
      if (underfilled &&
          controller.hasMore &&
          !controller.loadingNextPage &&
          !controller.refreshing) {
        controller.loadNextPage();
      }
    });
  }
}

class _WorkoutFeedHeader extends StatelessWidget {
  const _WorkoutFeedHeader({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Scenario 2: Workout feed (paginated GET + streamed images)',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          const Text(
            'Scroll to load more pages. Thumbnail images are loaded via '
            'streaming with progress and cancel automatically when cells '
            'leave view. Video download is controlled by each workout card '
            'and keeps running while you scroll.',
          ),
          const SizedBox(height: 10),
          Text(status),
        ],
      ),
    );
  }
}

class _WorkoutTile extends StatelessWidget {
  const _WorkoutTile({
    super.key,
    required this.workout,
    required this.controller,
    required this.onTap,
  });

  final Workout workout;
  final WorkoutFeedController controller;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 220,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Expanded(
                flex: 6,
                child: _WorkoutThumbnail(
                  workout: workout,
                  controller: controller,
                ),
              ),
              Expanded(
                flex: 4,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: <Widget>[
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            Text(
                              workout.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 6),
                            Text('${workout.minutes} minutes • #${workout.id}'),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      _WorkoutVideoDownloadAction(
                        workout: workout,
                        controller: controller,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WorkoutThumbnail extends StatefulWidget {
  const _WorkoutThumbnail({required this.workout, required this.controller});

  final Workout workout;
  final WorkoutFeedController controller;

  @override
  State<_WorkoutThumbnail> createState() => _WorkoutThumbnailState();
}

class _WorkoutThumbnailState extends State<_WorkoutThumbnail> {
  ThumbnailLoadOperation? _operation;

  Uint8List? _bytes;
  String? _error;
  double? _progress;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _startLoad();
  }

  @override
  void didUpdateWidget(covariant _WorkoutThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.workout.id != widget.workout.id) {
      _cancelInFlight('Workout cell recycled out of view.');
      _startLoad();
    }
  }

  @override
  void dispose() {
    _cancelInFlight('Workout cell went out of view; cancel image stream.');
    super.dispose();
  }

  Future<void> _startLoad() async {
    final cached = widget.controller.cachedThumbnail(widget.workout);
    if (cached != null) {
      setState(() {
        _bytes = cached;
        _loading = false;
        _error = null;
        _progress = 1;
      });
      return;
    }

    late final ThumbnailLoadOperation operation;
    operation = widget.controller.startThumbnailLoad(
      workout: widget.workout,
      onProgress: (int received, int? total) {
        if (!mounted || _operation != operation) {
          return;
        }
        setState(() {
          _progress = total == null || total <= 0 ? null : received / total;
        });
      },
    );
    _operation = operation;

    setState(() {
      _loading = true;
      _error = null;
      _progress = null;
      _bytes = null;
    });

    try {
      final bytes = await operation.future;

      if (!mounted || _operation != operation) {
        return;
      }

      setState(() {
        _bytes = bytes;
        _loading = false;
        _error = null;
        _progress = 1;
      });
      _operation = null;
    } on ThumbnailLoadCancelledException {
      if (!mounted || _operation != operation) {
        return;
      }
      _loading = false;
      _error = 'Image load cancelled.';
      _operation = null;
    } catch (error) {
      if (!mounted || _operation != operation) {
        return;
      }
      setState(() {
        _loading = false;
        _error = 'Failed to load image.';
      });
      debugPrint(
        'Thumbnail load failed for workout ${widget.workout.id}: $error',
      );
      _operation = null;
    }
  }

  void _cancelInFlight(String reason) {
    _operation?.cancel(reason);
    _operation = null;
  }

  @override
  Widget build(BuildContext context) {
    if (_bytes != null) {
      return Image.memory(_bytes!, fit: BoxFit.cover);
    }

    if (_loading) {
      return Container(
        color: Colors.black12,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              CircularProgressIndicator(value: _progress),
              const SizedBox(height: 8),
              Text(
                _progress == null
                    ? 'Streaming image...'
                    : 'Streaming ${(_progress! * 100).clamp(0.0, 100.0).toStringAsFixed(0)}%',
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      color: Colors.black12,
      alignment: Alignment.center,
      child: Text(_error ?? 'Image unavailable'),
    );
  }
}

class _WorkoutVideoDownloadAction extends StatelessWidget {
  const _WorkoutVideoDownloadAction({
    required this.workout,
    required this.controller,
  });

  final Workout workout;
  final WorkoutFeedController controller;

  @override
  Widget build(BuildContext context) {
    final state = controller.videoDownloadState(workout);
    final progress = state.progress;
    final progressLabel = progress == null
        ? null
        : '${(progress * 100).clamp(0.0, 100.0).toStringAsFixed(0)}%';
    final idleLabel = switch (state.phase) {
      WorkoutVideoDownloadPhase.completed => 'Done',
      WorkoutVideoDownloadPhase.cancelled => 'Canceled',
      WorkoutVideoDownloadPhase.failed => 'Failed',
      _ => null,
    };

    if (state.inProgress) {
      return Tooltip(
        message: 'Cancel video download',
        child: SizedBox(
          width: 52,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              InkResponse(
                onTap: () => controller.toggleVideoDownload(workout),
                radius: 24,
                child: SizedBox(
                  width: 40,
                  height: 40,
                  child: Stack(
                    alignment: Alignment.center,
                    children: <Widget>[
                      CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 3,
                      ),
                      const Icon(Icons.stop_rounded, size: 18),
                    ],
                  ),
                ),
              ),
              if (progressLabel != null) _ActionCaption(label: progressLabel),
              if (progressLabel == null) const _ActionCaption(label: '...'),
            ],
          ),
        ),
      );
    }

    return Tooltip(
      message: 'Download video',
      child: SizedBox(
        width: 52,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            InkResponse(
              onTap: () => controller.toggleVideoDownload(workout),
              radius: 22,
              child: const SizedBox(
                width: 40,
                height: 40,
                child: Center(child: Icon(Icons.download_rounded)),
              ),
            ),
            if (idleLabel != null)
              _ActionCaption(label: idleLabel)
            else
              const SizedBox(height: 14),
          ],
        ),
      ),
    );
  }
}

class _ActionCaption extends StatelessWidget {
  const _ActionCaption({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      maxLines: 1,
      softWrap: false,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.center,
      style: Theme.of(
        context,
      ).textTheme.bodySmall?.copyWith(fontSize: 10, height: 1.1),
    );
  }
}
