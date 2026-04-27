import 'package:http_client_contracts/http_client_contracts.dart';

class AuthHttpClient implements HttpClient {
  AuthHttpClient({
    required HttpClient inner,
    required String? Function() accessTokenProvider,
    required Future<bool> Function() refreshOnUnauthorized,
  }) : _inner = inner,
       _accessTokenProvider = accessTokenProvider,
       _refreshOnUnauthorized = refreshOnUnauthorized;

  final HttpClient _inner;
  final String? Function() _accessTokenProvider;
  final Future<bool> Function() _refreshOnUnauthorized;

  @override
  Future<HttpResponse> send(
    HttpRequest request, {
    HttpCancellationToken? cancellationToken,
  }) async {
    final firstRequest = _withAuthorization(request, _accessTokenProvider());
    final response = await _inner.send(
      firstRequest,
      cancellationToken: cancellationToken,
    );

    if (response.statusCode != 401 || request.body is StreamRequestBody) {
      return response;
    }

    final refreshed = await _refreshOnUnauthorized();
    if (!refreshed) {
      return response;
    }

    final retriedRequest = _withAuthorization(request, _accessTokenProvider());
    return _inner.send(retriedRequest, cancellationToken: cancellationToken);
  }

  @override
  Future<HttpStreamResponse> sendStream(
    HttpRequest request, {
    HttpCancellationToken? cancellationToken,
  }) async {
    final firstRequest = _withAuthorization(request, _accessTokenProvider());
    final response = await _inner.sendStream(
      firstRequest,
      cancellationToken: cancellationToken,
    );

    if (response.statusCode != 401 || request.body is StreamRequestBody) {
      return response;
    }

    final refreshed = await _refreshOnUnauthorized();
    if (!refreshed) {
      return response;
    }

    final retriedRequest = _withAuthorization(request, _accessTokenProvider());
    return _inner.sendStream(
      retriedRequest,
      cancellationToken: cancellationToken,
    );
  }

  HttpRequest _withAuthorization(HttpRequest request, String? token) {
    if (token == null || token.isEmpty) {
      return request;
    }

    final headers = <String, String>{...request.headers};
    headers.removeWhere(
      (String key, String _) => key.toLowerCase() == 'authorization',
    );
    headers['Authorization'] = 'Bearer $token';
    return request.copyWith(headers: headers);
  }

  @override
  void close() {
    _inner.close();
  }
}
