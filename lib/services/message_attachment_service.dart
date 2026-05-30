import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:uuid/uuid.dart';

import '../models/models.dart';

const int maxMessageAttachmentBytes = 256 * 1024;
const int maxMessageAttachmentsPerMessage = 3;

const _uuid = Uuid();

class PendingMessageAttachment {
  final String id;
  final String name;
  final String type;
  final int sizeBytes;
  final String contentBase64;

  const PendingMessageAttachment({
    required this.id,
    required this.name,
    required this.type,
    required this.sizeBytes,
    required this.contentBase64,
  });

  Map<String, dynamic> toApiPayload() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'sizeBytes': sizeBytes,
      'contentBase64': contentBase64,
    };
  }

  MessageAttachment toMessageAttachment() {
    return MessageAttachment(
      id: id,
      name: name,
      type: type,
      sizeBytes: sizeBytes,
    );
  }
}

class MessageAttachmentPicker {
  static Future<PendingMessageAttachment?> pickAttachment() async {
    final result = await FilePicker.platform.pickFiles(
      withData: true,
      allowMultiple: false,
    );

    if (result == null || result.files.isEmpty) {
      return null;
    }

    final file = result.files.single;
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) {
      throw StateError('Nie udało się odczytać pliku.');
    }

    if (bytes.length > maxMessageAttachmentBytes) {
      throw StateError('Plik jest za duży (max 256 KB).');
    }

    final name = file.name.trim().isEmpty ? 'zalacznik' : file.name.trim();
    final type = _guessMimeType(name, file.extension);

    return PendingMessageAttachment(
      id: 'att_${_uuid.v4()}',
      name: name,
      type: type,
      sizeBytes: bytes.length,
      contentBase64: base64Encode(bytes),
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

Uint8List decodeAttachmentBase64(String contentBase64) {
  return base64Decode(contentBase64.replaceAll('\n', '').trim());
}

String formatAttachmentSize(int bytes) {
  if (bytes < 1024) {
    return '$bytes B';
  }
  if (bytes < 1024 * 1024) {
    return '${(bytes / 1024).toStringAsFixed(1)} KB';
  }
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}
