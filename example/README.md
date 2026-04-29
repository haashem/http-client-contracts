# Fitness Companion (Flutter Example)

This app demonstrates provider-agnostic networking with `http_client_contracts`.

## Core idea

Feature and data code depend only on the contract package. The concrete transport
is selected in composition root and can be switched at runtime:

- `HttpPackageClient` (`package:http` adapter)
- `DioHttpClient` (`http_client_dio` adapter package)

## Architecture

- `lib/core`: entities, repository interfaces, and use cases.
- `lib/data`: repository implementation and offline queue storage.
- `lib/network`: demo backend server, decorators, and transport adapters.
- `lib/composition`: service graph assembly and transport mode selection.
- `lib/ui`: controller + screens for each scenario.

## Scenarios in app

1. Login + token refresh
2. Workout feed (paginated GET) with retry/timeout and graceful fallback
3. Create workout log (POST JSON)
4. Upload progress photo (multipart)
5. Export plan download (stream + cancel)
6. Offline draft sync (queue + replay)
7. Debug transport switch + parity check

## Do we need real endpoints?

No. This app uses an in-process local backend (`DemoBackendServer`) so the
whole demo is self-contained and reproducible without external services.

## Run

```bash
flutter pub get
flutter run
```
