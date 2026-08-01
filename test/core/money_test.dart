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

  test('formats TND with three fractional digits', () {
    final formatted = const Money(1234).format(locale: 'fr_TN');

    expect(formatted, contains('1,234'));
    expect(formatted, contains('TND'));
  });

  test(
    'formats large and negative values without floating-point conversion',
    () {
      expect(const Money(-5).format(locale: 'fr_TN'), contains('-0,005'));
      expect(
        const Money(9007199254740993).format(locale: 'en_US'),
        contains('9,007,199,254,740.993'),
      );
    },
  );
}
