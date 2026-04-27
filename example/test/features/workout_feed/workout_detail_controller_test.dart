import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http_client_contracts/http_client_contracts.dart';
import 'package:example/app/demo_runtime.dart';
import 'package:example/features/workout_feed/domain/workout.dart';
import 'package:example/features/workout_feed/domain/workout_detail.dart';
import 'package:example/features/workout_feed/domain/workout_feed_repository.dart';
import 'package:example/features/workout_feed/presentation/workout_detail_controller.dart';

void main() {
  group('WorkoutDetailController', () {
    test('maps cancellation to request cancelled status', () async {
      final repo = _FakeWorkoutFeedRepository();
      final runtime = _FakeDemoRuntime(repo);
      final controller = WorkoutDetailController(
        runtime: runtime,
        workoutId: 7,
      );

      final loadFuture = controller.load();
      controller.cancel();
      await loadFuture;

      expect(controller.status, 'Request cancelled.');
      expect(controller.loading, isFalse);
    });

    test('reveals images only after both image calls resolve', () async {
      final repo = _FakeWorkoutFeedRepository();
      final runtime = _FakeDemoRuntime(repo);
      final controller = WorkoutDetailController(
        runtime: runtime,
        workoutId: 3,
      );

      final loadFuture = controller.load();

      final detail = WorkoutDetail(
        id: 3,
        name: 'Intervals',
        minutes: 30,
        description: 'High intensity intervals.',
        coverImageUrl: '/assets/workouts/3/cover.png',
        titleImageUrl: '/assets/workouts/3/title.png',
      );
      repo.detailCompleter.complete(detail);
      await Future<void>.delayed(Duration.zero);

      repo.imageCompleters['/assets/workouts/3/cover.png']!.complete(
        Uint8List.fromList(<int>[1, 2, 3]),
      );
      await Future<void>.delayed(Duration.zero);

      expect(controller.coverImageBytes, isNull);
      expect(controller.titleImageBytes, isNull);

      repo.imageCompleters['/assets/workouts/3/title.png']!.complete(
        Uint8List.fromList(<int>[4, 5, 6]),
      );
      await loadFuture;

      expect(controller.coverImageBytes, isNotNull);
      expect(controller.titleImageBytes, isNotNull);
      expect(controller.status, 'Detail and both images loaded.');
      expect(controller.detail?.name, 'Intervals');
    });
  });
}

class _FakeDemoRuntime extends DemoRuntime {
  _FakeDemoRuntime(this._repo);

  final WorkoutFeedRepository _repo;

  @override
  WorkoutFeedRepository get workoutFeedRepository => _repo;

  @override
  bool get switchingTransport => false;
}

class _FakeWorkoutFeedRepository implements WorkoutFeedRepository {
  final Completer<WorkoutDetail> detailCompleter = Completer<WorkoutDetail>();
  final Map<String, Completer<Uint8List>> imageCompleters =
      <String, Completer<Uint8List>>{};

  final Map<int, WorkoutDetail> _detailsCache = <int, WorkoutDetail>{};
  final Map<String, Uint8List> _imageCache = <String, Uint8List>{};

  @override
  List<Workout> cachedWorkoutFeed() => const <Workout>[];

  @override
  WorkoutDetail? cachedWorkoutDetail(int id) => _detailsCache[id];

  @override
  Uint8List? cachedImageBytes(String imageUrl) => _imageCache[imageUrl];

  @override
  void clearFeedAndImageCaches() {
    _imageCache.clear();
  }

  @override
  Future<List<Workout>> fetchWorkoutFeed({
    required int page,
    required Duration timeout,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<WorkoutDetail> fetchWorkoutDetail({
    required int id,
    HttpCancellationToken? cancellationToken,
  }) async {
    final detail = await _cancelAware(
      future: detailCompleter.future,
      cancellationToken: cancellationToken,
      requestPath: '/workouts/$id',
    );
    _detailsCache[id] = detail;
    return detail;
  }

  @override
  Future<Uint8List> fetchImageBytes({
    required String imageUrl,
    HttpCancellationToken? cancellationToken,
    void Function(int receivedBytes, int? totalBytes)? onProgress,
  }) async {
    final completer = imageCompleters.putIfAbsent(
      imageUrl,
      () => Completer<Uint8List>(),
    );
    final bytes = await _cancelAware(
      future: completer.future,
      cancellationToken: cancellationToken,
      requestPath: imageUrl,
    );
    onProgress?.call(bytes.length, bytes.length);
    _imageCache[imageUrl] = bytes;
    return bytes;
  }

  @override
  Future<int> downloadVideoBytes({
    required String videoUrl,
    HttpCancellationToken? cancellationToken,
    void Function(int receivedBytes, int? totalBytes)? onProgress,
  }) {
    throw UnimplementedError();
  }

  Future<T> _cancelAware<T>({
    required Future<T> future,
    required HttpCancellationToken? cancellationToken,
    required String requestPath,
  }) {
    if (cancellationToken == null) {
      return future;
    }

    final request = HttpRequest.get(
      Uri.parse('https://example.com$requestPath'),
    );
    final cancelled = cancellationToken.stream.first.then((Object? reason) {
      throw HttpCancelledException(request: request, reason: reason);
    });

    return Future.any(<Future<T>>[future, cancelled]);
  }
}
