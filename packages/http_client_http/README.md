# http_client_http

`package:http` adapter for `http_client_core`.

## Usage

```dart
import 'package:http_client_http/http_client_http.dart';

final HttpClient client = HttpPackageClient();
final response = await client.get(Uri.parse('https://example.com'));
```

Use this package in composition/infrastructure layers. Keep feature code dependent on `http_client_core` only.
