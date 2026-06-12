import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

const int maxDocumentBytes = 5 * 1024 * 1024;
const int maxDocumentPhotoBytes = 1024 * 1024;

final ImagePicker _documentImagePicker = ImagePicker();

enum DocumentCaptureSource { camera, file }

class PendingDocumentAttachment {
  final String fileName;
  final String mimeType;
  final int sizeBytes;
  final String contentBase64;
  final Uint8List bytes;
  final bool isImage;

  const PendingDocumentAttachment({
    required this.fileName,
    required this.mimeType,
    required this.sizeBytes,
    required this.contentBase64,
    required this.bytes,
    required this.isImage,
  });
}

class DocumentAttachmentPicker {
  static Future<PendingDocumentAttachment?> pick({
    required DocumentCaptureSource source,
  }) async {
    if (source == DocumentCaptureSource.camera) {
      if (kIsWeb) {
        return _pickImageFile();
      }
      return _captureFromCamera();
    }
    return _pickAnyFile();
  }

  static Future<PendingDocumentAttachment?> _captureFromCamera() async {
    final photo = await _documentImagePicker.pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.rear,
      maxWidth: 2000,
      maxHeight: 2000,
      imageQuality: 90,
    );
    if (photo == null) {
      return null;
    }

    final bytes = await photo.readAsBytes();
    return _fromImageBytes(
      bytes,
      fileName: 'dokument_${DateTime.now().millisecondsSinceEpoch}.jpg',
    );
  }

  static Future<PendingDocumentAttachment?> _pickImageFile() async {
    final result = await FilePicker.platform.pickFiles(
      withData: true,
      allowMultiple: false,
      type: FileType.custom,
      allowedExtensions: kIsWeb
          ? const ['jpg', 'jpeg', 'png', 'webp', 'pdf', 'doc', 'docx', 'txt']
          : const [
              'jpg',
              'jpeg',
              'png',
              'webp',
              'heic',
              'heif',
              'pdf',
              'doc',
              'docx',
              'txt',
            ],
    );
    if (result == null || result.files.isEmpty) {
      return null;
    }
    return _fromPlatformFile(result.files.single);
  }

  static Future<PendingDocumentAttachment?> _pickAnyFile() async {
    final result = await FilePicker.platform.pickFiles(
      withData: true,
      allowMultiple: false,
      type: FileType.custom,
      allowedExtensions: const [
        'jpg',
        'jpeg',
        'png',
        'webp',
        'heic',
        'heif',
        'pdf',
        'doc',
        'docx',
        'txt',
      ],
    );
    if (result == null || result.files.isEmpty) {
      return null;
    }
    return _fromPlatformFile(result.files.single);
  }

  static PendingDocumentAttachment _fromPlatformFile(PlatformFile file) {
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) {
      throw StateError('Nie udało się odczytać pliku.');
    }

    final name = file.name.trim().isEmpty ? 'dokument' : file.name.trim();
    final mimeType = _guessMimeType(name, file.extension);
    final isImage = mimeType.startsWith('image/');

    if (isImage) {
      return _fromImageBytes(bytes, fileName: name);
    }

    if (bytes.length > maxDocumentBytes) {
      throw StateError('Plik jest za duży (max 5 MB).');
    }

    return PendingDocumentAttachment(
      fileName: name,
      mimeType: mimeType,
      sizeBytes: bytes.length,
      contentBase64: base64Encode(bytes),
      bytes: bytes,
      isImage: false,
    );
  }

  static PendingDocumentAttachment _fromImageBytes(
    Uint8List bytes, {
    required String fileName,
  }) {
    final compressed = _compressImage(bytes);
    final normalizedName = fileName.replaceAll(RegExp(r'\.[^.]+$'), '.jpg');
    return PendingDocumentAttachment(
      fileName: normalizedName,
      mimeType: 'image/jpeg',
      sizeBytes: compressed.length,
      contentBase64: base64Encode(compressed),
      bytes: compressed,
      isImage: true,
    );
  }

  static Uint8List _compressImage(Uint8List bytes) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      throw StateError(
        'Nie udało się przetworzyć zdjęcia. Użyj JPG lub PNG.',
      );
    }

    var working = decoded;
    if (working.width > 2000) {
      working = img.copyResize(working, width: 2000);
    }

    for (var quality = 90; quality >= 40; quality -= 10) {
      final encoded = Uint8List.fromList(img.encodeJpg(working, quality: quality));
      if (encoded.length <= maxDocumentPhotoBytes) {
        return encoded;
      }
    }

    working = img.copyResize(working, width: 1200);
    for (var quality = 85; quality >= 35; quality -= 10) {
      final encoded = Uint8List.fromList(img.encodeJpg(working, quality: quality));
      if (encoded.length <= maxDocumentPhotoBytes) {
        return encoded;
      }
    }

    throw StateError(
      'Zdjęcie jest za duże. Zrób jaśniejsze ujęcie i spróbuj ponownie.',
    );
  }

  static String _guessMimeType(String name, String? extension) {
    final ext = (extension ?? name.split('.').last).toLowerCase();
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'heic':
      case 'heif':
        return 'image/heic';
      case 'pdf':
        return 'application/pdf';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'txt':
        return 'text/plain';
      default:
        return 'application/octet-stream';
    }
  }
}

Uint8List decodeDocumentBase64(String contentBase64) {
  return base64Decode(contentBase64.replaceAll('\n', '').trim());
}

String defaultDocumentTitleFromFileName(String fileName) {
  final dotIndex = fileName.lastIndexOf('.');
  if (dotIndex <= 0) {
    return fileName;
  }
  return fileName.substring(0, dotIndex);
}
