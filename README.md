# HTTP Client Workspace

This repository is now a multi-package workspace:

- `packages/http_client_contracts`: transport-agnostic contracts.
- `packages/http_client_http`: `package:http` adapter for the contracts package.
- `packages/http_client_contract_test`: shared adapter conformance tests.

## Local development

Resolve the whole workspace once:

```bash
dart pub get
dart pub workspace list
```

Run checks package-by-package:

```bash
(cd packages/http_client_contracts && dart analyze && dart test)
(cd packages/http_client_contract_test && dart analyze && dart test)
(cd packages/http_client_http && dart analyze && dart test)
```
