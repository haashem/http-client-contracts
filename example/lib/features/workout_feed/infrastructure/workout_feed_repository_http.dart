import 'dart:convert';
import 'dart:typed_data';

import 'package:http_client_contracts/http_client_contracts.dart';

import '../domain/workout.dart';
import '../domain/workout_detail.dart';
import '../domain/workout_feed_repository.dart';

class WorkoutFeedRepositoryHttp implements WorkoutFeedRepository {
  WorkoutFeedRepositoryHttp({required HttpClient client, required Uri baseUri})
    : _client = client,
      _baseUri = baseUri;

  final HttpClient _client;
  final Uri _baseUri;
  List<Workout> _cachedFeed = <Workout>[];
  final Map<int, WorkoutDetail> _cachedDetails = <int, WorkoutDetail>{};
  final Map<String, Uint8List> _cachedImages = <String, Uint8List>{};
  static const Map<String, String> _featureHeaders = <String, String>{
    'x-demo-feature': 'workout_feed',
  };

  @override
  List<Workout> cachedWorkoutFeed() => List<Workout>.unmodifiable(_cachedFeed);

  @override
  WorkoutDetail? cachedWorkoutDetail(int id) => _cachedDetails[id];

  @override
  Uint8List? cachedImageBytes(String imageUrl) => _cachedImages[imageUrl];

  @override
  Future<List<Workout>> fetchWorkoutFeed({
    required int page,
    required Duration timeout,
  }) async {
    final response = await _client.send(
      HttpRequest.get(
        _baseUri.resolve('/workouts?page=$page'),
        headers: _featureHeaders,
        timeout: timeout,
      ),
    );

    _ensureSuccess(response);

    final list = response.bodyAsJson<List<dynamic>>();
    final workouts = list
        .map((dynamic item) => _jsonMap(item))
        .map(Workout.fromJson)
        .toList();
    if (page <= 1) {
      _cachedFeed = workouts;
    } else {
      _cachedFeed = <Workout>[..._cachedFeed, ...workouts];
    }
    return workouts;
  }

  @override
  Future<WorkoutDetail> fetchWorkoutDetail({
    required int id,
    HttpCancellationToken? cancellationToken,
  }) async {
    final response = await _client.send(
      HttpRequest.get(
        _baseUri.resolve('/workouts/$id'),
        headers: _featureHeaders,
        timeout: const Duration(milliseconds: 1200),
      ),
      cancellationToken: cancellationToken,
    );

    _ensureSuccess(response);

    final detail = WorkoutDetail.fromJson(
      _jsonMap(response.bodyAsJson<Map<String, dynamic>>()),
    );
    _cachedDetails[id] = detail;
    return detail;
  }

  @override
  Future<Uint8List> fetchImageBytes({
    required String imageUrl,
    HttpCancellationToken? cancellationToken,
    void Function(int receivedBytes, int? totalBytes)? onProgress,
  }) async {
    final response = await _client.sendStream(
      HttpRequest.get(
        _baseUri.resolve(imageUrl),
        headers: _featureHeaders,
        timeout: const Duration(seconds: 6),
      ),
      cancellationToken: cancellationToken,
    );

    if (!response.isSuccess) {
      throw HttpProtocolException(
        message: 'Unexpected status ${response.statusCode}.',
        request: response.request,
      );
    }

    final bytesBuilder = BytesBuilder(copy: false);
    var received = 0;
    await for (final chunk in response.stream) {
      bytesBuilder.add(chunk);
      received += chunk.length;
      onProgress?.call(received, response.contentLength);
    }

    final bytes = bytesBuilder.takeBytes();
    _cachedImages[imageUrl] = bytes;
    return bytes;
  }

  @override
  Future<int> downloadVideoBytes({
    required String videoUrl,
    HttpCancellationToken? cancellationToken,
    void Function(int receivedBytes, int? totalBytes)? onProgress,
  }) async {
    final response = await _client.sendStream(
      HttpRequest.get(
        _baseUri.resolve(videoUrl),
        headers: _featureHeaders,
        timeout: const Duration(seconds: 30),
      ),
      cancellationToken: cancellationToken,
    );

    if (!response.isSuccess) {
      throw HttpProtocolException(
        message: 'Unexpected status ${response.statusCode}.',
        request: response.request,
      );
    }

    final totalBytes = _resolveContentLength(response);
    var received = 0;
    onProgress?.call(received, totalBytes);
    await for (final chunk in response.stream) {
      received += chunk.length;
      onProgress?.call(received, totalBytes);
    }

    return received;
  }

  @override
  void clearFeedAndImageCaches() {
    _cachedFeed = <Workout>[];
    _cachedImages.clear();
  }

  Map<String, Object?> _jsonMap(Object? source) {
    return (source as Map<Object?, Object?>).map(
      (Object? key, Object? value) => MapEntry(key.toString(), value),
    );
  }

  int? _resolveContentLength(HttpStreamResponse response) {
    final direct = response.contentLength;
    if (direct != null && direct > 0) {
      return direct;
    }

    for (final entry in response.headers.entries) {
      if (entry.key.toLowerCase() != 'content-length') {
        continue;
      }
      final parsed = int.tryParse(entry.value.trim());
      if (parsed != null && parsed > 0) {
        return parsed;
      }
    }
    return null;
  }

  void _ensureSuccess(HttpResponse response) {
    if (response.isSuccess) {
      return;
    }

    final body = utf8.decode(response.bodyBytes);
    throw HttpProtocolException(
      message: 'Unexpected status ${response.statusCode}. body=$body',
      request: response.request,
    );
  }
}
