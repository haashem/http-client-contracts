import 'package:http_client_contract_test/http_client_contract_test.dart';
import 'package:http_client_dio/http_client_dio.dart';

void main() {
  runHttpClientContractSuite(
    implementationName: 'DioHttpClient',
    createClient: () => DioHttpClient(),
  );
}
