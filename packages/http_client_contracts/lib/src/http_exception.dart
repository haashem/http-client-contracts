import 'package:http_client_contracts/src/http_request.dart';

sealed class HttpException implements Exception {
  final String message;
  final HttpRequest request;
  final Object? cause;
  final StackTrace? causeStackTrace;

  const HttpException({
    required this.message,
    required this.request,
    this.cause,
    this.causeStackTrace,
  });

  @override
  String toString() => '$message (${request.method.name} ${request.uri})';
}

final class HttpNetworkException extends HttpException {
  const HttpNetworkException({
    required super.message,
    required super.request,
    super.cause,
    super.causeStackTrace,
  });
}

final class HttpTimeoutException extends HttpException {
  final Duration timeout;

  const HttpTimeoutException({
    required this.timeout,
    required super.request,
    super.cause,
    super.causeStackTrace,
  }) : super(message: 'Request timed out after $timeout.');
}

final class HttpCancelledException extends HttpException {
  final Object? reason;

  const HttpCancelledException({
    required super.request,
    this.reason,
  }) : super(message: 'Request cancelled.');
}

final class HttpProtocolException extends HttpException {
  const HttpProtocolException({
    required super.message,
    required super.request,
    super.cause,
    super.causeStackTrace,
  });
}
