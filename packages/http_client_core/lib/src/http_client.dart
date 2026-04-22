import 'package:http_client_core/src/http_cancellation_token.dart';
import 'package:http_client_core/src/http_request.dart';
import 'package:http_client_core/src/http_request_body.dart';
import 'package:http_client_core/src/http_response.dart';
import 'package:http_client_core/src/http_stream_response.dart';

abstract interface class HttpClient {
  Future<HttpResponse> send(
    HttpRequest request, {
    HttpCancellationToken? cancellationToken,
  });

  Future<HttpStreamResponse> sendStream(
    HttpRequest request, {
    HttpCancellationToken? cancellationToken,
  });

  void close();
}

extension HttpClientConvenience on HttpClient {
  Future<HttpResponse> get(
    Uri uri, {
    Map<String, String> headers = const <String, String>{},
    Duration? timeout,
    HttpCancellationToken? cancellationToken,
  }) {
    return send(
      HttpRequest.get(uri, headers: headers, timeout: timeout),
      cancellationToken: cancellationToken,
    );
  }

  Future<HttpResponse> post(
    Uri uri, {
    Map<String, String> headers = const <String, String>{},
    HttpRequestBody? body,
    Duration? timeout,
    HttpCancellationToken? cancellationToken,
  }) {
    return send(
      HttpRequest.post(uri, headers: headers, body: body, timeout: timeout),
      cancellationToken: cancellationToken,
    );
  }

  Future<HttpResponse> put(
    Uri uri, {
    Map<String, String> headers = const <String, String>{},
    HttpRequestBody? body,
    Duration? timeout,
    HttpCancellationToken? cancellationToken,
  }) {
    return send(
      HttpRequest.put(uri, headers: headers, body: body, timeout: timeout),
      cancellationToken: cancellationToken,
    );
  }

  Future<HttpResponse> patch(
    Uri uri, {
    Map<String, String> headers = const <String, String>{},
    HttpRequestBody? body,
    Duration? timeout,
    HttpCancellationToken? cancellationToken,
  }) {
    return send(
      HttpRequest.patch(uri, headers: headers, body: body, timeout: timeout),
      cancellationToken: cancellationToken,
    );
  }

  Future<HttpResponse> delete(
    Uri uri, {
    Map<String, String> headers = const <String, String>{},
    HttpRequestBody? body,
    Duration? timeout,
    HttpCancellationToken? cancellationToken,
  }) {
    return send(
      HttpRequest.delete(uri, headers: headers, body: body, timeout: timeout),
      cancellationToken: cancellationToken,
    );
  }
}
