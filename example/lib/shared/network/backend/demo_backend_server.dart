import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;
import 'dart:typed_data';

class DemoBackendServer {
  DemoBackendServer._(this._server);

  final io.HttpServer _server;

  bool slowFeedResponses = false;
  Duration startupRefreshDelay = const Duration(milliseconds: 1800);
  bool _startupRefreshDelayApplied = false;
  String _validAccessToken = 'access-live-token';
  final String _validRefreshToken = 'refresh-token-1';
  final List<Map<String, Object?>> _workouts =
      List<Map<String, Object?>>.generate(60, (int index) {
        final id = index + 1;
        return <String, Object?>{
          'id': id,
          'name': _workoutNameFor(id),
          'minutes': 18 + ((id * 7) % 38),
        };
      });
  final Map<String, List<int>> _assetImageCache = <String, List<int>>{};
  final Map<int, List<int>> _assetVideoCache = <int, List<int>>{};

  Uri get baseUri => Uri.parse('http://127.0.0.1:${_server.port}/');

  static Future<DemoBackendServer> start() async {
    final server = await io.HttpServer.bind(io.InternetAddress.loopbackIPv4, 0);
    final backend = DemoBackendServer._(server);
    backend._startListening();
    return backend;
  }

  void _startListening() {
    _server.listen((io.HttpRequest request) async {
      try {
        await _handle(request);
      } catch (_) {
        request.response.statusCode = io.HttpStatus.internalServerError;
        request.response.write('backend failure');
        await request.response.close();
      }
    });
  }

  Future<void> _handle(io.HttpRequest request) async {
    final path = request.uri.path;
    final method = request.method;

    if (!_isPublic(path) && !_isAuthorized(request)) {
      await _writeJson(
        request.response,
        io.HttpStatus.unauthorized,
        <String, Object?>{'error': 'unauthorized'},
      );
      return;
    }

    if (method == 'POST' && path == '/auth/login') {
      await _writeJson(request.response, io.HttpStatus.ok, <String, Object?>{
        'accessToken': 'expired-access-token',
        'refreshToken': _validRefreshToken,
      });
      return;
    }

    if (method == 'POST' && path == '/auth/refresh') {
      // Demo-only behavior: make startup restore visibly slow so splash state
      // is clearly observable in the app.
      if (!_startupRefreshDelayApplied) {
        _startupRefreshDelayApplied = true;
        await Future<void>.delayed(startupRefreshDelay);
      }

      final payload = await _readJson(request);
      final refreshToken = payload['refreshToken'] as String?;
      if (refreshToken != _validRefreshToken) {
        await _writeJson(
          request.response,
          io.HttpStatus.unauthorized,
          <String, Object?>{'error': 'invalid refresh token'},
        );
        return;
      }
      _validAccessToken =
          'access-live-token-${DateTime.now().millisecondsSinceEpoch}';
      await _writeJson(request.response, io.HttpStatus.ok, <String, Object?>{
        'accessToken': _validAccessToken,
      });
      return;
    }

    if (method == 'GET' && path == '/workouts') {
      await Future<void>.delayed(const Duration(milliseconds: 260));

      final page =
          int.tryParse(request.uri.queryParameters['page'] ?? '1') ?? 1;
      const pageSize = 8;
      final start = (page - 1) * pageSize;
      final end = start + pageSize;
      final pageItems = start >= _workouts.length
          ? <Map<String, Object?>>[]
          : _workouts.sublist(
              start,
              end > _workouts.length ? _workouts.length : end,
            );

      final pagePayload = pageItems.map((Map<String, Object?> workout) {
        final id = workout['id'];
        return <String, Object?>{
          ...workout,
          'thumbnailImageUrl': '/assets/workouts/$id/cover.png',
          'videoDownloadUrl': '/assets/workouts/$id/video.bin',
        };
      }).toList();

      await _writeJson(request.response, io.HttpStatus.ok, pagePayload);
      return;
    }

    final pathSegments = request.uri.pathSegments;
    if (method == 'GET' &&
        pathSegments.length == 2 &&
        pathSegments[0] == 'workouts') {
      final id = int.tryParse(pathSegments[1]);
      if (id == null) {
        request.response.statusCode = io.HttpStatus.badRequest;
        await request.response.close();
        return;
      }

      final workout = _workouts.where((Map<String, Object?> item) {
        return item['id'] == id;
      }).firstOrNull;

      if (workout == null) {
        request.response.statusCode = io.HttpStatus.notFound;
        await request.response.close();
        return;
      }

      await Future<void>.delayed(const Duration(milliseconds: 800));
      await _writeJson(request.response, io.HttpStatus.ok, <String, Object?>{
        ...workout,
        'description':
            'Detailed training breakdown, HR zones, and coach notes for workout #$id.',
        'coverImageUrl': '/assets/workouts/$id/cover.png',
        'titleImageUrl': '/assets/workouts/$id/title.png',
      });
      return;
    }

    if (method == 'GET' &&
        pathSegments.length == 4 &&
        pathSegments[0] == 'assets' &&
        pathSegments[1] == 'workouts') {
      final id = int.tryParse(pathSegments[2]);
      final name = pathSegments[3];
      if (id == null ||
          (name != 'cover.png' && name != 'title.png' && name != 'video.bin')) {
        request.response.statusCode = io.HttpStatus.notFound;
        await request.response.close();
        return;
      }

      if (name == 'video.bin') {
        await Future<void>.delayed(const Duration(milliseconds: 220));
        request.response.statusCode = io.HttpStatus.ok;
        request.response.headers.set(
          io.HttpHeaders.contentTypeHeader,
          'application/octet-stream',
        );
        final videoBytes = _assetVideoCache.putIfAbsent(
          id,
          () => _generateWorkoutVideoBytes(workoutId: id),
        );
        request.response.headers.contentLength = videoBytes.length;
        await _writeChunkedBytes(
          response: request.response,
          bytes: videoBytes,
          chunks: 22,
          delay: const Duration(milliseconds: 440),
        );
        return;
      }

      await Future<void>.delayed(const Duration(milliseconds: 260));
      request.response.statusCode = io.HttpStatus.ok;
      request.response.headers.contentType = io.ContentType('image', 'png');
      final cacheKey = '$id:$name';
      final imageBytes = _assetImageCache.putIfAbsent(cacheKey, () {
        return _generateWorkoutImageBytes(
          workoutId: id,
          kind: name == 'cover.png' ? _ImageKind.cover : _ImageKind.title,
        );
      });
      request.response.headers.contentLength = imageBytes.length;
      await _writeChunkedBytes(
        response: request.response,
        bytes: imageBytes,
        chunks: 8,
        delay: const Duration(milliseconds: 280),
      );
      return;
    }

    if (method == 'POST' && path == '/workouts') {
      final payload = await _readJson(request);
      final created = <String, Object?>{
        'id': _workouts.length + 1,
        'name': payload['name'] ?? 'Unnamed',
        'minutes': payload['minutes'] ?? 0,
      };
      _workouts.add(created);
      await _writeJson(request.response, io.HttpStatus.created, created);
      return;
    }

    if (method == 'POST' && path == '/workouts/upload') {
      final bytes = await request.fold<int>(0, (int sum, List<int> chunk) {
        return sum + chunk.length;
      });
      await _writeJson(request.response, io.HttpStatus.ok, <String, Object?>{
        'uploadedBytes': bytes,
      });
      return;
    }

    if (method == 'GET' && path == '/plans/export') {
      request.response.statusCode = io.HttpStatus.ok;
      request.response.headers.set(
        io.HttpHeaders.contentTypeHeader,
        'application/octet-stream',
      );
      request.response.headers.contentLength = 18;
      request.response.add(utf8.encode('chunk-1-'));
      await request.response.flush();
      await Future<void>.delayed(const Duration(milliseconds: 80));
      request.response.add(utf8.encode('chunk-2-'));
      await request.response.flush();
      await Future<void>.delayed(const Duration(milliseconds: 120));
      request.response.add(utf8.encode('chunk-3'));
      await request.response.close();
      return;
    }

    request.response.statusCode = io.HttpStatus.notFound;
    await request.response.close();
  }

