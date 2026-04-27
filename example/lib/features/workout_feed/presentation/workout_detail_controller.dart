import 'package:flutter/foundation.dart';
import 'package:http_client_contracts/http_client_contracts.dart';

import '../../../app/demo_runtime.dart';
import '../application/load_workout_detail.dart';
import '../domain/workout_detail.dart';

class WorkoutDetailController extends ChangeNotifier {
  WorkoutDetailController({
    required DemoRuntime runtime,
    required this.workoutId,
  }) : _runtime = runtime;

  final DemoRuntime _runtime;
  final int workoutId;

  bool loading = false;
  String status = 'Not loaded';

  WorkoutDetail? detail;
  Uint8List? coverImageBytes;
  Uint8List? titleImageBytes;

  HttpCancellationToken? _cancellationToken;

  Future<void> load() async {
    if (loading || _runtime.switchingTransport) {
      return;
    }

    _cancellationToken?.cancel('Superseded by a new detail request.');
    final cancellationToken = HttpCancellationToken();
    _cancellationToken = cancellationToken;

    loading = true;
    status = 'Loading workout details...';
    coverImageBytes = null;
    titleImageBytes = null;
    notifyListeners();

    try {
      final detailResult = await LoadWorkoutDetail(
        repository: _runtime.workoutFeedRepository,
      ).execute(workoutId: workoutId, cancellationToken: cancellationToken);

      detail = detailResult.detail;
      status = detailResult.message;

      final images = await Future.wait<Uint8List>(<Future<Uint8List>>[
        _loadImageWithFallback(
          imageUrl: detail!.coverImageUrl,
          cancellationToken: cancellationToken,
        ),
        _loadImageWithFallback(
          imageUrl: detail!.titleImageUrl,
          cancellationToken: cancellationToken,
        ),
      ]);

      coverImageBytes = images[0];
      titleImageBytes = images[1];
      status = detailResult.usedFallback
          ? '${detailResult.message} Images loaded from cache/network.'
          : 'Detail and both images loaded.';
    } on HttpCancelledException {
      status = 'Request cancelled.';
    } catch (error) {
      status = 'Failed to load workout detail: $error';
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  void cancel() {
    _cancellationToken?.cancel('User left workout detail screen.');
  }

  @override
  void dispose() {
    cancel();
    super.dispose();
  }

  Future<Uint8List> _loadImageWithFallback({
    required String imageUrl,
    required HttpCancellationToken cancellationToken,
  }) async {
    try {
      return await _runtime.workoutFeedRepository.fetchImageBytes(
        imageUrl: imageUrl,
        cancellationToken: cancellationToken,
      );
    } on HttpCancelledException {
      rethrow;
    } on HttpException {
      final cached = _runtime.workoutFeedRepository.cachedImageBytes(imageUrl);
      if (cached != null) {
        return cached;
      }
      rethrow;
    }
  }
}
