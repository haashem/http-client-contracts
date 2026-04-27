import 'dart:async';

import 'package:http_client_contracts/http_client_contracts.dart';

class RetryHttpClient implements HttpClient {
  RetryHttpClient({
    required HttpClient inner,
    this.maxAttempts = 3,
    this.retryDelay = const Duration(milliseconds: 80),
  }) : _inner = inner;

  final HttpClient _inner;
  final int maxAttempts;
  final Duration retryDelay;

  @override
  Future<HttpResponse> send(
    HttpRequest request, {
    HttpCancellationToken? cancellationToken,
  }) async {
    final canReplayBody = request.body is! StreamRequestBody;
    final attempts = canReplayBody ? maxAttempts : 1;

    for (var attempt = 1; attempt <= attempts; attempt++) {
      try {
        final response = await _inner.send(
          request,
          cancellationToken: cancellationToken,
        );

        final retriableStatus = response.statusCode >= 500;
        if (!retriableStatus || attempt == attempts) {
          return response;
        }
      } on HttpCancelledException {
        rethrow;
      } on HttpNetworkException {
        if (attempt == attempts) {
          rethrow;
        }
      } on HttpTimeoutException {
        if (attempt == attempts) {
          rethrow;
        }
      }

      await Future<void>.delayed(retryDelay);
    }

    throw StateError('Retry attempts exhausted unexpectedly.');
  }

  @override
  Future<HttpStreamResponse> sendStream(
    HttpRequest request, {
    HttpCancellationToken? cancellationToken,
  }) async {
    final canReplayBody = request.body is! StreamRequestBody;
    final attempts = canReplayBody ? maxAttempts : 1;

    for (var attempt = 1; attempt <= attempts; attempt++) {
      try {
        final response = await _inner.sendStream(
          request,
          cancellationToken: cancellationToken,
        );

        final retriableStatus = response.statusCode >= 500;
        if (!retriableStatus || attempt == attempts) {
          return response;
        }

        await response.stream.drain<void>();
      } on HttpCancelledException {
        rethrow;
      } on HttpNetworkException {
        if (attempt == attempts) {
          rethrow;
        }
      } on HttpTimeoutException {
        if (attempt == attempts) {
          rethrow;
        }
      }

      await Future<void>.delayed(retryDelay);
    }

    throw StateError('Retry attempts exhausted unexpectedly.');
  }

  @override
  void close() {
    _inner.close();
  }
}
