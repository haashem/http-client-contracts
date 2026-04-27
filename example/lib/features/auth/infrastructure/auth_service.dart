import 'package:http_client_contracts/http_client_contracts.dart';

import '../domain/auth_gateway.dart';
import 'auth_session.dart';

class AuthService implements AuthGateway {
  AuthService({
    required HttpClient client,
    required Uri baseUri,
    required AuthSession session,
  }) : _client = client,
       _baseUri = baseUri,
       _session = session;

  final HttpClient _client;
  final Uri _baseUri;
  final AuthSession _session;
  static const Map<String, String> _featureHeaders = <String, String>{
    'x-demo-feature': 'auth',
  };

  @override
  Future<void> login() async {
    final response = await _client.send(
      HttpRequest.post(
        _baseUri.resolve('/auth/login'),
        headers: _featureHeaders,
        body: HttpRequestBody.json(const <String, Object?>{
          'username': 'demo@fitness.app',
          'password': 'demo',
        }),
      ),
    );

    final payload = response.bodyAsJson<Map<String, dynamic>>();
    _session.accessToken = payload['accessToken'] as String?;
    _session.refreshToken = payload['refreshToken'] as String?;
  }

  @override
  Future<bool> restoreSession() async {
    return refreshAccessToken();
  }

  Future<bool> refreshAccessToken() async {
    final refreshToken = _session.refreshToken;
    if (refreshToken == null) {
      return false;
    }

    final response = await _client.send(
      HttpRequest.post(
        _baseUri.resolve('/auth/refresh'),
        headers: _featureHeaders,
        body: HttpRequestBody.json(<String, Object?>{
          'refreshToken': refreshToken,
        }),
      ),
    );

    if (!response.isSuccess) {
      return false;
    }

    final payload = response.bodyAsJson<Map<String, dynamic>>();
    _session.accessToken = payload['accessToken'] as String?;
    return _session.accessToken != null;
  }

  @override
  String? accessToken() => _session.accessToken;
}
