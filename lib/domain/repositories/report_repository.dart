import '../entities/report.dart';

abstract interface class ReportRepository {
  Future<SalesReport> buildSalesReport({
    required String managerAccountId,
    required String startDate,
    required String endDate,
  });
}
