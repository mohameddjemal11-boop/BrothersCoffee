enum AccountRole { employee, manager }

enum BusinessDayStatus { open, closed }

enum BusinessDayEventType { opened, closed, reopened }

enum SaleStatus { draft, confirmed, cancelled }

enum SalePaymentMethod { cash }

enum AuditEventType {
  managerBootstrap,
  accountCreated,
  accountUpdated,
  accountArchived,
  categoryCreated,
  categoryUpdated,
  categoryArchived,
  productCreated,
  productUpdated,
  productArchived,
  saleConfirmed,
  saleCancelled,
  timeZoneChanged,
}
