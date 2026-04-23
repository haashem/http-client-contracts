# http_client_contract_test

Shared HTTP client conformance tests for adapter packages.

## Usage

Add as a `dev_dependency` in an adapter package, then invoke:

```dart
import 'package:http_client_contract_test/http_client_contract_test.dart';

void main() {
  runHttpClientContractSuite(
    implementationName: 'MyAdapter',
    createClient: () => MyAdapterClient(),
  );
}
```
