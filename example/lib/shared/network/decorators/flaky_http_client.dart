import 'package:http_client_contracts/http_client_contracts.dart';

class FlakyHttpClient implements HttpClient {
  FlakyHttpClient({required HttpClient inner}) : _inner = inner;

  final HttpClient _inner;

  bool offlineMode = false;
  bool transientFeedFailuresEnabled = false;
  int _remainingTransientFeedFailures = 0;

  void armTransientFeedFailures(int count) {
    _remainingTransientFeedFailures = count;
  }

  @override
  Future<HttpResponse> send(
    HttpRequest request, {
    HttpCancellationToken? cancellationToken,
  }) {
    _throwIfSimulatedFailure(request);
    return _inner.send(request, cancellationToken: cancellationToken);
  }

  @override
  Future<HttpStreamResponse> sendStream(
    HttpRequest request, {
    HttpCancellationToken? cancellationToken,
  }) {
    _throwIfSimulatedFailure(request);
    return _inner.sendStream(request, cancellationToken: cancellationToken);
  }

  void _throwIfSimulatedFailure(HttpRequest request) {
    if (offlineMode) {
      throw HttpNetworkException(
        message: 'Simulated airplane mode: network unavailable.',
        request: request,
      );
    }

    final isFeed =
        request.method == HttpMethod.get && request.uri.path == '/workouts';
    if (transientFeedFailuresEnabled &&
        isFeed &&
        _remainingTransientFeedFailures > 0) {
      _remainingTransientFeedFailures -= 1;
      throw HttpNetworkException(
        message: 'Simulated flaky network for workout feed.',
        request: request,
      );
    }
  }

  @override
  void close() {
    _inner.close();
  }
}
