abstract interface class AuthGateway {
  Future<void> login();
  Future<bool> restoreSession();
  String? accessToken();
}
