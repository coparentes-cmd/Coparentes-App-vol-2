import '../models/models.dart';
import 'calendar_date_utils.dart';

const swapRequestMessageHeader = 'Wniosek o zamianę dnia opieki';
const scheduleProposalMessageHeader = 'Propozycja grafiku opieki';
const exceptionRequestMessageHeader = 'Wniosek o zmianę opiekuna';

bool isSwapScheduleThread(String? category) => category == 'Zmiana grafiku';

bool isSwapRequestMessage(String content) {
  return content.trim().startsWith(swapRequestMessageHeader);
}

bool isScheduleProposalMessage(String content) {
  return content.trim().startsWith(scheduleProposalMessageHeader);
}

bool isExceptionRequestMessage(String content) {
  return content.trim().startsWith(exceptionRequestMessageHeader);
}

DateTime? parsePlDateFromText(String text) {
  final match = RegExp(r'(\d{2})\.(\d{2})\.(\d{4})').firstMatch(text);
  if (match == null) {
    return null;
  }
  return DateTime(
    int.parse(match.group(3)!),
    int.parse(match.group(2)!),
    int.parse(match.group(1)!),
  );
}

DateTime? _parseExceptionRangeStart(String content) {
  for (final line in content.split('\n')) {
    final trimmed = line.trim();
    if (!trimmed.startsWith('Okres:')) {
      continue;
    }
    final value = trimmed.substring('Okres:'.length).trim();
    final parts = value.split('–').map((part) => part.trim()).toList();
    return parsePlDateFromText(parts.first);
  }
  return null;
}

SwapRequest? findPendingSwapForMessage({
  required String messageContent,
  required String messageSenderId,
  required List<SwapRequest> swaps,
}) {
  if (!isSwapRequestMessage(messageContent)) {
    return null;
  }

  DateTime? original;
  DateTime? proposed;
  for (final line in messageContent.split('\n')) {
    final trimmed = line.trim();
    if (trimmed.startsWith('Oryginalny dzień:')) {
      original = parsePlDateFromText(trimmed);
    } else if (trimmed.startsWith('Proponowany dzień:')) {
      proposed = parsePlDateFromText(trimmed);
    }
  }

  final pending = swaps
      .where(
        (swap) =>
            swap.status == SwapStatus.pending &&
            swap.requesterId == messageSenderId,
      )
      .toList();

  if (pending.isEmpty) {
    return null;
  }

  if (original != null && proposed != null) {
    for (final swap in pending) {
      if (isSameCalendarDay(swap.originalDate, original) &&
          isSameCalendarDay(swap.proposedDate, proposed)) {
        return swap;
      }
    }
  }

  pending.sort((a, b) => b.createdAt.compareTo(a.createdAt));
  return pending.first;
}

CustodySchedule? findPendingScheduleForMessage({
  required String messageContent,
  required String messageSenderId,
  required CustodySchedule? schedule,
}) {
  if (!isScheduleProposalMessage(messageContent)) {
    return null;
  }
  if (schedule == null ||
      schedule.status != CustodyScheduleStatus.pendingApproval ||
      schedule.proposedById != messageSenderId) {
    return null;
  }
  return schedule;
}

CustodyException? findPendingExceptionForMessage({
  required String messageContent,
  required String messageSenderId,
  required List<CustodyException> exceptions,
}) {
  if (!isExceptionRequestMessage(messageContent)) {
    return null;
  }

  final rangeStart = _parseExceptionRangeStart(messageContent);
  final pending = exceptions
      .where(
        (item) =>
            item.status == CustodyExceptionStatus.pending &&
            item.requesterId == messageSenderId,
      )
      .toList();

  if (pending.isEmpty) {
    return null;
  }

  if (rangeStart != null) {
    for (final item in pending) {
      if (isSameCalendarDay(item.fromDate, rangeStart)) {
        return item;
      }
    }
  }

  pending.sort((a, b) => b.createdAt.compareTo(a.createdAt));
  return pending.first;
}

bool canRespondToSwapMessage({
  required SwapRequest swap,
  required String? viewerUserId,
}) {
  if (viewerUserId == null) {
    return false;
  }
  if (viewerUserId == swap.requesterId) {
    return false;
  }
  return swap.status == SwapStatus.pending;
}

bool canRespondToScheduleMessage({
  required CustodySchedule schedule,
  required String? viewerUserId,
}) {
  if (viewerUserId == null || viewerUserId == schedule.proposedById) {
    return false;
  }
  return schedule.status == CustodyScheduleStatus.pendingApproval;
}

bool canRespondToExceptionMessage({
  required CustodyException exception,
  required String? viewerUserId,
}) {
  if (viewerUserId == null || viewerUserId == exception.requesterId) {
    return false;
  }
  return exception.status == CustodyExceptionStatus.pending;
}
