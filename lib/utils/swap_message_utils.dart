import '../models/models.dart';
import 'calendar_date_utils.dart';

const swapRequestMessageHeader = 'Wniosek o zamianę dnia opieki';

bool isSwapScheduleThread(String? category) => category == 'Zmiana grafiku';

bool isSwapRequestMessage(String content) {
  return content.trim().startsWith(swapRequestMessageHeader);
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
