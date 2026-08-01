import '../../core/money.dart';
import 'enums.dart';

class SaleDraftLine {
  const SaleDraftLine({required this.productId, required this.quantity});

  final String productId;
  final int quantity;
}

class SaleLineSnapshot {
  const SaleLineSnapshot({
    required this.id,
    required this.productId,
    required this.productName,
    required this.unitPrice,
    required this.quantity,
    required this.lineTotal,
    required this.displayOrder,
  });

  final String id;
  final String productId;
  final String productName;
  final Money unitPrice;
  final int quantity;
  final Money lineTotal;
  final int displayOrder;
}

class SaleRecord {
  const SaleRecord({
    required this.id,
    required this.businessDayId,
    required this.businessDate,
    required this.displayNumber,
    required this.status,
    required this.creatorAccountId,
    required this.creatorName,
    required this.confirmedAt,
    required this.total,
    required this.lines,
    this.cancelledAt,
    this.cancelledByAccountId,
    this.cancellationReason,
  });

  final String id;
  final String businessDayId;
  final String businessDate;
  final int displayNumber;
  final SaleStatus status;
  final String creatorAccountId;
  final String creatorName;
  final DateTime confirmedAt;
  final Money total;
  final List<SaleLineSnapshot> lines;
  final DateTime? cancelledAt;
  final String? cancelledByAccountId;
  final String? cancellationReason;
}

enum SaleFailureCode {
  emptyBasket,
  invalidQuantity,
  duplicateProduct,
  inactiveAccount,
  unavailableProduct,
  previousBusinessDayOpen,
  managerRequired,
  saleNotFound,
  saleNotCancellable,
  cancellationReasonRequired,
}

class SaleFailure implements Exception {
  const SaleFailure(this.code, [this.details]);

  final SaleFailureCode code;
  final String? details;

  @override
  String toString() =>
      'SaleFailure($code${details == null ? '' : ': $details'})';
}
