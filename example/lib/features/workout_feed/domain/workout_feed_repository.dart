import 'dart:typed_data';

import 'package:http_client_contracts/http_client_contracts.dart';

import 'workout.dart';
import 'workout_detail.dart';

abstract interface class WorkoutFeedRepository {
  Future<List<Workout>> fetchWorkoutFeed({
    required int page,
    required Duration timeout,
  });

  List<Workout> cachedWorkoutFeed();

  Future<WorkoutDetail> fetchWorkoutDetail({
    required int id,
    HttpCancellationToken? cancellationToken,
  });

  WorkoutDetail? cachedWorkoutDetail(int id);

  Future<Uint8List> fetchImageBytes({
    required String imageUrl,
    HttpCancellationToken? cancellationToken,
    void Function(int receivedBytes, int? totalBytes)? onProgress,
  });

  Future<int> downloadVideoBytes({
    required String videoUrl,
    HttpCancellationToken? cancellationToken,
    void Function(int receivedBytes, int? totalBytes)? onProgress,
  });

  Uint8List? cachedImageBytes(String imageUrl);

  void clearFeedAndImageCaches();
}
