import 'package:intl/intl.dart';

/// A TND amount stored exactly as integer millimes (1 TND = 1000 millimes).
extension type const Money(int millimes) implements int {
  const Money.zero() : this(0);

  Money operator +(Money other) => Money(millimes + other.millimes);
  Money operator -(Money other) => Money(millimes - other.millimes);
  Money operator *(int quantity) => Money(millimes * quantity);

  String formatMillimes({String locale = 'fr_TN', required String unit}) =>
      '${NumberFormat.decimalPattern(locale).format(millimes)} $unit';
}

const int millimesPerDinar = 1000;

Money? parseMillimes(String value) {
  final normalized = value.trim();
  if (!RegExp(r'^\d+$').hasMatch(normalized)) return null;
  return Money(int.parse(normalized));
}

Money sumMoney(Iterable<Money> amounts) =>
    amounts.fold(const Money.zero(), (total, amount) => total + amount);
