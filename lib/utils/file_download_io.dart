import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

Future<void> saveBytesAsFile({
  required String fileName,
  required String mimeType,
  required Uint8List bytes,
}) async {
  final safeName = _sanitizeFileName(fileName);
  final directory = await _resolveDownloadDirectory();
  final file = File(p.join(directory.path, safeName));
  _assertPathInsideDirectory(file: file, directory: directory);
  await file.parent.create(recursive: true);
  await file.writeAsBytes(bytes, flush: true);
}

/// Keeps only a basename with a safe character whitelist (no path segments).
String _sanitizeFileName(String fileName) {
  var name = p.basename(fileName.trim());
  // Strip traversal / separators that basename may leave on some inputs.
  name = name.replaceAll('..', '');
  name = name.replaceAll(RegExp(r'[/\\]'), '_');
  name = name.replaceAll(RegExp(r'[^a-zA-Z0-9_\-.]'), '_');
  name = name.replaceAll(RegExp(r'_+'), '_');
  name = name.replaceAll(RegExp(r'^\.+'), '');

  if (name.isEmpty || name == '.' || name == '..') {
    return 'coparentes-download.bin';
  }

  return name;
}

void _assertPathInsideDirectory({
  required File file,
  required Directory directory,
}) {
  final root = p.normalize(directory.absolute.path);
  final target = p.normalize(file.absolute.path);
  if (!p.isWithin(root, target)) {
    throw ArgumentError(
      'Invalid download path: "$target" escapes directory "$root"',
    );
  }
}

Future<Directory> _resolveDownloadDirectory() async {
  final downloads = await getDownloadsDirectory();
  if (downloads != null) {
    return downloads;
  }

  final documents = await getApplicationDocumentsDirectory();
  return Directory(p.join(documents.path, 'Coparentes'));
}
