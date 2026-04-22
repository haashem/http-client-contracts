import 'dart:async';

import 'package:http_client_core/src/http_exception.dart';
import 'package:http_client_core/src/http_request.dart';

class HttpCancellationToken {
  bool _isCancelled = false;
  Object? _reason;
  final StreamController<Object?> _controller =
      StreamController<Object?>.broadcast(sync: true);

  bool get isCancelled => _isCancelled;

  Object? get reason => _reason;

  Stream<Object?> get stream => _controller.stream;

  Future<Object?> get whenCancelled {
    if (_isCancelled) {
      return Future<Object?>.value(_reason);
    }
    return _controller.stream.first;
  }

  void cancel([Object? reason]) {
    if (_isCancelled) {
      return;
    }

    _isCancelled = true;
    _reason = reason;

    _controller.add(reason);
    unawaited(_controller.close());
  }

  void throwIfCancelled(HttpRequest request) {
    if (_isCancelled) {
      throw HttpCancelledException(request: request, reason: _reason);
    }
  }

  void dispose() {
    if (!_controller.isClosed) {
      unawaited(_controller.close());
    }
  }
}
