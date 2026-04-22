import 'package:http_client_http/http_client_http.dart';

import 'support/http_client_contract_suite.dart';

void main() {
  runHttpClientContractSuite(
    implementationName: 'HttpPackageClient',
    createClient: () => HttpPackageClient(),
  );
}
