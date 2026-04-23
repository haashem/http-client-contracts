import 'package:http_client_contract_test/http_client_contract_test.dart';
import 'package:test/test.dart';

void main() {
  test('exports runHttpClientContractSuite', () {
    expect(runHttpClientContractSuite, isA<Function>());
  });
}
