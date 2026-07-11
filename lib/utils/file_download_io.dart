import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

Future<void> saveBytesAsFile({
  required String fileName,
  required String mimeType,
  required Uint8List bytes,
}) async {
  final safeName = _sanitizeFileName(fileName);
  final directory = await _resolveDownloadDirectory();
  final file = File('${directory.path}/$safeName');
  await file.parent.create(recursive: true);
  await file.writeAsBytes(bytes, flush: true);
}

String _sanitizeFileName(String fileName) {
  final trimmed = fileName.trim();
  if (trimmed.isEmpty) {
    return 'coparentes-download.bin';
  }

  return trimmed
      .replaceAll('/', '_')
      .replaceAll('\\', '_')
      .replaceAll(':', '_');
}

Future<Directory> _resolveDownloadDirectory() async {
  final downloads = await getDownloadsDirectory();
  if (downloads != null) {
    return downloads;
  }

  final documents = await getApplicationDocumentsDirectory();
  return Directory('${documents.path}/Coparentes');
}
