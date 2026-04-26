# HTTP Client Workspace

This repository is now a multi-package workspace:

- `packages/http_client_contracts`: transport-agnostic contracts.
- `packages/http_client_http`: `package:http` adapter for the contracts package.
- `packages/http_client_contract_test`: shared adapter conformance tests.

## Local development

Run checks package-by-package:

```bash
cd packages/http_client_contracts && dart pub get && dart analyze && dart test
cd packages/http_client_contract_test && dart pub get && dart analyze && dart test
cd packages/http_client_http && dart pub get && dart analyze && dart test
```
