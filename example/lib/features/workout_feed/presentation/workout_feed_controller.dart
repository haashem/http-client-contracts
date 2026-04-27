import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:http_client_contracts/http_client_contracts.dart';

import '../../../app/demo_runtime.dart';
import '../application/load_workout_feed.dart';
import '../domain/workout.dart';

class WorkoutFeedController extends ChangeNotifier {
  WorkoutFeedController({required DemoRuntime runtime}) : _runtime = runtime;

  final DemoRuntime _runtime;

  bool refreshing = false;
  bool loadingNextPage = false;
  bool hasMore = true;
  int _nextPage = 1;
  int _thumbnailReloadVersion = 0;
  final Map<int, _VideoDownloadOperation> _videoDownloadOperations =
      <int, _VideoDownloadOperation>{};
  final Map<int, WorkoutVideoDownloadState> _videoDownloadStates =
      <int, WorkoutVideoDownloadState>{};

  List<Workout> feed = <Workout>[];
  String status = 'Not loaded';

  int get thumbnailReloadVersion => _thumbnailReloadVersion;

  WorkoutVideoDownloadState videoDownloadState(Workout workout) {
    return _videoDownloadStates[workout.id] ??
        const WorkoutVideoDownloadState.idle();
  }

  Future<void> loadInitialPageIfNeeded() async {
    if (feed.isNotEmpty || refreshing || loadingNextPage) {
      return;
    }
    await refreshFeed();
  }

  Future<void> refreshFeed() async {
    if (_runtime.switchingTransport || refreshing || loadingNextPage) {
      return;
    }

    refreshing = true;
    _cancelAllVideoDownloads('Feed refresh started.');
    _videoDownloadStates.clear();
    _runtime.workoutFeedRepository.clearFeedAndImageCaches();
    _thumbnailReloadVersion += 1;
    feed = <Workout>[];
    hasMore = true;
    _nextPage = 1;
    status = 'Loading workouts...';
    notifyListeners();

    try {
      await _fetchPage(page: 1, replace: true);
    } finally {
      refreshing = false;
      notifyListeners();
    }
  }

  Future<void> loadNextPage() async {
    if (_runtime.switchingTransport ||
        refreshing ||
        loadingNextPage ||
        !hasMore) {
      return;
    }

    loadingNextPage = true;
    status = 'Loading page $_nextPage...';
    notifyListeners();

    try {
      await _fetchPage(page: _nextPage, replace: false);
    } finally {
      loadingNextPage = false;
      notifyListeners();
    }
  }

  void toggleVideoDownload(Workout workout) {
    final active = _videoDownloadOperations[workout.id];
    if (active != null) {
      active.token.cancel('Canceled by user from workout feed.');
      return;
    }
    _startVideoDownload(workout);
  }

  Uint8List? cachedThumbnail(Workout workout) {
    return _runtime.workoutFeedRepository.cachedImageBytes(
      workout.thumbnailImageUrl,
    );
  }

  ThumbnailLoadOperation startThumbnailLoad({
    required Workout workout,
    void Function(int receivedBytes, int? totalBytes)? onProgress,
  }) {
    final token = HttpCancellationToken();
    final future = () async {
      try {
        return await _runtime.workoutFeedRepository.fetchImageBytes(
          imageUrl: workout.thumbnailImageUrl,
          cancellationToken: token,
          onProgress: onProgress,
        );
      } on HttpCancelledException catch (error) {
        throw ThumbnailLoadCancelledException(reason: error.reason);
      }
    }();

    return ThumbnailLoadOperation._(future: future, token: token);
  }

  @override
  void dispose() {
    _cancelAllVideoDownloads('Workout feed closed.');
    super.dispose();
  }

  void _startVideoDownload(Workout workout) {
    final token = HttpCancellationToken();
    _videoDownloadOperations[workout.id] = _VideoDownloadOperation(
      token: token,
    );
    _videoDownloadStates[workout.id] = const WorkoutVideoDownloadState(
      phase: WorkoutVideoDownloadPhase.downloading,
      receivedBytes: 0,
      totalBytes: null,
      statusMessage: 'Starting video download...',
    );
    notifyListeners();
    unawaited(_runVideoDownload(workout: workout, token: token));
  }

