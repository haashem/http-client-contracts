# http_client_dio

`dio` adapter for `http_client_contracts`.

## Usage

```dart
import 'package:http_client_dio/http_client_dio.dart';

final HttpClient client = DioHttpClient();
final response = await client.get(Uri.parse('https://example.com'));
```

Use this package in composition/infrastructure layers. Keep feature code dependent on `http_client_contracts` only.
