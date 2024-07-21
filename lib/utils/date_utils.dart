import 'package:intl/intl.dart';

class DateUtils {
  static DateTime getNextClassDate(String day, String time) {
    final now = DateTime.now();
    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday'
    ];
    final classDay = days.indexOf(day) + 1;

    final cleanedTime = cleanTimeString(time);
    final timeFormat = DateFormat('hh:mm a');
    final classTime = timeFormat.parse(cleanedTime);

    final classDate = DateTime(
        now.year, now.month, now.day, classTime.hour, classTime.minute);

    int daysUntilClass = (classDay - now.weekday) % 7;
    if (daysUntilClass <= 0) {
      daysUntilClass += 7;
    }

    return classDate.add(Duration(days: daysUntilClass));
  }

  static String cleanTimeString(String time) {
    return time.replaceAll(RegExp(r'[^\x20-\x7E]'), '');
  }

  static DateTime parseClassTime(String timeString) {
    final now = DateTime.now();
    final timeFormat = DateFormat('hh:mm a');
    final parsedTime = timeFormat.parse(timeString);
    return DateTime(
        now.year, now.month, now.day, parsedTime.hour, parsedTime.minute);
  }
}
