import 'dart:convert';
import 'dart:typed_data';

import 'package:http_client_contracts/src/http_multipart_file.dart';

sealed class HttpRequestBody {
  const HttpRequestBody();

  String? get defaultContentType;

  factory HttpRequestBody.json(
    Object? value, {
    Encoding encoding,
  }) = JsonRequestBody;

  factory HttpRequestBody.text(
    String value, {
    Encoding encoding,
    String contentType,
  }) = TextRequestBody;

  factory HttpRequestBody.bytes(
    List<int> value, {
    String? contentType,
  }) = BytesRequestBody;

  factory HttpRequestBody.formUrlEncoded(
    Map<String, String> fields, {
    Encoding encoding,
  }) = FormUrlEncodedRequestBody;

  factory HttpRequestBody.multipart({
    Map<String, String> fields,
    List<HttpMultipartFile> files,
  }) = MultipartRequestBody;

  factory HttpRequestBody.stream(
    Stream<List<int>> stream, {
    int? contentLength,
    String? contentType,
  }) = StreamRequestBody;
}

final class JsonRequestBody extends HttpRequestBody {
  final Object? value;
  final Encoding encoding;

  const JsonRequestBody(this.value, {this.encoding = utf8});

  @override
  String get defaultContentType => 'application/json; charset=utf-8';

  Uint8List encode() => Uint8List.fromList(encoding.encode(jsonEncode(value)));
}

final class TextRequestBody extends HttpRequestBody {
  final String value;
  final Encoding encoding;
  final String contentType;

  const TextRequestBody(
    this.value, {
    this.encoding = utf8,
    this.contentType = 'text/plain; charset=utf-8',
  });

  @override
  String get defaultContentType => contentType;

  Uint8List encode() => Uint8List.fromList(encoding.encode(value));
}

final class BytesRequestBody extends HttpRequestBody {
  final Uint8List value;
  final String? contentType;

  BytesRequestBody(List<int> value, {this.contentType})
      : value = Uint8List.fromList(value);

  @override
  String? get defaultContentType => contentType;

  Uint8List encode() => value;
}

final class FormUrlEncodedRequestBody extends HttpRequestBody {
  final Map<String, String> fields;
  final Encoding encoding;

  FormUrlEncodedRequestBody(
    Map<String, String> fields, {
    this.encoding = utf8,
  }) : fields = Map.unmodifiable(Map<String, String>.from(fields));

  @override
  String get defaultContentType =>
      'application/x-www-form-urlencoded; charset=utf-8';

  Uint8List encode() {
    final query = Uri(queryParameters: fields).query;
    return Uint8List.fromList(encoding.encode(query));
  }
}

final class MultipartRequestBody extends HttpRequestBody {
  final Map<String, String> fields;
  final List<HttpMultipartFile> files;

  MultipartRequestBody({
    Map<String, String> fields = const <String, String>{},
    List<HttpMultipartFile> files = const <HttpMultipartFile>[],
  })  : fields = Map.unmodifiable(Map<String, String>.from(fields)),
        files = List<HttpMultipartFile>.unmodifiable(files);

  @override
  String? get defaultContentType => null;
}

final class StreamRequestBody extends HttpRequestBody {
  final Stream<List<int>> stream;
  final int? contentLength;
  final String? contentType;

  const StreamRequestBody(
    this.stream, {
    this.contentLength,
    this.contentType,
  });

  @override
  String? get defaultContentType => contentType;
}
