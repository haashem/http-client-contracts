import 'dart:typed_data';

class HttpMultipartFile {
  final String field;
  final String filename;
  final Uint8List bytes;

  HttpMultipartFile({
    required this.field,
    required this.filename,
    required List<int> bytes,
  }) : bytes = Uint8List.fromList(bytes);
}
