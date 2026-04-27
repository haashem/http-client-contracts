import 'package:flutter_test/flutter_test.dart';
import 'package:http_client_contracts/http_client_contracts.dart';
import 'package:example/shared/network/decorators/retry_http_client.dart';

void main() {
  test('retries transient network failures and eventually succeeds', () async {
    final inner = _FlakyInnerClient(failuresBeforeSuccess: 2);
    final retryClient = RetryHttpClient(
      inner: inner,
      maxAttempts: 3,
      retryDelay: Duration.zero,
    );

    final request = HttpRequest.get(Uri.parse('https://example.com/workouts'));
    final response = await retryClient.send(request);

    expect(response.statusCode, 200);
    expect(inner.calls, 3);
  });
}

class _FlakyInnerClient implements HttpClient {
  _FlakyInnerClient({required this.failuresBeforeSuccess});

  final int failuresBeforeSuccess;
  int calls = 0;

  @override
  Future<HttpResponse> send(
    HttpRequest request, {
    HttpCancellationToken? cancellationToken,
  }) async {
    calls += 1;
    if (calls <= failuresBeforeSuccess) {
      throw HttpNetworkException(
        message: 'Transient network failure.',
        request: request,
      );
    }

    return HttpResponse(
      request: request,
      statusCode: 200,
      headers: const <String, String>{},
      bodyBytes: const <int>[],
    );
  }

  @override
  Future<HttpStreamResponse> sendStream(
    HttpRequest request, {
    HttpCancellationToken? cancellationToken,
  }) {
    throw UnimplementedError();
  }

  @override
  void close() {}
}
