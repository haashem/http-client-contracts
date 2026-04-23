import 'package:http_client_contract_test/http_client_contract_test.dart';
import 'package:http_client_http/http_client_http.dart';

void main() {
  runHttpClientContractSuite(
    implementationName: 'HttpPackageClient',
    createClient: () => HttpPackageClient(),
  );
}
