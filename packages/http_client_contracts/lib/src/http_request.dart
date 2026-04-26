import 'package:http_client_contracts/src/http_method.dart';
import 'package:http_client_contracts/src/http_request_body.dart';

class HttpRequest {
  final HttpMethod method;
  final Uri uri;
  final Map<String, String> headers;
  final HttpRequestBody? body;
  final Duration? timeout;

  HttpRequest({
    required this.method,
    required this.uri,
    Map<String, String> headers = const <String, String>{},
    this.body,
    this.timeout,
  }) : headers = Map<String, String>.unmodifiable(headers);

  HttpRequest.get(
    this.uri, {
    Map<String, String> headers = const <String, String>{},
    this.timeout,
  })  : method = HttpMethod.get,
        headers = Map<String, String>.unmodifiable(headers),
        body = null;

  HttpRequest.head(
    this.uri, {
    Map<String, String> headers = const <String, String>{},
    this.timeout,
  })  : method = HttpMethod.head,
        headers = Map<String, String>.unmodifiable(headers),
        body = null;

  HttpRequest.delete(
    this.uri, {
    Map<String, String> headers = const <String, String>{},
    this.body,
    this.timeout,
  })  : method = HttpMethod.delete,
        headers = Map<String, String>.unmodifiable(headers);

  HttpRequest.post(
    this.uri, {
    Map<String, String> headers = const <String, String>{},
    this.body,
    this.timeout,
  })  : method = HttpMethod.post,
        headers = Map<String, String>.unmodifiable(headers);

  HttpRequest.put(
    this.uri, {
    Map<String, String> headers = const <String, String>{},
    this.body,
    this.timeout,
  })  : method = HttpMethod.put,
        headers = Map<String, String>.unmodifiable(headers);

  HttpRequest.patch(
    this.uri, {
    Map<String, String> headers = const <String, String>{},
    this.body,
    this.timeout,
  })  : method = HttpMethod.patch,
        headers = Map<String, String>.unmodifiable(headers);

  HttpRequest.options(
    this.uri, {
    Map<String, String> headers = const <String, String>{},
    this.body,
    this.timeout,
  })  : method = HttpMethod.options,
        headers = Map<String, String>.unmodifiable(headers);

  HttpRequest copyWith({
    HttpMethod? method,
    Uri? uri,
    Map<String, String>? headers,
    HttpRequestBody? body,
    Duration? timeout,
  }) {
    return HttpRequest(
      method: method ?? this.method,
      uri: uri ?? this.uri,
      headers: headers ?? this.headers,
      body: body ?? this.body,
      timeout: timeout ?? this.timeout,
    );
  }

  @override
  String toString() => 'HttpRequest(${method.wireValue} $uri)';
}
