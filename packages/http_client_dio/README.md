# http_client_dio

[`dio`](https://pub.dev/packages/dio) adapter for
[`http_client_contracts`](https://pub.dev/packages/http_client_contracts).

Use this package when your app should depend on the transport-agnostic
`HttpClient` contract, but you want requests to run through `dio`.

## When To Use

- Your app already uses `dio` or wants `dio` configuration, interceptors, and
  transport behavior.
- Keep feature/business code decoupled from `dio` by depending on the
  transport-agnostic `HttpClient` contract from `http_client_contracts`.
- The concrete adapter should be created only in composition/infrastructure.

Import `http_client_contracts` directly wherever you need the shared
`HttpClient` types.

## Usage

Create the adapter in your composition root and pass it to code that expects the
contract:

```dart
import 'package:dio/dio.dart';
import 'package:http_client_contracts/http_client_contracts.dart';
import 'package:http_client_dio/http_client_dio.dart';

final dio = Dio(
  BaseOptions(
    headers: {'Authorization': 'Bearer token'},
  ),
);

final HttpClient client = DioHttpClient(dio: dio);
final feedRepository = FeedRepository(client: client); // expects HttpClient
```

Use the contract in app/business code:

```dart
import 'package:http_client_contracts/http_client_contracts.dart';

class FeedRepository {
  FeedRepository({required this.client});

  final HttpClient client;

  Future<List<Object?>> loadFeed() async {
    final response = await client.get(
      Uri.parse('https://api.example.com/feed'),
      timeout: const Duration(seconds: 8),
    );

    if (!response.isSuccess) {
      throw StateError('Feed request failed with ${response.statusCode}.');
    }

    return response.bodyAsJson<List<Object?>>();
  }
}
```

## Related Packages

- [`http_client_contracts`](https://pub.dev/packages/http_client_contracts):
  shared `HttpClient` interface, request/response models, and exceptions.
- [`http_client_http`](https://pub.dev/packages/http_client_http):
  `package:http` adapter for the same contract.