  Future<void> _runVideoDownload({
    required Workout workout,
    required HttpCancellationToken token,
  }) async {
    try {
      final totalDownloaded = await _runtime.workoutFeedRepository
          .downloadVideoBytes(
            videoUrl: workout.videoDownloadUrl,
            cancellationToken: token,
            onProgress: (int received, int? total) {
              if (!_isActiveOperation(workoutId: workout.id, token: token)) {
                return;
              }

              _videoDownloadStates[workout.id] = WorkoutVideoDownloadState(
                phase: WorkoutVideoDownloadPhase.downloading,
                receivedBytes: received,
                totalBytes: total,
                statusMessage: _buildProgressMessage(
                  receivedBytes: received,
                  totalBytes: total,
                ),
              );
              notifyListeners();
            },
          );

      if (!_isActiveOperation(workoutId: workout.id, token: token)) {
        return;
      }

      _videoDownloadOperations.remove(workout.id);
      _videoDownloadStates[workout.id] = WorkoutVideoDownloadState(
        phase: WorkoutVideoDownloadPhase.completed,
        receivedBytes: totalDownloaded,
        totalBytes: totalDownloaded,
        statusMessage: 'Video downloaded (${_formatBytes(totalDownloaded)}).',
      );
      notifyListeners();
    } on HttpCancelledException catch (error) {
      if (!_isActiveOperation(workoutId: workout.id, token: token)) {
        return;
      }

      _videoDownloadOperations.remove(workout.id);
      _videoDownloadStates[workout.id] = WorkoutVideoDownloadState(
        phase: WorkoutVideoDownloadPhase.cancelled,
        receivedBytes: 0,
        totalBytes: null,
        statusMessage: 'Cancelled: ${_normalizedReason(error.reason)}',
      );
      notifyListeners();
    } catch (error) {
      if (!_isActiveOperation(workoutId: workout.id, token: token)) {
        return;
      }

      _videoDownloadOperations.remove(workout.id);
      _videoDownloadStates[workout.id] = WorkoutVideoDownloadState(
        phase: WorkoutVideoDownloadPhase.failed,
        receivedBytes: 0,
        totalBytes: null,
        statusMessage: 'Download failed.',
      );
      status = 'Video download failed for workout ${workout.id}: $error';
      notifyListeners();
    }
  }

  bool _isActiveOperation({
    required int workoutId,
    required HttpCancellationToken token,
  }) {
    final active = _videoDownloadOperations[workoutId];
    return identical(active?.token, token);
  }

  void _cancelAllVideoDownloads(String reason) {
    for (final operation in _videoDownloadOperations.values) {
      operation.token.cancel(reason);
    }
    _videoDownloadOperations.clear();
  }

  String _buildProgressMessage({
    required int receivedBytes,
    required int? totalBytes,
  }) {
    final receivedLabel = _formatBytes(receivedBytes);
    if (totalBytes == null || totalBytes <= 0) {
      return '$receivedLabel downloaded';
    }
    final totalLabel = _formatBytes(totalBytes);
    return '$receivedLabel / $totalLabel';
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    }
    final kb = bytes / 1024;
    if (kb < 1024) {
      return '${kb.toStringAsFixed(1)} KB';
    }
    final mb = kb / 1024;
    return '${mb.toStringAsFixed(1)} MB';
  }

  String _normalizedReason(Object? reason) {
    final value = reason?.toString().trim();
    if (value == null || value.isEmpty) {
      return 'none';
    }
    return value;
  }

  Future<void> _fetchPage({required int page, required bool replace}) async {
    if (_runtime.flakyFeedMode && page == 1) {
      _runtime.armTransientFeedFailures(2);
    }

    try {
      final useCase = LoadWorkoutFeed(
        repository: _runtime.workoutFeedRepository,
      );
      final result = await useCase.execute(
        page: page,
        slowMode: _runtime.slowFeedMode,
      );

      if (replace) {
        feed = result.workouts;
      } else {
        feed = <Workout>[...feed, ...result.workouts];
      }

      if (result.workouts.isEmpty) {
        hasMore = false;
        status = feed.isEmpty ? 'No workouts available.' : 'No more workouts.';
      } else {
        _nextPage = page + 1;
        status = result.message;
      }
    } catch (error) {
      status = 'Feed failed: $error';
      if (replace) {
        hasMore = feed.isNotEmpty;
      }
    }
  }
}

class ThumbnailLoadOperation {
  ThumbnailLoadOperation._({
    required this.future,
    required HttpCancellationToken token,
  }) : _token = token;

  final Future<Uint8List> future;
  final HttpCancellationToken _token;

  void cancel([Object? reason]) {
    if (!_token.isCancelled) {
      _token.cancel(reason);
    }
  }
}

class ThumbnailLoadCancelledException implements Exception {
  const ThumbnailLoadCancelledException({this.reason});

  final Object? reason;

  @override
  String toString() =>
      'ThumbnailLoadCancelledException(reason: ${reason ?? 'none'})';
}

class _VideoDownloadOperation {
  const _VideoDownloadOperation({required this.token});

  final HttpCancellationToken token;
}

enum WorkoutVideoDownloadPhase {
  idle,
  downloading,
  completed,
  cancelled,
  failed,
}

class WorkoutVideoDownloadState {
  const WorkoutVideoDownloadState({
    required this.phase,
    required this.receivedBytes,
    required this.totalBytes,
    required this.statusMessage,
  });

  const WorkoutVideoDownloadState.idle()
    : phase = WorkoutVideoDownloadPhase.idle,
      receivedBytes = 0,
      totalBytes = null,
      statusMessage = null;

  final WorkoutVideoDownloadPhase phase;
  final int receivedBytes;
  final int? totalBytes;
  final String? statusMessage;

  bool get inProgress => phase == WorkoutVideoDownloadPhase.downloading;

  bool get completed => phase == WorkoutVideoDownloadPhase.completed;

  double? get progress {
    final total = totalBytes;
    if (total == null || total <= 0) {
      if (phase == WorkoutVideoDownloadPhase.downloading) {
        return 0;
      }
      return null;
    }
    return (receivedBytes / total).clamp(0.0, 1.0);
  }
}
