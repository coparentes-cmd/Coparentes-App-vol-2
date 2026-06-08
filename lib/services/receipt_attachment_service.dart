import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

const int maxReceiptBytes = 512 * 1024;
const _uuid = Uuid();
final ImagePicker _imagePicker = ImagePicker();

enum ReceiptImageSource { camera, gallery }

class PendingReceiptImage {
  final String id;
  final String fileName;
  final String mimeType;
  final int sizeBytes;
  final String contentBase64;
  final Uint8List bytes;

  const PendingReceiptImage({
    required this.id,
    required this.fileName,
    required this.mimeType,
    required this.sizeBytes,
    required this.contentBase64,
    required this.bytes,
  });
}

class ReceiptParseResult {
  final String? title;
  final double? amount;
  final String? category;
  final DateTime? date;
  final String confidence;
  final String? rawTextPreview;

  const ReceiptParseResult({
    this.title,
    this.amount,
    this.category,
    this.date,
    required this.confidence,
    this.rawTextPreview,
  });

  factory ReceiptParseResult.fromJson(Map<String, dynamic> json) {
    DateTime? parsedDate;
    final dateRaw = json['date'] as String?;
    if (dateRaw != null && dateRaw.isNotEmpty) {
      parsedDate = DateTime.tryParse(dateRaw);
    }

    return ReceiptParseResult(
      title: json['title'] as String?,
      amount: json['amount'] == null
          ? null
          : (json['amount'] as num).toDouble(),
      category: json['category'] as String?,
      date: parsedDate,
      confidence: json['confidence'] as String? ?? 'low',
      rawTextPreview: json['rawTextPreview'] as String?,
    );
  }
}

class ReceiptAttachmentPicker {
  static Future<PendingReceiptImage?> pickReceiptImage({
    required ReceiptImageSource source,
  }) async {
    if (kIsWeb && source == ReceiptImageSource.camera) {
      return _pickFromGallery();
    }
    if (source == ReceiptImageSource.camera) {
      return _captureFromCamera();
    }
    return _pickFromGallery();
  }

  static Future<PendingReceiptImage?> _captureFromCamera() async {
    final photo = await _imagePicker.pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.rear,
      maxWidth: 1800,
      maxHeight: 1800,
      imageQuality: 88,
    );

    if (photo == null) {
      return null;
    }

    final bytes = await photo.readAsBytes();
    return _fromBytes(
      bytes,
      fileName: 'paragon_${DateTime.now().millisecondsSinceEpoch}.jpg',
      mimeType: 'image/jpeg',
    );
  }

  static Future<PendingReceiptImage?> _pickFromGallery() async {
    final result = await FilePicker.platform.pickFiles(
      withData: true,
      allowMultiple: false,
      type: FileType.custom,
      allowedExtensions: kIsWeb
          ? const ['jpg', 'jpeg', 'png', 'webp']
          : const ['jpg', 'jpeg', 'png', 'webp', 'heic', 'heif'],
    );

    if (result == null || result.files.isEmpty) {
      return null;
    }

    final file = result.files.single;
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) {
      throw StateError('Nie udało się odczytać zdjęcia paragonu.');
    }

    final name = file.name.trim().isEmpty ? 'paragon.jpg' : file.name.trim();
    return _fromBytes(
      bytes,
      fileName: name,
      mimeType: _guessMimeType(name, file.extension),
    );
  }

  static Future<PendingReceiptImage> _fromBytes(
    Uint8List bytes, {
    required String fileName,
    required String mimeType,
  }) async {
    final compressed = _compressForUpload(bytes);
    return PendingReceiptImage(
      id: 'rcpt_${_uuid.v4()}',
      fileName: fileName.replaceAll(RegExp(r'\.[^.]+$'), '.jpg'),
      mimeType: 'image/jpeg',
      sizeBytes: compressed.length,
      contentBase64: base64Encode(compressed),
      bytes: compressed,
    );
  }

  static Uint8List _compressForUpload(Uint8List bytes) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      throw StateError(
        'Nie udało się przetworzyć zdjęcia. Użyj JPG lub PNG (nie HEIC).',
      );
    }

    var working = decoded;
    if (working.width > 1600) {
      working = img.copyResize(working, width: 1600);
    }

    for (var quality = 88; quality >= 35; quality -= 8) {
      final encoded = Uint8List.fromList(img.encodeJpg(working, quality: quality));
      if (encoded.length <= maxReceiptBytes) {
        return encoded;
      }
    }

    working = img.copyResize(working, width: 1000);
    for (var quality = 80; quality >= 30; quality -= 10) {
      final encoded = Uint8List.fromList(img.encodeJpg(working, quality: quality));
      if (encoded.length <= maxReceiptBytes) {
        return encoded;
      }
    }

    throw StateError(
      'Zdjęcie jest za duże (max 512 KB). Zbliż paragon i spróbuj ponownie.',
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
      default:
        return 'image/jpeg';
    }
  }
}

Uint8List decodeReceiptBase64(String contentBase64) {
  return base64Decode(contentBase64.replaceAll('\n', '').trim());
}
