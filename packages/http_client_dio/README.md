# http_client_dio

`dio` adapter for `http_client_contracts`.

## When To Use

Use this package to provide a concrete `HttpClient` implementation at your app's
composition root.

Do not couple app code directly to `DioHttpClient`. Keep app/business logic
dependent on `HttpClient` from `http_client_contracts`, and wire concrete
adapters in composition/infrastructure.

## Usage

```dart
import 'package:http_client_dio/http_client_dio.dart';

final HttpClient client = DioHttpClient();
final feedRepository = FeedRepository(client: client); // expects HttpClient
```

Use this package in composition/infrastructure layers only.
