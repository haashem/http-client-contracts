import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http_client_core/src/http_request.dart';

class HttpStreamResponse {
  final HttpRequest request;
  final int statusCode;
  final Map<String, String> headers;
  final int? contentLength;
  final Stream<List<int>> stream;

  HttpStreamResponse({
    required this.request,
    required this.statusCode,
    required Map<String, String> headers,
    required this.stream,
    this.contentLength,
  }) : headers = Map<String, String>.unmodifiable(headers) {
    if (statusCode < 100 || statusCode > 599) {
      throw ArgumentError('Invalid status code: $statusCode');
    }
    if (contentLength != null && contentLength! < 0) {
      throw ArgumentError('Invalid contentLength: $contentLength');
    }
  }

  bool get isSuccess => statusCode >= 200 && statusCode < 300;

  Future<Uint8List> bodyBytes() async {
    final buffer = <int>[];
    await for (final chunk in stream) {
      buffer.addAll(chunk);
    }
    return Uint8List.fromList(buffer);
  }

  Future<String> bodyAsString([Encoding encoding = utf8]) =>
      encoding.decodeStream(stream);

  Future<T> bodyAsJson<T>() async => jsonDecode(await bodyAsString()) as T;

  @override
  String toString() => 'HttpStreamResponse($statusCode ${request.uri})';
}
