import 'package:brothers_coffee_pos/core/money.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('money arithmetic stays exact in millimes', () {
    const unitPrice = Money(1350);
    final total = unitPrice * 3 + const Money(50) - const Money(100);

    expect(total.millimes, 4000);
    expect(
      sumMoney([const Money(1), const Money(2), const Money(3)]).millimes,
      6,
    );
  });

  test('formats UI amounts directly as integer millimes', () {
    final formatted = const Money(
      1234,
    ).formatMillimes(locale: 'en_US', unit: 'millimes');

    expect(formatted, '1,234 millimes');
  });

  test(
    'formats large and negative values without floating-point conversion',
    () {
      expect(
        const Money(-5).formatMillimes(locale: 'en_US', unit: 'millimes'),
        '-5 millimes',
      );
      expect(
        const Money(
          9007199254740993,
        ).formatMillimes(locale: 'en_US', unit: 'millimes'),
        '9,007,199,254,740,993 millimes',
      );
    },
  );

  test('parses only integer millime input', () {
    expect(parseMillimes('1500'), const Money(1500));
    expect(parseMillimes(' 1500 '), const Money(1500));
    expect(parseMillimes('1.5'), isNull);
    expect(parseMillimes('1,5'), isNull);
  });
}
