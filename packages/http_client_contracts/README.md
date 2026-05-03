# http_client_contracts

A transport-agnostic HTTP interface for Dart and Flutter.

This package defines the HTTP contract your code should depend on, while concrete network engines (like `package:http` or `dio`) are plugged in through your app’s composition root.



## Why This Design

- Keep feature/business code stable even if you switch transport implementation.
- Add cross-cutting behavior (retry, auth, logging) without coupling to one HTTP library.


<img src="https://github.com/haashem/http-client-contracts/blob/main/packages/http_client_contracts/screenshots/usage-diagram.png?raw=true" alt="HTTP client usage diagram" width="900">


## What You Get

- One `HttpClient` interface for all transports.
- Built-in support for request timeout (`Duration timeout` on requests).
- Built-in support for request cancellation (`HttpCancellationToken`).
- Strong request/response models (`HttpRequest`, `HttpResponse`, `HttpStreamResponse`).
- Consistent error types (`HttpTimeoutException`, `HttpCancelledException`, `HttpNetworkException`).

## Interface

The main interface is `HttpClient`:

- `send(request, cancellationToken: ...)` for regular request/response.
- `sendStream(request, cancellationToken: ...)` for streamed responses.
- Convenience methods like `get`, `post`, `put`, `patch`, and `delete`.

## Quick Start

`http_client_contracts` provides interfaces and models only.
To send real requests, plug an adapter package into your app's composition root:

- [`http_client_http`](https://pub.dev/packages/http_client_http) (`package:http`)
- [`http_client_dio`](https://pub.dev/packages/http_client_dio) (`dio`)

Basic request:

```dart
import 'package:http_client_contracts/http_client_contracts.dart';

Future<void> loadFeed(HttpClient client) async {
  final response = await client.get(
    Uri.parse('https://api.example.com/feed'),
    timeout: const Duration(seconds: 8),
  );

  print(response.statusCode);
}
```

Cancellation:

```dart
final token = HttpCancellationToken();

final future = client.get(
  Uri.parse('https://api.example.com/slow'),
  cancellationToken: token,
);

token.cancel('user navigated away');

try {
  await future;
} on HttpCancelledException {
  // Expected when request is cancelled.
}
```
