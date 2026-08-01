import 'enums.dart';

class Account {
  const Account({
    required this.id,
    required this.displayName,
    required this.role,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
    required this.revision,
  });

  final String id;
  final String displayName;
  final AccountRole role;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int revision;
}
