# http_client_http

[`package:http`](https://pub.dev/packages/http) adapter for
[`http_client_contracts`](https://pub.dev/packages/http_client_contracts).

Use this package when your app should depend on the transport-agnostic
`HttpClient` contract, but you want requests to run through `package:http`.

## When To Use

- You want a small adapter around the official Dart `package:http` client.
- Keep feature/business code decoupled from `package:http` by depending on the
  transport-agnostic `HttpClient` contract from `http_client_contracts`.
- The concrete adapter should be created only in composition/infrastructure.

Import `http_client_contracts` directly wherever you need the shared
`HttpClient` types.

## Usage

Create the adapter in your composition root and pass it to code that expects the
contract:

```dart
import 'package:http/http.dart' as http;
import 'package:http_client_contracts/http_client_contracts.dart';
import 'package:http_client_http/http_client_http.dart';

final HttpClient client = HttpPackageClient(
  innerClient: http.Client(),
);
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
- [`http_client_dio`](https://pub.dev/packages/http_client_dio):
  `dio` adapter for the same contract.
