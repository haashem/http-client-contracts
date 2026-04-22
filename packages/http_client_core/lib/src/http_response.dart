import 'dart:convert';
import 'dart:typed_data';

import 'package:http_client_core/src/http_request.dart';

class HttpResponse {
  final HttpRequest request;
  final int statusCode;
  final Map<String, String> headers;
  final Uint8List bodyBytes;

  HttpResponse({
    required this.request,
    required this.statusCode,
    required Map<String, String> headers,
    required List<int> bodyBytes,
  })  : headers = Map<String, String>.unmodifiable(headers),
        bodyBytes = Uint8List.fromList(bodyBytes) {
    if (statusCode < 100 || statusCode > 599) {
      throw ArgumentError('Invalid status code: $statusCode');
    }
  }

  bool get isSuccess => statusCode >= 200 && statusCode < 300;

  String bodyAsString([Encoding encoding = utf8]) => encoding.decode(bodyBytes);

  T bodyAsJson<T>() => jsonDecode(bodyAsString()) as T;

  @override
  String toString() => 'HttpResponse($statusCode ${request.uri})';
}
