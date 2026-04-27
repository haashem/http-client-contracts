import 'package:flutter/foundation.dart';
import 'package:http_client_contracts/http_client_contracts.dart';

class LoggingHttpClient implements HttpClient {
  LoggingHttpClient({required HttpClient inner}) : _inner = inner;

  final HttpClient _inner;
  static const String _featureHeader = 'x-demo-feature';
  static const String _defaultFeature = 'http';

  @override
  Future<HttpResponse> send(
    HttpRequest request, {
    HttpCancellationToken? cancellationToken,
  }) async {
    final feature = _featureFromRequest(request);
    final started = DateTime.now();
    _log(feature, '-> ${request.method.wireValue} ${request.uri}');

    try {
      final response = await _inner.send(
        request,
        cancellationToken: cancellationToken,
      );
      final elapsed = DateTime.now().difference(started).inMilliseconds;
      _log(feature, '<- ${response.statusCode} ${request.uri} (${elapsed}ms)');
      return response;
    } on HttpCancelledException catch (error) {
      final elapsed = DateTime.now().difference(started).inMilliseconds;
      _log(
        feature,
        '<x ${request.uri} cancelled in ${elapsed}ms (reason: ${error.reason ?? 'none'})',
      );
      rethrow;
    } catch (error) {
      final elapsed = DateTime.now().difference(started).inMilliseconds;
      _log(feature, '<! ${request.uri} failed in ${elapsed}ms: $error');
      rethrow;
    }
  }

  @override
  Future<HttpStreamResponse> sendStream(
    HttpRequest request, {
    HttpCancellationToken? cancellationToken,
  }) async {
    final feature = _featureFromRequest(request);
    final started = DateTime.now();
    _log(feature, '~> ${request.method.wireValue} ${request.uri}');

    try {
      final response = await _inner.sendStream(
        request,
        cancellationToken: cancellationToken,
      );
      final elapsed = DateTime.now().difference(started).inMilliseconds;
      _log(feature, '<~ ${response.statusCode} ${request.uri} (${elapsed}ms)');
      return HttpStreamResponse(
        request: response.request,
        statusCode: response.statusCode,
        headers: response.headers,
        contentLength: response.contentLength,
        stream: _withStreamLogging(
          feature: feature,
          request: request,
          source: response.stream,
          started: started,
        ),
      );
    } on HttpCancelledException catch (error) {
      final elapsed = DateTime.now().difference(started).inMilliseconds;
      _log(
        feature,
        '<x ${request.uri} stream cancelled in ${elapsed}ms (reason: ${error.reason ?? 'none'})',
      );
      rethrow;
    } catch (error) {
      final elapsed = DateTime.now().difference(started).inMilliseconds;
      _log(feature, '<! ${request.uri} stream failed in ${elapsed}ms: $error');
      rethrow;
    }
  }

  @override
  void close() {
    _inner.close();
  }

  Stream<List<int>> _withStreamLogging({
    required String feature,
    required HttpRequest request,
    required Stream<List<int>> source,
    required DateTime started,
  }) async* {
    var streamedBytes = 0;
    try {
      await for (final chunk in source) {
        streamedBytes += chunk.length;
        yield chunk;
      }
      final elapsed = DateTime.now().difference(started).inMilliseconds;
      _log(
        feature,
        '<= ${request.uri} stream completed $streamedBytes bytes (${elapsed}ms)',
      );
    } on HttpCancelledException catch (error) {
      final elapsed = DateTime.now().difference(started).inMilliseconds;
      _log(
        feature,
        '<x ${request.uri} stream cancelled in ${elapsed}ms (reason: ${error.reason ?? 'none'})',
      );
      rethrow;
    } catch (error) {
      final elapsed = DateTime.now().difference(started).inMilliseconds;
      _log(feature, '<! ${request.uri} stream crashed in ${elapsed}ms: $error');
      rethrow;
    }
  }

  String _featureFromRequest(HttpRequest request) {
    for (final entry in request.headers.entries) {
      if (entry.key.toLowerCase() == _featureHeader) {
        return entry.value;
      }
    }
    return _defaultFeature;
  }

  void _log(String feature, String message) {
    debugPrint('[$feature] $message');
  }
}
