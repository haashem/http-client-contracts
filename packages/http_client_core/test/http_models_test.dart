import 'package:http_client_core/http_client_core.dart';
import 'package:test/test.dart';

void main() {
  group('HttpRequest', () {
    test('defensively copies headers', () {
      final headers = <String, String>{'x-id': '1'};
      final request =
          HttpRequest.get(Uri.parse('https://example.com'), headers: headers);

      headers['x-id'] = '2';

      expect(request.headers['x-id'], '1');
      expect(() => request.headers['x-id'] = '3', throwsUnsupportedError);
    });
  });

  group('HttpResponse', () {
    test('rejects invalid status code', () {
      expect(
        () => HttpResponse(
          request: HttpRequest.get(Uri.parse('https://example.com')),
          statusCode: 99,
          headers: const <String, String>{},
          bodyBytes: const <int>[],
        ),
        throwsArgumentError,
      );
    });
  });

  group('HttpCancellationToken', () {
    test('cancel marks token and exposes reason', () {
      final token = HttpCancellationToken();

      token.cancel('dispose');

      expect(token.isCancelled, isTrue);
      expect(token.reason, 'dispose');
    });
  });
}
