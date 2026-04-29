# http_client_http

`package:http` adapter for `http_client_contracts`.

## When To Use

Use this package to provide a concrete `HttpClient` implementation at your app's
composition root.

Do not couple app code directly to `HttpPackageClient`. Keep app/business logic
dependent on `HttpClient` from `http_client_contracts`, and wire concrete
adapters in composition/infrastructure.

## Usage

```dart
import 'package:http_client_http/http_client_http.dart';

final HttpClient client = HttpPackageClient();
final feedRepository = FeedRepository(client: client); // expects HttpClient
```

Use this package in composition/infrastructure layers only.
