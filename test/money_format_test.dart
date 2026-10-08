import 'package:flutter_test/flutter_test.dart';
import 'package:skill_link/core/format/money.dart';

void main() {
  test('formats loose stored amounts the same way', () {
    expect(formatRupees('1500'), 'Rs 1,500');
    expect(formatRupees('1,500'), 'Rs 1,500');
    expect(formatRupees('Rs. 1500'), 'Rs 1,500');
    expect(formatRupees('rs 250000'), 'Rs 250,000');
    expect(formatRupees(800), 'Rs 800');
  });

  test('keeps non-numeric text and handles empty values', () {
    expect(formatRupees('Negotiable'), 'Negotiable');
    expect(formatRupees(''), '');
    expect(formatRupees(null, empty: 'Not provided'), 'Not provided');
  });

  test('hourly rates append /hr only to real amounts', () {
    expect(formatHourlyRate('1500'), 'Rs 1,500/hr');
    expect(formatHourlyRate(''), '');
    expect(formatHourlyRate('Ask me'), 'Ask me');
  });
}
