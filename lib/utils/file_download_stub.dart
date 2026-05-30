import 'dart:typed_data';

Future<void> saveBytesAsFile({
  required String fileName,
  required String mimeType,
  required Uint8List bytes,
}) async {
  throw UnsupportedError('Pobieranie plików dostępne tylko w wersji web.');
}
