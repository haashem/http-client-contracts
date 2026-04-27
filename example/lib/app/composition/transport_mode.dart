enum TransportMode { packageHttp, dio }

extension TransportModeLabel on TransportMode {
  String get label {
    switch (this) {
      case TransportMode.packageHttp:
        return 'HttpPackageClient';
      case TransportMode.dio:
        return 'DioClient';
    }
  }
}
