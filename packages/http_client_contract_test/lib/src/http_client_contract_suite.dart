import 'dart:async';
import 'dart:io' as io;

import 'package:http_client_contracts/http_client_contracts.dart';
import 'package:test/test.dart';

typedef ClientFactory = FutureOr<HttpClient> Function();

void runHttpClientContractSuite({
  required String implementationName,
  required ClientFactory createClient,
}) {
  group('$implementationName contract', () {
    late io.HttpServer server;
    late Uri baseUri;
    late HttpClient client;

    Uri uri(String path) => baseUri.resolve(path);

    setUpAll(() async {
      server = await io.HttpServer.bind(io.InternetAddress.loopbackIPv4, 0);
      baseUri = Uri.parse('http://${server.address.address}:${server.port}/');

      server.listen((io.HttpRequest incoming) async {
        switch (incoming.uri.path) {
          case '/ok':
            incoming.response.statusCode = io.HttpStatus.ok;
            incoming.response.headers.contentType = io.ContentType.json;
            incoming.response.write('{"status":"ok"}');
            await incoming.response.close();

          case '/echo':
            final bodyBytes = await incoming.fold<List<int>>(
              <int>[],
              (List<int> previous, List<int> chunk) => previous..addAll(chunk),
            );
            final contentType =
                incoming.headers.value(io.HttpHeaders.contentTypeHeader);
            if (contentType != null) {
              incoming.response.headers.set('x-seen-content-type', contentType);
            }
            incoming.response.statusCode = io.HttpStatus.ok;
            incoming.response.add(bodyBytes);
            await incoming.response.close();

          case '/stream':
            incoming.response.statusCode = io.HttpStatus.ok;
            incoming.response.add(<int>[1, 2]);
            await incoming.response.flush();
            await Future<void>.delayed(const Duration(milliseconds: 5));
            incoming.response.add(<int>[3, 4]);
            await incoming.response.close();

          case '/stream-cancel':
            incoming.response.statusCode = io.HttpStatus.ok;
            incoming.response.add(<int>[1, 2]);
            await incoming.response.flush();
            await Future<void>.delayed(const Duration(milliseconds: 120));
            incoming.response.add(<int>[3, 4]);
            await incoming.response.close();

          case '/stream-timeout':
            incoming.response.statusCode = io.HttpStatus.ok;
            incoming.response.add(<int>[1, 2]);
            await incoming.response.flush();
            await Future<void>.delayed(const Duration(milliseconds: 120));
            incoming.response.add(<int>[3, 4]);
            await incoming.response.close();

          case '/slow':
            await Future<void>.delayed(const Duration(milliseconds: 120));
            incoming.response.statusCode = io.HttpStatus.ok;
            incoming.response.write('slow');
            await incoming.response.close();

          default:
            incoming.response.statusCode = io.HttpStatus.notFound;
            await incoming.response.close();
        }
      });
    });

    setUp(() async {
      client = await createClient();
    });

    tearDown(() {
      client.close();
    });

    tearDownAll(() async {
      await server.close(force: true);
    });

    test('sends GET and returns status/body', () async {
      final response = await client.send(HttpRequest.get(uri('/ok')));

      expect(response.statusCode, io.HttpStatus.ok);
      expect(response.isSuccess, isTrue);
      expect(
        response.bodyAsJson<Map<String, dynamic>>(),
        <String, dynamic>{'status': 'ok'},
      );
    });

    test('applies default content-type for json body', () async {
      final response = await client.send(
        HttpRequest.post(
          uri('/echo'),
          body: HttpRequestBody.json(
            <String, Object?>{'k': 'v'},
          ),
        ),
      );

      expect(response.bodyAsString(), '{"k":"v"}');
      expect(
        response.headers['x-seen-content-type'],
        startsWith('application/json'),
      );
    });

    test('applies default content-type for text body', () async {
      final response = await client.send(
        HttpRequest.post(
          uri('/echo'),
          body: HttpRequestBody.text('hello'),
        ),
      );

      expect(response.bodyAsString(), 'hello');
      expect(
        response.headers['x-seen-content-type'],
        startsWith('text/plain'),
      );
    });

    test('applies default content-type for form body', () async {
      final response = await client.send(
        HttpRequest.post(
          uri('/echo'),
          body: HttpRequestBody.formUrlEncoded(
            <String, String>{'a': '1', 'b': '2'},
          ),
        ),
      );

      expect(
        response.headers['x-seen-content-type'],
        startsWith('application/x-www-form-urlencoded'),
      );
      expect(response.bodyAsString(), contains('a=1'));
      expect(response.bodyAsString(), contains('b=2'));
    });

    test('supports StreamRequestBody', () async {
      final bodyStream = Stream<List<int>>.fromIterable(
        <List<int>>[
          <int>[65, 66],
          <int>[67, 68],
        ],
      );

      final response = await client.send(
        HttpRequest.post(
          uri('/echo'),
          body: HttpRequestBody.stream(
            bodyStream,
            contentLength: 4,
            contentType: 'application/octet-stream',
          ),
        ),
      );

      expect(response.bodyBytes, <int>[65, 66, 67, 68]);
      expect(
        response.headers['x-seen-content-type'],
        'application/octet-stream',
      );
    });

    test('sendStream returns stream data', () async {
      final streamed = await client.sendStream(HttpRequest.get(uri('/stream')));
      final bytes = await streamed.bodyBytes();

      expect(bytes, <int>[1, 2, 3, 4]);
    });

    test('maps timeout to HttpTimeoutException', () {
      final future = client.send(
        HttpRequest.get(
          uri('/slow'),
          timeout: const Duration(milliseconds: 15),
        ),
      );

      expect(future, throwsA(isA<HttpTimeoutException>()));
    });

    test('throws HttpCancelledException for pre-cancelled token', () {
      final token = HttpCancellationToken()..cancel('test');

      final future = client.send(
        HttpRequest.get(uri('/ok')),
        cancellationToken: token,
      );

      expect(future, throwsA(isA<HttpCancelledException>()));
    });

    test('throws HttpCancelledException for in-flight stream cancellation',
        () async {
      final token = HttpCancellationToken();
      final streamed = await client.sendStream(
        HttpRequest.get(uri('/stream-cancel')),
        cancellationToken: token,
      );

      final future = streamed.bodyBytes();
      unawaited(
        Future<void>.delayed(
          const Duration(milliseconds: 20),
          () => token.cancel('during stream'),
        ),
      );

      await expectLater(future, throwsA(isA<HttpCancelledException>()));
    });

    test('throws HttpCancelledException for in-flight send cancellation',
        () async {
      final token = HttpCancellationToken();
      final future = client.send(
        HttpRequest.get(uri('/stream-cancel')),
        cancellationToken: token,
      );

      unawaited(
        Future<void>.delayed(
          const Duration(milliseconds: 20),
          () => token.cancel('during send'),
        ),
      );

      await expectLater(future, throwsA(isA<HttpCancelledException>()));
    });

    test('maps body-read timeout to HttpTimeoutException for send', () async {
      final future = client.send(
        HttpRequest.get(
          uri('/stream-timeout'),
          timeout: const Duration(milliseconds: 30),
        ),
      );

      await expectLater(future, throwsA(isA<HttpTimeoutException>()));
    });

    test('maps connection failures to HttpNetworkException', () {
      final invalidUri = Uri.parse('http://127.0.0.1:1/unreachable');

      final future = client.send(HttpRequest.get(invalidUri));

      expect(future, throwsA(isA<HttpNetworkException>()));
    });
  });
}
