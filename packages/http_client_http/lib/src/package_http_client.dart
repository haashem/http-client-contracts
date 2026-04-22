import 'dart:async';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http_client_core/http_client_core.dart';

class HttpPackageClient implements HttpClient {
  final http.Client _client;

  HttpPackageClient({http.Client? innerClient})
      : _client = innerClient ?? http.Client();

  @override
  Future<HttpResponse> send(
    HttpRequest request, {
    HttpCancellationToken? cancellationToken,
  }) async {
    final streamResponse = await sendStream(
      request,
      cancellationToken: cancellationToken,
    );

    final bytes = await _readAllBytes(
      streamResponse.stream,
      request: request,
      cancellationToken: cancellationToken,
    );

    return HttpResponse(
      request: request,
      statusCode: streamResponse.statusCode,
      headers: streamResponse.headers,
      bodyBytes: bytes,
    );
  }

  @override
  Future<HttpStreamResponse> sendStream(
    HttpRequest request, {
    HttpCancellationToken? cancellationToken,
  }) async {
    cancellationToken?.throwIfCancelled(request);

    final baseRequest = _buildBaseRequest(request);

    http.StreamedResponse response;
    try {
      response = await _runRequest(
        request: request,
        cancellationToken: cancellationToken,
        operation: _client.send(baseRequest),
      );
    } on HttpException {
      rethrow;
    } catch (error, stackTrace) {
      throw HttpNetworkException(
        message: 'Failed to send request.',
        request: request,
        cause: error,
        causeStackTrace: stackTrace,
      );
    }

    return HttpStreamResponse(
      request: request,
      statusCode: response.statusCode,
      headers: response.headers,
      contentLength: response.contentLength,
      stream: _withCancellation(
        response.stream,
        request: request,
        cancellationToken: cancellationToken,
      ),
    );
  }

  @override
  void close() {
    _client.close();
  }

  Future<T> _runRequest<T>({
    required HttpRequest request,
    required Future<T> operation,
    HttpCancellationToken? cancellationToken,
  }) {
    Future<T> guarded = operation;

    if (request.timeout != null) {
      guarded = guarded.timeout(
        request.timeout!,
        onTimeout: () {
          throw HttpTimeoutException(
            timeout: request.timeout!,
            request: request,
          );
        },
      );
    }

    if (cancellationToken == null) {
      return guarded;
    }

    final cancelledFuture = cancellationToken.whenCancelled.then<T>((reason) {
      throw HttpCancelledException(request: request, reason: reason);
    });

    return Future.any(<Future<T>>[guarded, cancelledFuture]);
  }

  Future<Uint8List> _readAllBytes(
    Stream<List<int>> stream, {
    required HttpRequest request,
    HttpCancellationToken? cancellationToken,
  }) async {
    final chunks = <int>[];

    try {
      await for (final chunk in _withCancellation(
        stream,
        request: request,
        cancellationToken: cancellationToken,
      )) {
        chunks.addAll(chunk);
      }
    } on HttpException {
      rethrow;
    } catch (error, stackTrace) {
      throw HttpNetworkException(
        message: 'Failed while reading response body.',
        request: request,
        cause: error,
        causeStackTrace: stackTrace,
      );
    }

    return Uint8List.fromList(chunks);
  }

  Stream<List<int>> _withCancellation(
    Stream<List<int>> source, {
    required HttpRequest request,
    HttpCancellationToken? cancellationToken,
  }) {
    if (cancellationToken == null) {
      return source;
    }

    if (cancellationToken.isCancelled) {
      return Stream<List<int>>.error(
        HttpCancelledException(
            request: request, reason: cancellationToken.reason),
      );
    }

    StreamSubscription<List<int>>? sourceSubscription;
    StreamSubscription<Object?>? cancellationSubscription;

    late final StreamController<List<int>> controller;
    controller = StreamController<List<int>>(
      onListen: () {
        sourceSubscription = source.listen(
          controller.add,
          onError: controller.addError,
          onDone: () async {
            await cancellationSubscription?.cancel();
            await controller.close();
          },
        );

        cancellationSubscription =
            cancellationToken.stream.listen((reason) async {
          await sourceSubscription?.cancel();
          controller.addError(
              HttpCancelledException(request: request, reason: reason));
          await controller.close();
        });
      },
      onPause: () => sourceSubscription?.pause(),
      onResume: () => sourceSubscription?.resume(),
      onCancel: () async {
        await cancellationSubscription?.cancel();
        await sourceSubscription?.cancel();
      },
    );

    return controller.stream;
  }

  http.BaseRequest _buildBaseRequest(HttpRequest request) {
    final body = request.body;
    final headers = Map<String, String>.from(request.headers);

    _ensureDefaultContentType(body, headers);

    if (body is MultipartRequestBody) {
      final multipart = http.MultipartRequest(
        request.method.wireValue,
        request.uri,
      )..headers.addAll(headers);

      multipart.fields.addAll(body.fields);
      for (final file in body.files) {
        multipart.files.add(
          http.MultipartFile.fromBytes(
            file.field,
            file.bytes,
            filename: file.filename,
          ),
        );
      }

      return multipart;
    }

    if (body is StreamRequestBody) {
      final streamedRequest = http.StreamedRequest(
        request.method.wireValue,
        request.uri,
      )..headers.addAll(headers);

      final contentLength = body.contentLength;
      if (contentLength != null) {
        streamedRequest.contentLength = contentLength;
      }

      body.stream.listen(
        streamedRequest.sink.add,
        onError: streamedRequest.sink.addError,
        onDone: streamedRequest.sink.close,
        cancelOnError: true,
      );

      return streamedRequest;
    }

    final plainRequest = http.Request(request.method.wireValue, request.uri)
      ..headers.addAll(headers);

    if (body != null) {
      plainRequest.bodyBytes = _encodeBodyBytes(body, request);
    }

    return plainRequest;
  }

  Uint8List _encodeBodyBytes(HttpRequestBody body, HttpRequest request) {
    switch (body) {
      case JsonRequestBody():
        return body.encode();
      case TextRequestBody():
        return body.encode();
      case BytesRequestBody():
        return body.encode();
      case FormUrlEncodedRequestBody():
        return body.encode();
      case MultipartRequestBody():
        throw HttpProtocolException(
          message: 'Multipart body is handled by MultipartRequest.',
          request: request,
        );
      case StreamRequestBody():
        throw HttpProtocolException(
          message: 'Stream body must use StreamedRequest.',
          request: request,
        );
    }
  }

  void _ensureDefaultContentType(
    HttpRequestBody? body,
    Map<String, String> headers,
  ) {
    if (body == null || body.defaultContentType == null) {
      return;
    }

    final hasContentType = headers.keys.any(
      (key) => key.toLowerCase() == 'content-type',
    );

    if (!hasContentType) {
      headers['Content-Type'] = body.defaultContentType!;
    }
  }
}
