import '../../../data/api/app_api_client.dart';
import '../../../models/models.dart';

String formatSwapDate(DateTime date) {
  return '${date.day.toString().padLeft(2, '0')}.'
      '${date.month.toString().padLeft(2, '0')}.'
      '${date.year}';
}

String formatScheduleRange(CustodySchedule schedule) {
  final start =
      '${schedule.startDate.day}.${schedule.startDate.month}.${schedule.startDate.year}';
  final end = schedule.endDate;
  if (end == null) {
    return start;
  }
  return '$start – ${end.day}.${end.month}.${end.year}';
}

String calendarActionError(Object error, String actionLabel) {
  if (error is StateError && error.message == 'schedule_locked') {
    return 'Grafik jest zablokowany. Zmiany wymagają akceptacji drugiego rodzica.';
  }
  if (error is ApiException) {
    if (error.message == 'invalid_request') {
      return 'Nieprawidłowe dane $actionLabel. Sprawdź wybrane daty.';
    }
    if (error.message == 'swap_not_allowed') {
      return 'Nie możesz odpowiedzieć na własny wniosek o zamianę.';
    }
    if (error.message == 'schedule_not_active') {
      return 'Zmiany dni są możliwe dopiero po zaakceptowaniu grafiku opieki.';
    }
    if (error.message == 'schedule_locked') {
      return 'Grafik jest zablokowany. Zmiany wymagają akceptacji drugiego rodzica.';
    }
    if (error.message == 'schedule_not_allowed' ||
        error.message == 'exception_not_allowed') {
      return 'Nie możesz odpowiedzieć na własną prośbę.';
    }
    if (error.statusCode >= 500) {
      return 'Błąd serwera. Spróbuj ponownie za chwilę.';
    }
  }
  return 'Nie udało się wysłać $actionLabel.';
}
