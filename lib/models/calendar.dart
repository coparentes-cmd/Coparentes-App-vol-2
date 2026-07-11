import 'package:flutter/material.dart';

import 'enums.dart';

class CustodySlot {
  final String id;
  final DateTime date;
  final UserRole custodian;
  final String? handoverLocation;
  final String? handoverTime;
  final CustodySlotSource source;

  CustodySlot({
    required this.id,
    required this.date,
    required this.custodian,
    this.handoverLocation,
    this.handoverTime,
    this.source = CustodySlotSource.schedule,
  });

  CustodySlot copyWith({
    String? id,
    DateTime? date,
    UserRole? custodian,
    String? handoverLocation,
    String? handoverTime,
    CustodySlotSource? source,
  }) {
    return CustodySlot(
      id: id ?? this.id,
      date: date ?? this.date,
      custodian: custodian ?? this.custodian,
      handoverLocation: handoverLocation ?? this.handoverLocation,
      handoverTime: handoverTime ?? this.handoverTime,
      source: source ?? this.source,
    );
  }
}

class CustodyWeekPattern {
  final Map<String, UserRole> days;

  const CustodyWeekPattern(this.days);

  UserRole forWeekday(int weekday) {
    const keys = [
      'monday',
      'tuesday',
      'wednesday',
      'thursday',
      'friday',
      'saturday',
      'sunday',
    ];
    final index = weekday - 1;
    if (index < 0 || index >= keys.length) {
      return UserRole.parentA;
    }
    return days[keys[index]] ?? UserRole.parentA;
  }
}

class CustodySchedule {
  final String id;
  final CustodySchedulePattern patternType;
  final DateTime startDate;
  final DateTime? endDate;
  final CustodyWeekPattern weekA;
  final CustodyWeekPattern weekB;
  final String? handoverTime;
  final String? handoverLocation;
  final CustodyScheduleStatus status;
  final String proposedById;
  final String? approvedById;
  final DateTime? approvedAt;
  final DateTime createdAt;

  CustodySchedule({
    required this.id,
    required this.patternType,
    required this.startDate,
    this.endDate,
    required this.weekA,
    required this.weekB,
    this.handoverTime,
    this.handoverLocation,
    required this.status,
    required this.proposedById,
    this.approvedById,
    this.approvedAt,
    required this.createdAt,
  });

  String get patternLabel {
    switch (patternType) {
      case CustodySchedulePattern.weekAlternating:
        return 'Co tydzień na zmianę';
      case CustodySchedulePattern.everyOtherWeekend:
        return 'Co drugi weekend';
      case CustodySchedulePattern.customWeek:
        return 'Własny tydzień';
    }
  }
}

class CustodyException {
  final String id;
  final DateTime fromDate;
  final DateTime toDate;
  final UserRole custodian;
  final CustodyExceptionType exceptionType;
  final String? reason;
  final CustodyExceptionStatus status;
  final String requesterId;
  final String? responseNote;
  final DateTime createdAt;

  CustodyException({
    required this.id,
    required this.fromDate,
    required this.toDate,
    required this.custodian,
    required this.exceptionType,
    this.reason,
    required this.status,
    required this.requesterId,
    this.responseNote,
    required this.createdAt,
  });

  bool coversDay(DateTime day) {
    final target = DateTime(day.year, day.month, day.day);
    final from = DateTime(fromDate.year, fromDate.month, fromDate.day);
    final to = DateTime(toDate.year, toDate.month, toDate.day);
    return !target.isBefore(from) && !target.isAfter(to);
  }
}

class CalendarEvent {
  final String id;
  final String title;
  final String? description;
  final DateTime startDate;
  final DateTime? endDate;
  final EventType type;
  final String? childId;
  final String createdBy;
  final String? location;

  CalendarEvent({
    required this.id,
    required this.title,
    this.description,
    required this.startDate,
    this.endDate,
    required this.type,
    this.childId,
    required this.createdBy,
    this.location,
  });

  Color get typeColor {
    switch (type) {
      case EventType.school:
        return const Color(0xFF1565C0);
      case EventType.medical:
        return const Color(0xFFD32F2F);
      case EventType.activity:
        return const Color(0xFFF57C00);
      case EventType.handover:
        return const Color(0xFF00897B);
      case EventType.holiday:
        return const Color(0xFF6A1B9A);
      case EventType.other:
        return const Color(0xFF546E7A);
    }
  }

  IconData get typeIcon {
    switch (type) {
      case EventType.school:
        return Icons.school;
      case EventType.medical:
        return Icons.medical_services;
      case EventType.activity:
        return Icons.sports_soccer;
      case EventType.handover:
        return Icons.swap_horiz;
      case EventType.holiday:
        return Icons.beach_access;
      case EventType.other:
        return Icons.event;
    }
  }
}

class SwapRequest {
  final String id;
  final String requesterId;
  final String requesterName;
  final DateTime originalDate;
  final DateTime proposedDate;
  final String? reason;
  final SwapStatus status;
  final DateTime createdAt;
  final String? responseNote;

  SwapRequest({
    required this.id,
    required this.requesterId,
    required this.requesterName,
    required this.originalDate,
    required this.proposedDate,
    this.reason,
    required this.status,
    required this.createdAt,
    this.responseNote,
  });

  Color get statusColor {
    switch (status) {
      case SwapStatus.pending:
        return const Color(0xFFF57C00);
      case SwapStatus.accepted:
        return const Color(0xFF388E3C);
      case SwapStatus.rejected:
        return const Color(0xFFD32F2F);
      case SwapStatus.counterProposed:
        return const Color(0xFF1565C0);
    }
  }

  String get statusLabel {
    switch (status) {
      case SwapStatus.pending:
        return 'Oczekuje';
      case SwapStatus.accepted:
        return 'Zaakceptowany';
      case SwapStatus.rejected:
        return 'Odrzucony';
      case SwapStatus.counterProposed:
        return 'Kontrpropozycja';
    }
  }
}
