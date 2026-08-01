import '../../core/money.dart';
import '../entities/business_day.dart';

abstract interface class BusinessDayRepository {
  Future<BusinessDayRecord?> getOpenDay({required String accountId});

  Future<BusinessDayRecord> closeOpenDay({
    required String accountId,
    Money? countedCash,
  });

  Future<BusinessDayRecord> reopenDay({
    required String managerAccountId,
    required String businessDayId,
    required String reason,
  });
}
