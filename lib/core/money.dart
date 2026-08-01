import 'package:intl/intl.dart';

/// A TND amount stored exactly as integer millimes (1 TND = 1000 millimes).
extension type const Money(int millimes) implements int {
  const Money.zero() : this(0);

  Money operator +(Money other) => Money(millimes + other.millimes);
  Money operator -(Money other) => Money(millimes - other.millimes);
  Money operator *(int quantity) => Money(millimes * quantity);

  String format({String locale = 'fr_TN'}) {
    final formatter = NumberFormat.currency(
      locale: locale,
      name: 'TND',
      symbol: 'TND',
      decimalDigits: 3,
    );
    final absolute = millimes.abs();
    final wholeDinars = absolute ~/ millimesPerDinar;
    final fraction = (absolute % millimesPerDinar).toString().padLeft(3, '0');
    final zeroFraction = '${formatter.symbols.DECIMAL_SEP}000';
    final formattedWhole = formatter.format(wholeDinars);
    final fractionIndex = formattedWhole.lastIndexOf(zeroFraction);
    final exact = formattedWhole.replaceRange(
      fractionIndex,
      fractionIndex + zeroFraction.length,
      '${formatter.symbols.DECIMAL_SEP}$fraction',
    );
    return millimes < 0 ? '${formatter.symbols.MINUS_SIGN}$exact' : exact;
  }
}

const int millimesPerDinar = 1000;

Money sumMoney(Iterable<Money> amounts) =>
    amounts.fold(const Money.zero(), (total, amount) => total + amount);
