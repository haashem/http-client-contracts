import 'dart:convert';

import 'package:http_client_contracts/http_client_contracts.dart';
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

    test('get/head constructors set no body', () {
      final get = HttpRequest.get(Uri.parse('https://example.com/get'));
      final head = HttpRequest.head(Uri.parse('https://example.com/head'));

      expect(get.method, HttpMethod.get);
      expect(get.body, isNull);
      expect(head.method, HttpMethod.head);
      expect(head.body, isNull);
    });

    test('copyWith overrides selected fields', () {
      final original = HttpRequest.post(
        Uri.parse('https://example.com/a'),
        headers: const <String, String>{'x-a': '1'},
        body: HttpRequestBody.text('a'),
        timeout: const Duration(seconds: 3),
      );

      final copied = original.copyWith(
        method: HttpMethod.put,
        uri: Uri.parse('https://example.com/b'),
        headers: const <String, String>{'x-b': '2'},
        body: HttpRequestBody.text('b'),
        timeout: const Duration(seconds: 5),
      );

      expect(copied.method, HttpMethod.put);
      expect(copied.uri, Uri.parse('https://example.com/b'));
      expect(copied.headers, const <String, String>{'x-b': '2'});
      expect((copied.body! as TextRequestBody).value, 'b');
      expect(copied.timeout, const Duration(seconds: 5));

      expect(original.method, HttpMethod.post);
      expect(original.uri, Uri.parse('https://example.com/a'));
    });
  });

  group('HttpRequestBody', () {
    test('json body encodes and exposes default content-type', () {
      final body = HttpRequestBody.json(<String, Object?>{'k': 'v'});
      final jsonBody = body as JsonRequestBody;

      expect(
        body.defaultContentType,
        'application/json; charset=utf-8',
      );
      expect(utf8.decode(jsonBody.encode()), '{"k":"v"}');
    });

    test('text body encodes and supports custom content-type', () {
      final body = HttpRequestBody.text(
        'hello',
        contentType: 'text/custom; charset=utf-8',
      );
      final textBody = body as TextRequestBody;

      expect(body.defaultContentType, 'text/custom; charset=utf-8');
      expect(utf8.decode(textBody.encode()), 'hello');
    });

    test('bytes body defensively copies source bytes', () {
      final source = <int>[1, 2, 3];
      final body = HttpRequestBody.bytes(source);
      final bytesBody = body as BytesRequestBody;

      source[0] = 9;

      expect(bytesBody.encode(), <int>[1, 2, 3]);
    });

    test('form body encodes query and keeps fields unmodifiable', () {
      final source = <String, String>{'a': '1', 'b': '2'};
      final body = HttpRequestBody.formUrlEncoded(source);
      final formBody = body as FormUrlEncodedRequestBody;

      source['a'] = '9';

      final encoded = utf8.decode(formBody.encode());
      expect(body.defaultContentType, 'application/x-www-form-urlencoded; charset=utf-8');
      expect(encoded, contains('a=1'));
      expect(encoded, contains('b=2'));
      expect(() => formBody.fields['c'] = '3', throwsUnsupportedError);
    });

    test('multipart body keeps fields/files unmodifiable', () {
      final sourceFields = <String, String>{'k': 'v'};
      final sourceFiles = <HttpMultipartFile>[
        HttpMultipartFile(field: 'f', filename: 'a.txt', bytes: utf8.encode('x')),
      ];

      final body = HttpRequestBody.multipart(
        fields: sourceFields,
        files: sourceFiles,
      ) as MultipartRequestBody;

      sourceFields['k'] = 'changed';
      sourceFiles.add(
        HttpMultipartFile(field: 'f2', filename: 'b.txt', bytes: utf8.encode('y')),
      );

      expect(body.fields, const <String, String>{'k': 'v'});
      expect(body.files, hasLength(1));
      expect(() => body.fields['x'] = '1', throwsUnsupportedError);
      expect(
        () => body.files.add(
          HttpMultipartFile(field: 'z', filename: 'z.txt', bytes: const <int>[]),
        ),
        throwsUnsupportedError,
      );
      expect(body.defaultContentType, isNull);
    });

    test('stream body keeps stream metadata', () {
      final body = HttpRequestBody.stream(
        Stream<List<int>>.fromIterable(
          <List<int>>[
            <int>[1],
            <int>[2],
          ],
        ),
        contentLength: 2,
        contentType: 'application/octet-stream',
      ) as StreamRequestBody;

      expect(body.contentLength, 2);
      expect(body.defaultContentType, 'application/octet-stream');
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

      expect(
        () => HttpResponse(
          request: HttpRequest.get(Uri.parse('https://example.com')),
          statusCode: 600,
          headers: const <String, String>{},
          bodyBytes: const <int>[],
        ),
        throwsArgumentError,
      );
    });

    test('isSuccess boundaries are correct', () {
      HttpResponse response(int status) => HttpResponse(
            request: HttpRequest.get(Uri.parse('https://example.com')),
            statusCode: status,
            headers: const <String, String>{},
            bodyBytes: const <int>[],
          );

      expect(response(199).isSuccess, isFalse);
      expect(response(200).isSuccess, isTrue);
      expect(response(299).isSuccess, isTrue);
      expect(response(300).isSuccess, isFalse);
    });

    test('bodyAsString/bodyAsJson work and body bytes are copied', () {
      final source = utf8.encode('{"ok":true}');
      final response = HttpResponse(
        request: HttpRequest.get(Uri.parse('https://example.com')),
        statusCode: 200,
        headers: const <String, String>{'x': '1'},
        bodyBytes: source,
      );

      source[0] = 120;

      expect(response.bodyAsString(), '{"ok":true}');
      expect(response.bodyAsJson<Map<String, dynamic>>(), <String, dynamic>{'ok': true});
      expect(() => response.headers['y'] = '2', throwsUnsupportedError);
    });
  });

  group('HttpStreamResponse', () {
    test('rejects invalid status or content-length', () {
      expect(
        () => HttpStreamResponse(
          request: HttpRequest.get(Uri.parse('https://example.com')),
          statusCode: 99,
          headers: const <String, String>{},
          stream: const Stream<List<int>>.empty(),
        ),
        throwsArgumentError,
      );

      expect(
        () => HttpStreamResponse(
          request: HttpRequest.get(Uri.parse('https://example.com')),
          statusCode: 200,
          headers: const <String, String>{},
          contentLength: -1,
          stream: const Stream<List<int>>.empty(),
        ),
        throwsArgumentError,
      );
    });

    test('bodyBytes reads stream', () async {
      final response = HttpStreamResponse(
        request: HttpRequest.get(Uri.parse('https://example.com')),
        statusCode: 200,
        headers: const <String, String>{},
        stream: Stream<List<int>>.fromIterable(
          <List<int>>[
            utf8.encode('he'),
            utf8.encode('llo'),
          ],
        ),
      );

      expect(await response.bodyBytes(), utf8.encode('hello'));
    });

    test('bodyAsString/bodyAsJson decode stream', () async {
      final asString = HttpStreamResponse(
        request: HttpRequest.get(Uri.parse('https://example.com')),
        statusCode: 200,
        headers: const <String, String>{},
        stream: Stream<List<int>>.fromIterable(<List<int>>[utf8.encode('text')]),
      );

      final asJson = HttpStreamResponse(
        request: HttpRequest.get(Uri.parse('https://example.com')),
        statusCode: 200,
        headers: const <String, String>{},
        stream: Stream<List<int>>.fromIterable(<List<int>>[utf8.encode('{"a":1}')]),
      );

      expect(await asString.bodyAsString(), 'text');
      expect(await asJson.bodyAsJson<Map<String, dynamic>>(), <String, dynamic>{'a': 1});
    });

    test('isSuccess boundaries are correct', () {
      HttpStreamResponse response(int status) => HttpStreamResponse(
            request: HttpRequest.get(Uri.parse('https://example.com')),
            statusCode: status,
            headers: const <String, String>{},
            stream: const Stream<List<int>>.empty(),
          );

      expect(response(199).isSuccess, isFalse);
      expect(response(200).isSuccess, isTrue);
      expect(response(299).isSuccess, isTrue);
      expect(response(300).isSuccess, isFalse);
    });
  });

  group('HttpCancellationToken', () {
    test('cancel marks token and exposes reason', () {
      final token = HttpCancellationToken();

      token.cancel('dispose');

      expect(token.isCancelled, isTrue);
      expect(token.reason, 'dispose');
    });

    test('cancel is idempotent and keeps first reason', () {
      final token = HttpCancellationToken();

      token.cancel('first');
      token.cancel('second');

      expect(token.reason, 'first');
    });

    test('whenCancelled resolves for pre-cancelled token', () async {
      final token = HttpCancellationToken()..cancel('done');

      expect(await token.whenCancelled, 'done');
    });

    test('whenCancelled resolves after future cancel', () async {
      final token = HttpCancellationToken();

      final future = token.whenCancelled;
      token.cancel('later');

      expect(await future, 'later');
    });

    test('throwIfCancelled throws HttpCancelledException', () {
      final token = HttpCancellationToken()..cancel('stop');

      expect(
        () => token.throwIfCancelled(HttpRequest.get(Uri.parse('https://example.com'))),
        throwsA(
          isA<HttpCancelledException>().having(
            (HttpCancelledException exception) => exception.reason,
            'reason',
            'stop',
          ),
        ),
      );
    });
  });

  group('HttpClient convenience extension', () {
    test('get maps to send(HttpRequest.get)', () async {
      final client = _FakeHttpClient();
      final token = HttpCancellationToken();

      await client.get(
        Uri.parse('https://example.com/r'),
        headers: const <String, String>{'x': '1'},
        timeout: const Duration(seconds: 2),
        cancellationToken: token,
      );

      final request = client.lastRequest!;
      expect(request.method, HttpMethod.get);
      expect(request.uri, Uri.parse('https://example.com/r'));
      expect(request.headers, const <String, String>{'x': '1'});
      expect(request.timeout, const Duration(seconds: 2));
      expect(client.lastToken, same(token));
    });

    test('post maps body and metadata', () async {
      final client = _FakeHttpClient();
      final body = HttpRequestBody.json(<String, Object?>{'a': 1});

      await client.post(
        Uri.parse('https://example.com/p'),
        body: body,
      );

      final request = client.lastRequest!;
      expect(request.method, HttpMethod.post);
      expect(request.body, same(body));
    });

    test('delete maps body and token', () async {
      final client = _FakeHttpClient();
      final token = HttpCancellationToken();
      final body = HttpRequestBody.text('bye');

      await client.delete(
        Uri.parse('https://example.com/d'),
        body: body,
        cancellationToken: token,
      );

      final request = client.lastRequest!;
      expect(request.method, HttpMethod.delete);
      expect(request.body, same(body));
      expect(client.lastToken, same(token));
    });
  });
}

class _FakeHttpClient implements HttpClient {
  HttpRequest? lastRequest;
  HttpCancellationToken? lastToken;

  @override
  Future<HttpResponse> send(
    HttpRequest request, {
    HttpCancellationToken? cancellationToken,
  }) async {
    lastRequest = request;
    lastToken = cancellationToken;
    return HttpResponse(
      request: request,
      statusCode: 200,
      headers: const <String, String>{},
      bodyBytes: const <int>[],
    );
  }

  @override
  Future<HttpStreamResponse> sendStream(
    HttpRequest request, {
    HttpCancellationToken? cancellationToken,
  }) async {
    lastRequest = request;
    lastToken = cancellationToken;
    return HttpStreamResponse(
      request: request,
      statusCode: 200,
      headers: const <String, String>{},
      stream: const Stream<List<int>>.empty(),
    );
  }

  @override
  void close() {}
}