  bool _isPublic(String path) => path.startsWith('/auth/');

  bool _isAuthorized(io.HttpRequest request) {
    final authHeader = request.headers.value(
      io.HttpHeaders.authorizationHeader,
    );
    return authHeader == 'Bearer $_validAccessToken';
  }

  Future<Map<String, Object?>> _readJson(io.HttpRequest request) async {
    final body = await utf8.decoder.bind(request).join();
    if (body.isEmpty) {
      return <String, Object?>{};
    }

    final decoded = jsonDecode(body) as Map<Object?, Object?>;
    return decoded.map(
      (Object? key, Object? value) => MapEntry(key.toString(), value),
    );
  }

  Future<void> _writeJson(
    io.HttpResponse response,
    int code,
    Object payload,
  ) async {
    response.statusCode = code;
    response.headers.contentType = io.ContentType.json;
    response.write(jsonEncode(payload));
    await response.close();
  }

  Future<void> _writeChunkedBytes({
    required io.HttpResponse response,
    required List<int> bytes,
    required int chunks,
    required Duration delay,
  }) async {
    final chunkSize = (bytes.length / chunks).ceil();
    var offset = 0;
    while (offset < bytes.length) {
      final end = (offset + chunkSize) > bytes.length
          ? bytes.length
          : offset + chunkSize;
      response.add(bytes.sublist(offset, end));
      await response.flush();
      offset = end;
      if (offset < bytes.length) {
        await Future<void>.delayed(delay);
      }
    }
    await response.close();
  }

