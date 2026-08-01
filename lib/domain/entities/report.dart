import '../../core/money.dart';
import 'business_day.dart';

class SalesReport {
  const SalesReport({
    required this.startDate,
    required this.endDate,
    required this.grossSales,
    required this.cancellations,
    required this.netSales,
    required this.confirmedSaleCount,
    required this.cancelledSaleCount,
    required this.days,
    required this.products,
    required this.categories,
    required this.employees,
  });

  final String startDate;
  final String endDate;
  final Money grossSales;
  final Money cancellations;
  final Money netSales;
  final int confirmedSaleCount;
  final int cancelledSaleCount;
  final List<BusinessDayRecord> days;
  final List<ReportBreakdownRow> products;
  final List<ReportBreakdownRow> categories;
  final List<ReportBreakdownRow> employees;
}

class ReportBreakdownRow {
  const ReportBreakdownRow({
    required this.id,
    required this.label,
    required this.quantity,
    required this.value,
  });

  final String id;
  final String label;
  final int quantity;
  final Money value;
}

enum ReportFailureCode { managerRequired, inactiveAccount, invalidDateRange }

class ReportFailure implements Exception {
  const ReportFailure(this.code);

  final ReportFailureCode code;
}
