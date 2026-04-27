import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http_client_contracts/http_client_contracts.dart';
import 'package:example/features/auth/infrastructure/auth_service.dart';
import 'package:example/features/auth/infrastructure/auth_session.dart';

void main() {
  group('AuthService.restoreSession', () {
    test('returns false when refresh token is missing', () async {
      var sendCalls = 0;
      final client = _FakeHttpClient((HttpRequest _, HttpCancellationToken? _) {
        sendCalls += 1;
        throw StateError('should not be called');
      });

      final service = AuthService(
        client: client,
        baseUri: Uri.parse('http://localhost:8080/'),
        session: AuthSession(),
      );

      final restored = await service.restoreSession();

      expect(restored, isFalse);
      expect(sendCalls, 0);
    });

    test('returns true and updates token on successful refresh', () async {
      final session = AuthSession(refreshToken: 'refresh-token-1');
      final client = _FakeHttpClient((
        HttpRequest request,
        HttpCancellationToken? _,
      ) async {
        expect(request.uri.path, '/auth/refresh');
        return _jsonResponse(
          request: request,
          statusCode: 200,
          payload: <String, Object?>{'accessToken': 'live-token'},
        );
      });

      final service = AuthService(
        client: client,
        baseUri: Uri.parse('http://localhost:8080/'),
        session: session,
      );

      final restored = await service.restoreSession();

      expect(restored, isTrue);
      expect(session.accessToken, 'live-token');
    });

    test('returns false when refresh endpoint fails', () async {
      final session = AuthSession(refreshToken: 'refresh-token-1');
      final client = _FakeHttpClient((
        HttpRequest request,
        HttpCancellationToken? _,
      ) async {
        return _jsonResponse(
          request: request,
          statusCode: 401,
          payload: <String, Object?>{'error': 'invalid refresh token'},
        );
      });

      final service = AuthService(
        client: client,
        baseUri: Uri.parse('http://localhost:8080/'),
        session: session,
      );

      final restored = await service.restoreSession();

      expect(restored, isFalse);
      expect(session.accessToken, isNull);
    });
  });
}

class _FakeHttpClient implements HttpClient {
  _FakeHttpClient(this._sendHandler);

  final Future<HttpResponse> Function(
    HttpRequest request,
    HttpCancellationToken? cancellationToken,
  )
  _sendHandler;

  @override
  Future<HttpResponse> send(
    HttpRequest request, {
    HttpCancellationToken? cancellationToken,
  }) {
    return _sendHandler(request, cancellationToken);
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

HttpResponse _jsonResponse({
  required HttpRequest request,
  required int statusCode,
  required Map<String, Object?> payload,
}) {
  return HttpResponse(
    request: request,
    statusCode: statusCode,
    headers: const <String, String>{'content-type': 'application/json'},
    bodyBytes: utf8.encode(jsonEncode(payload)),
  );
}
