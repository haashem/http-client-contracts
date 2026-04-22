import 'dart:async';
import 'dart:io' as io;

import 'package:http_client_core/http_client_core.dart';
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
      expect(response.bodyAsJson<Map<String, dynamic>>(),
          <String, dynamic>{'status': 'ok'});
    });

    test('applies default content-type for json body', () async {
      final response = await client.send(
        HttpRequest.post(uri('/echo'),
            body: HttpRequestBody.json(<String, Object?>{'k': 'v'})),
      );

      expect(response.bodyAsString(), '{"k":"v"}');
      expect(response.headers['x-seen-content-type'],
          startsWith('application/json'));
    });

    test('sendStream returns stream data', () async {
      final streamed = await client.sendStream(HttpRequest.get(uri('/stream')));
      final bytes = await streamed.bodyBytes();

      expect(bytes, <int>[1, 2, 3, 4]);
    });

    test('maps timeout to HttpTimeoutException', () {
      final future = client.send(
        HttpRequest.get(uri('/slow'),
            timeout: const Duration(milliseconds: 15)),
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

    test('maps connection failures to HttpNetworkException', () {
      final invalidUri = Uri.parse('http://127.0.0.1:1/unreachable');

      final future = client.send(HttpRequest.get(invalidUri));

      expect(future, throwsA(isA<HttpNetworkException>()));
    });
  });
}
