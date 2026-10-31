import 'package:intl/intl.dart';

class DateFormatter {
  static final DateFormat _dateTimeFormat = DateFormat('dd MMM yyyy, HH:mm', 'id_ID');
  static final DateFormat _dateFormat = DateFormat('dd MMMM yyyy', 'id_ID');
  static final DateFormat _dateShortFormat = DateFormat('dd/MM/yyyy');
  static final DateFormat _timeFormat = DateFormat('HH:mm');
  static final DateFormat _fileDateFormat = DateFormat('yyyyMMdd_HHmmss');

  static String formatDateTime(DateTime? dateTime) {
    if (dateTime == null) return '-';
    try {
      return _dateTimeFormat.format(dateTime);
    } catch (_) {
      return dateTime.toString().substring(0, 16);
    }
  }

  static String formatDate(DateTime? dateTime) {
    if (dateTime == null) return '-';
    try {
      return _dateFormat.format(dateTime);
    } catch (_) {
      return dateTime.toString().substring(0, 10);
    }
  }

  static String formatDateFull(DateTime? dateTime) {
    return formatDate(dateTime);
  }

  static String formatDateShort(DateTime? dateTime) {
    if (dateTime == null) return '-';
    try {
      return _dateShortFormat.format(dateTime);
    } catch (_) {
      return dateTime.toString().substring(0, 10);
    }
  }

  static String formatTime(DateTime? dateTime) {
    if (dateTime == null) return '-';
    try {
      return _timeFormat.format(dateTime);
    } catch (_) {
      return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    }
  }

  static String forFileName(DateTime dateTime) {
    return _fileDateFormat.format(dateTime);
  }
}