  Future<void> close() => _server.close(force: true);
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

String _workoutNameFor(int id) {
  const names = <String>[
    'Morning Run',
    'Strength Session',
    'Intervals',
    'Yoga Mobility',
    'Upper Body Push',
    'Lower Body Power',
    'Core Stability',
    'Zone 2 Cardio',
    'Tempo Run',
    'Recovery Walk',
    'Full Body Circuit',
    'Mobility Reset',
    'Hill Sprints',
    'Kettlebell Complex',
    'Pilates Flow',
    'Rowing Intervals',
    'Bodyweight Blast',
    'Progressive Overload',
    'Endurance Builder',
    'Stretch and Breathe',
    'Metcon Challenge',
    'Tabata Burner',
    'Glute Focus',
    'Active Recovery',
  ];
  return names[(id - 1) % names.length];
}

enum _ImageKind { cover, title }

List<int> _generateWorkoutImageBytes({
  required int workoutId,
  required _ImageKind kind,
}) {
  final seed = workoutId * 31 + (kind == _ImageKind.cover ? 7 : 13);
  final start = _rgbFromSeed(seed);
  final end = _rgbFromSeed(seed + 19);
  final height = kind == _ImageKind.cover ? 200 : 140;
  return _encodePngGradient(width: 360, height: height, start: start, end: end);
}

List<int> _generateWorkoutVideoBytes({required int workoutId}) {
  final size = 900 * 1024;
  final bytes = Uint8List(size);
  for (var i = 0; i < size; i++) {
    bytes[i] = (workoutId * 17 + i * 13) & 0xFF;
  }
  return bytes;
}

_Rgb _rgbFromSeed(int seed) {
  final hash = (seed * 1103515245 + 12345) & 0x7fffffff;
  int channel(int shift) {
    return 64 + ((hash >> shift) & 0x7F);
  }

  return _Rgb(r: channel(0), g: channel(7), b: channel(14));
}

List<int> _encodePngGradient({
  required int width,
  required int height,
  required _Rgb start,
  required _Rgb end,
}) {
  final rowLength = 1 + (width * 3);
  final raw = Uint8List(rowLength * height);
  var offset = 0;

  for (var y = 0; y < height; y++) {
    raw[offset++] = 0; // No filter.
    final ty = height <= 1 ? 0.0 : y / (height - 1);
    for (var x = 0; x < width; x++) {
      final tx = width <= 1 ? 0.0 : x / (width - 1);
      final t = (tx * 0.72) + (ty * 0.28);
      raw[offset++] = _lerpChannel(start.r, end.r, t);
      raw[offset++] = _lerpChannel(start.g, end.g, t);
      raw[offset++] = _lerpChannel(start.b, end.b, t);
    }
  }

  final compressed = io.ZLibEncoder().convert(raw);

  final out = BytesBuilder(copy: false);
  out.add(const <int>[137, 80, 78, 71, 13, 10, 26, 10]); // PNG signature.

  final ihdr = ByteData(13)
    ..setUint32(0, width, Endian.big)
    ..setUint32(4, height, Endian.big)
    ..setUint8(8, 8) // Bit depth.
    ..setUint8(9, 2) // RGB.
    ..setUint8(10, 0) // Compression method.
    ..setUint8(11, 0) // Filter method.
    ..setUint8(12, 0); // No interlace.

  _writePngChunk(out: out, type: 'IHDR', data: ihdr.buffer.asUint8List());
  _writePngChunk(out: out, type: 'IDAT', data: compressed);
  _writePngChunk(out: out, type: 'IEND', data: const <int>[]);

  return out.takeBytes();
}

void _writePngChunk({
  required BytesBuilder out,
  required String type,
  required List<int> data,
}) {
  final typeBytes = ascii.encode(type);

  final lengthBytes = ByteData(4)..setUint32(0, data.length, Endian.big);
  out.add(lengthBytes.buffer.asUint8List());
  out.add(typeBytes);
  out.add(data);

  final crc = _crc32ForChunk(typeBytes, data);
  final crcBytes = ByteData(4)..setUint32(0, crc, Endian.big);
  out.add(crcBytes.buffer.asUint8List());
}

int _crc32ForChunk(List<int> typeBytes, List<int> data) {
  var crc = 0xFFFFFFFF;
  for (final b in typeBytes) {
    crc = _crc32Table[(crc ^ b) & 0xFF] ^ (crc >> 8);
  }
  for (final b in data) {
    crc = _crc32Table[(crc ^ b) & 0xFF] ^ (crc >> 8);
  }
  return (crc ^ 0xFFFFFFFF) & 0xFFFFFFFF;
}

int _lerpChannel(int start, int end, double t) {
  final value = (start + ((end - start) * t)).round();
  if (value < 0) {
    return 0;
  }
  if (value > 255) {
    return 255;
  }
  return value;
}

class _Rgb {
  const _Rgb({required this.r, required this.g, required this.b});

  final int r;
  final int g;
  final int b;
}

final List<int> _crc32Table = List<int>.generate(256, (int i) {
  var c = i;
  for (var k = 0; k < 8; k++) {
    c = (c & 1) != 0 ? (0xEDB88320 ^ (c >> 1)) : (c >> 1);
  }
  return c;
});
