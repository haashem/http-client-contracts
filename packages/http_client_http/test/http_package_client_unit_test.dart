import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http_client_http/http_client_http.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

class MockInnerHttpClient extends Mock implements http.Client {}

void main() {
  final url = Uri.parse('https://example.com/resource');

  late MockInnerHttpClient inner;
  late HttpPackageClient client;

  setUp(() {
    inner = MockInnerHttpClient();
    client = HttpPackageClient(innerClient: inner);

    registerFallbackValue(http.Request('GET', url));
  });

  tearDown(() {
    client.close();
  });

  test('preserves explicit content-type header', () async {
    when(() => inner.send(any())).thenAnswer(
      (_) async => http.StreamedResponse(const Stream<List<int>>.empty(), 204),
    );

    await client.send(
      HttpRequest.post(
        url,
        headers: <String, String>{'content-type': 'application/custom'},
        body: HttpRequestBody.json(<String, Object?>{'a': 1}),
      ),
    );

    final captured =
        verify(() => inner.send(captureAny())).captured.single as http.Request;

    expect(captured.headers['content-type'], 'application/custom');
  });

  test('builds multipart request with files', () async {
    when(() => inner.send(any())).thenAnswer(
      (_) async => http.StreamedResponse(const Stream<List<int>>.empty(), 201),
    );

    final request = HttpRequest.post(
      url,
      body: HttpRequestBody.multipart(
        fields: <String, String>{'name': 'value'},
        files: <HttpMultipartFile>[
          HttpMultipartFile(
            field: 'avatar',
            filename: 'pic.jpg',
            bytes: utf8.encode('abc'),
          ),
        ],
      ),
    );

    await client.sendStream(request);

    final captured = verify(() => inner.send(captureAny())).captured.single
        as http.MultipartRequest;

    expect(captured.method, 'POST');
    expect(captured.fields, <String, String>{'name': 'value'});
    expect(captured.files, hasLength(1));
    expect(captured.files.first.field, 'avatar');
    expect(captured.files.first.filename, 'pic.jpg');
  });

  test('keeps original transport exception as cause', () {
    when(() => inner.send(any())).thenThrow(StateError('offline'));

    final future = client.send(HttpRequest.get(url));

    expect(
      future,
      throwsA(
        isA<HttpNetworkException>().having(
          (exception) => exception.cause,
          'cause',
          isA<StateError>(),
        ),
      ),
    );
  });
}
