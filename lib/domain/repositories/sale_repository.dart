import '../entities/sale.dart';

abstract interface class SaleRepository {
  Future<SaleRecord> confirmCashSale({
    required String accountId,
    required List<SaleDraftLine> lines,
  });

  Future<List<SaleRecord>> listForBusinessDate({
    required String managerAccountId,
    required String businessDate,
  });

  Future<SaleRecord> cancelSale({
    required String managerAccountId,
    required String saleId,
    required String reason,
  });
}
