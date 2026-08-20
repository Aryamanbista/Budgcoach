import 'package:intl/intl.dart';

class Formatters {
  /// Formats a double amount into Nepalese style grouping: NPR 1,23,450.00 or NPR 1,23,450
  static String formatNpr(double amount, {bool showSign = false}) {
    final absAmount = amount.abs();
    final format = NumberFormat.decimalPattern('en_IN');
    String formatted;

    // Check if it has a decimal part
    if (absAmount == absAmount.toInt()) {
      formatted = format.format(absAmount.toInt());
    } else {
      // Show two decimal places for fractional amounts
      formatted = NumberFormat('#,##,##0.00', 'en_IN').format(absAmount);
    }

    final sign = amount < 0 ? '-' : (showSign && amount > 0 ? '+' : '');
    return '${sign}NPR $formatted';
  }

  /// Formats a DateTime to DD/MM/YYYY
  static String formatDate(DateTime date) {
    return DateFormat('dd/MM/yyyy').format(date);
  }

  /// Returns festival names based on Nepali calendar alignment (e.g. October -> Dashain, November -> Tihar)
  static String getFestivalName(DateTime date) {
    if (date.month == 10) {
      return 'Dashain Festival';
    } else if (date.month == 11) {
      return 'Tihar Festival';
    }
    return '';
  }

  /// Returns a display string for a date (e.g., "Today", "Yesterday", or "DD/MM/YYYY")
  static String formatDateToWord(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final compareDate = DateTime(date.year, date.month, date.day);

    if (compareDate == today) {
      return 'TODAY';
    } else if (compareDate == yesterday) {
      return 'YESTERDAY';
    } else {
      return DateFormat('MMM dd, yyyy').format(date).toUpperCase();
    }
  }
}
