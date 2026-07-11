import 'package:flutter/material.dart';

import 'enums.dart';

class ExportJob {
  final String id;
  final ExportType type;
  final DateTime fromDate;
  final DateTime toDate;
  final String status;
  final String? downloadUrl;
  final String? manifestHash;
  final DateTime createdAt;

  ExportJob({
    required this.id,
    required this.type,
    required this.fromDate,
    required this.toDate,
    required this.status,
    this.downloadUrl,
    this.manifestHash,
    required this.createdAt,
  });

  String get typeLabel {
    switch (type) {
      case ExportType.messages:
        return 'Wiadomości';
      case ExportType.calendar:
        return 'Kalendarz';
      case ExportType.finances:
        return 'Finanse';
      case ExportType.fullPack:
        return 'Pełny pakiet';
    }
  }

  IconData get typeIcon {
    switch (type) {
      case ExportType.messages:
        return Icons.chat;
      case ExportType.calendar:
        return Icons.calendar_month;
      case ExportType.finances:
        return Icons.account_balance_wallet;
      case ExportType.fullPack:
        return Icons.folder_special;
    }
  }
}

extension ExportTypeExtension on ExportType {
  String get typeLabel {
    switch (this) {
      case ExportType.messages:
        return 'Wiadomości';
      case ExportType.calendar:
        return 'Kalendarz';
      case ExportType.finances:
        return 'Finanse';
      case ExportType.fullPack:
        return 'Pełny pakiet';
    }
  }

  IconData get typeIcon {
    switch (this) {
      case ExportType.messages:
        return Icons.chat;
      case ExportType.calendar:
        return Icons.calendar_month;
      case ExportType.finances:
        return Icons.account_balance_wallet;
      case ExportType.fullPack:
        return Icons.folder_special;
    }
  }
}
