import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:http_client_contracts/http_client_contracts.dart';

class DioHttpClient implements HttpClient {
  DioHttpClient({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;

  @override
  Future<HttpResponse> send(
    HttpRequest request, {
    HttpCancellationToken? cancellationToken,
  }) async {
    final streamed = await sendStream(
      request,
      cancellationToken: cancellationToken,
    );

    final bytes = await _readAllBytes(
      streamed.stream,
      request: request,
      cancellationToken: cancellationToken,
    );

    return HttpResponse(
      request: request,
      statusCode: streamed.statusCode,
      headers: streamed.headers,
      bodyBytes: bytes,
    );
  }

  @override
  Future<HttpStreamResponse> sendStream(
    HttpRequest request, {
    HttpCancellationToken? cancellationToken,
  }) async {
    cancellationToken?.throwIfCancelled(request);

    final headers = Map<String, String>.from(request.headers);
    final data = _toDioData(request.body, request, headers);

    final timeout = request.timeout;
    final options = Options(
      method: request.method.wireValue,
      headers: headers,
      responseType: ResponseType.stream,
      validateStatus: (_) => true,
      sendTimeout: timeout,
      receiveTimeout: timeout,
    );

    final cancelToken = CancelToken();
    final subscription = cancellationToken?.stream.listen((Object? reason) {
      if (!cancelToken.isCancelled) {
        cancelToken.cancel(reason);
      }
    });

    try {
      final response = await _dio.requestUri<ResponseBody>(
        request.uri,
        data: data,
        options: options,
        cancelToken: cancelToken,
      );

      final responseBody = response.data;
      if (responseBody == null) {
        throw HttpProtocolException(
          message: 'Missing response stream body.',
          request: request,
        );
      }

      final responseHeaders = response.headers.map.map(
        (String key, List<String> values) => MapEntry(key, values.join(',')),
      );

      return HttpStreamResponse(
        request: request,
        statusCode: response.statusCode ?? 0,
        headers: responseHeaders,
        contentLength: responseBody.contentLength,
        stream: _withCancellation(
          responseBody.stream,
          request: request,
          cancellationToken: cancellationToken,
        ),
      );
    } on HttpException {
      rethrow;
    } on DioException catch (error, stackTrace) {
      if (error.type == DioExceptionType.cancel || cancelToken.isCancelled) {
        throw HttpCancelledException(
          request: request,
          reason: cancellationToken?.reason ?? error.message,
        );
      }

      if (error.type == DioExceptionType.sendTimeout ||
          error.type == DioExceptionType.receiveTimeout ||
          error.type == DioExceptionType.connectionTimeout) {
        throw HttpTimeoutException(
          timeout: timeout ?? Duration.zero,
          request: request,
          cause: error,
          causeStackTrace: stackTrace,
        );
      }

      throw HttpNetworkException(
        message: 'Dio request failed.',
        request: request,
        cause: error,
        causeStackTrace: stackTrace,
      );
    } catch (error, stackTrace) {
      throw HttpNetworkException(
        message: 'Unknown transport failure.',
        request: request,
        cause: error,
        causeStackTrace: stackTrace,
      );
    } finally {
      await subscription?.cancel();
    }
  }

  @override
  void close() {
    _dio.close(force: true);
  }

  Object? _toDioData(
    HttpRequestBody? body,
    HttpRequest request,
    Map<String, String> headers,
  ) {
    if (body == null) {
      return null;
    }

    _ensureDefaultContentType(body, headers);

    switch (body) {
      case JsonRequestBody():
        return body.value;
      case TextRequestBody():
        return body.value;
      case BytesRequestBody():
        return body.value;
      case FormUrlEncodedRequestBody():
        return body.fields;
      case MultipartRequestBody():
        final map = <String, Object>{};
        map.addAll(body.fields);
        for (final file in body.files) {
          map[file.field] = MultipartFile.fromBytes(
            file.bytes,
            filename: file.filename,
          );
        }
        return FormData.fromMap(map);
      case StreamRequestBody():
        final contentLength = body.contentLength;
        if (contentLength != null) {
          headers[Headers.contentLengthHeader] = '$contentLength';
        }
        return body.stream;
    }
  }

  Future<Uint8List> _readAllBytes(
    Stream<List<int>> stream, {
    required HttpRequest request,
    HttpCancellationToken? cancellationToken,
  }) async {
    final readFuture = () async {
      final buffer = <int>[];
      await for (final chunk in _withCancellation(
        stream,
        request: request,
        cancellationToken: cancellationToken,
      )) {
        buffer.addAll(chunk);
      }
      return Uint8List.fromList(buffer);
    }();

    final timeout = request.timeout;
    final guardedReadFuture = timeout == null
        ? readFuture
        : readFuture.timeout(
            timeout,
            onTimeout: () {
              throw HttpTimeoutException(timeout: timeout, request: request);
            },
          );

    try {
      return await guardedReadFuture;
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
  }

  Stream<Uint8List> _withCancellation(
    Stream<List<int>> source, {
    required HttpRequest request,
    HttpCancellationToken? cancellationToken,
  }) {
    if (cancellationToken == null) {
      return source.map((List<int> chunk) => Uint8List.fromList(chunk));
    }

    if (cancellationToken.isCancelled) {
      return Stream<Uint8List>.error(
        HttpCancelledException(
          request: request,
          reason: cancellationToken.reason,
        ),
      );
    }

    StreamSubscription<List<int>>? sourceSubscription;
    StreamSubscription<Object?>? cancellationSubscription;

    late final StreamController<Uint8List> controller;
    controller = StreamController<Uint8List>(
      onListen: () {
        sourceSubscription = source.listen(
          (List<int> chunk) => controller.add(Uint8List.fromList(chunk)),
          onError: controller.addError,
          onDone: () async {
            await cancellationSubscription?.cancel();
            await controller.close();
          },
        );

        cancellationSubscription = cancellationToken.stream.listen((
          Object? reason,
        ) async {
          await sourceSubscription?.cancel();
          controller.addError(
            HttpCancelledException(request: request, reason: reason),
          );
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

  void _ensureDefaultContentType(
    HttpRequestBody body,
    Map<String, String> headers,
  ) {
    final defaultContentType = body.defaultContentType;
    if (defaultContentType == null) {
      return;
    }

    final hasContentType = headers.keys.any(
      (String key) => key.toLowerCase() == Headers.contentTypeHeader,
    );
    if (!hasContentType) {
      headers[Headers.contentTypeHeader] = defaultContentType;
    }
  }
}
