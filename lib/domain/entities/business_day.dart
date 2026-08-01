import '../../core/money.dart';
import 'enums.dart';

class BusinessDayRecord {
  const BusinessDayRecord({
    required this.id,
    required this.businessDate,
    required this.status,
    required this.openedAt,
    required this.openedByAccountId,
    required this.canViewFinancials,
    this.closedAt,
    this.closedByAccountId,
    this.expectedCash,
    this.countedCash,
    this.variance,
  });

  final String id;
  final String businessDate;
  final BusinessDayStatus status;
  final DateTime openedAt;
  final String openedByAccountId;
  final DateTime? closedAt;
  final String? closedByAccountId;
  final bool canViewFinancials;
  final Money? expectedCash;
  final Money? countedCash;
  final Money? variance;
}

enum BusinessDayFailureCode {
  inactiveAccount,
  managerRequired,
  noOpenDay,
  dayNotFound,
  dayNotOpen,
  dayNotClosed,
  reopenReasonRequired,
  anotherDayOpen,
  invalidCashCount,
}

class BusinessDayFailure implements Exception {
  const BusinessDayFailure(this.code, [this.details]);

  final BusinessDayFailureCode code;
  final String? details;

  @override
  String toString() =>
      'BusinessDayFailure($code${details == null ? '' : ': $details'})';
}
