import 'dart:typed_data';

import 'file_download_stub.dart'
    if (dart.library.html) 'file_download_web.dart' as file_download;

Future<void> saveBytesAsFile({
  required String fileName,
  required String mimeType,
  required Uint8List bytes,
}) {
  return file_download.saveBytesAsFile(
    fileName: fileName,
    mimeType: mimeType,
    bytes: bytes,
  );
}
