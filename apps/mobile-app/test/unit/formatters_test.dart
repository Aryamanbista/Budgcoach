import 'package:budgcoach/core/utils/formatters.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Formatters.formatNpr', () {
    test('uses Nepalese digit grouping', () {
      expect(Formatters.formatNpr(123450), 'NPR 1,23,450');
    });

    test('preserves two decimal places for fractional values', () {
      expect(Formatters.formatNpr(1234.5), 'NPR 1,234.50');
    });

    test('formats negative and explicitly signed positive values', () {
      expect(Formatters.formatNpr(-850), '-NPR 850');
      expect(Formatters.formatNpr(5000, showSign: true), '+NPR 5,000');
    });
  });

  group('date formatting', () {
    test('formats numeric date', () {
      expect(Formatters.formatDate(DateTime(2026, 8, 14)), '14/08/2026');
    });

    test('identifies Dashain and Tihar seasons', () {
      expect(
        Formatters.getFestivalName(DateTime(2026, 10, 1)),
        'Dashain Festival',
      );
      expect(
        Formatters.getFestivalName(DateTime(2026, 11, 1)),
        'Tihar Festival',
      );
      expect(Formatters.getFestivalName(DateTime(2026, 9, 1)), isEmpty);
    });

    test('uses today and yesterday labels', () {
      final today = DateTime.now();
      final yesterday = today.subtract(const Duration(days: 1));

      expect(Formatters.formatDateToWord(today), 'TODAY');
      expect(Formatters.formatDateToWord(yesterday), 'YESTERDAY');
    });
  });
}
