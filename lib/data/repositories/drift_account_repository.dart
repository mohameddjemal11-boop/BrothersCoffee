import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../domain/entities/account.dart' as domain;
import '../../domain/entities/enums.dart';
import '../../domain/repositories/account_administration_repository.dart';
import '../../domain/repositories/account_repository.dart';
import '../database/app_database.dart';
import '../security/pin_hasher.dart';

class DriftAccountRepository
    implements AccountRepository, AccountAdministrationRepository {
  DriftAccountRepository(this._database, {PinHasher? pinHasher, Uuid? uuid})
    : _pinHasher = pinHasher ?? PinHasher(),
      _uuid = uuid ?? const Uuid();

  final AppDatabase _database;
  final PinHasher _pinHasher;
  final Uuid _uuid;

  @override
  Future<domain.Account> bootstrapManager({
    required String displayName,
    required String pin,
  }) async {
    final name = _validName(displayName);
    return _database.transaction(() async {
      final existing =
          await (_database.select(_database.accounts)
                ..where((row) => row.role.equals(AccountRole.manager.name))
                ..limit(1))
              .getSingleOrNull();
      if (existing != null) return _map(existing);
      final manager = await _insert(
        name: name,
        role: AccountRole.manager,
        pin: pin,
      );
      await _appendAudit(
        type: AuditEventType.managerBootstrap,
        entityId: manager.id,
        actorAccountId: manager.id,
        details: {'displayName': manager.displayName},
      );
      return manager;
    });
  }

  @override
  Future<domain.Account?> authenticate(String accountId, String pin) async {
    final row =
        await (_database.select(_database.accounts)..where(
              (item) => item.id.equals(accountId) & item.isActive.equals(true),
            ))
            .getSingleOrNull();
    if (row == null) return null;
    final valid = await _pinHasher.verify(
      pin,
      hash: row.pinHash,
      salt: row.pinSalt,
    );
    return valid ? _map(row) : null;
  }

  @override
  Future<List<domain.Account>> listActive() async {
    final rows =
        await (_database.select(_database.accounts)
              ..where((row) => row.isActive.equals(true))
              ..orderBy([(row) => OrderingTerm.asc(row.displayName)]))
            .get();
    return rows.map(_map).toList(growable: false);
  }

  @override
  Future<List<domain.Account>> listForManagement({
    required String managerAccountId,
  }) async {
    await _activeManager(managerAccountId);
    return listActive();
  }

  @override
  Future<domain.Account> createEmployee({
    required String managerAccountId,
    required String displayName,
    required String pin,
  }) => _database.transaction(() async {
    final manager = await _activeManager(managerAccountId);
    final employee = await _insert(
      name: _validName(displayName),
      role: AccountRole.employee,
      pin: pin,
    );
    await _appendAudit(
      type: AuditEventType.accountCreated,
      entityId: employee.id,
      actorAccountId: manager.id,
      details: {
        'displayName': employee.displayName,
        'role': employee.role.name,
      },
    );
    return employee;
  });

  @override
  Future<domain.Account> updateAccount({
    required String managerAccountId,
    required String accountId,
    String? displayName,
    String? pin,
  }) => _database.transaction(() async {
    final manager = await _activeManager(managerAccountId);
    final current = await _findRow(accountId);
    PinDigest? digest;
    if (pin != null) digest = await _pinHasher.hash(pin);
    final now = DateTime.now().toUtc();
    await (_database.update(
      _database.accounts,
    )..where((row) => row.id.equals(accountId))).write(
      AccountsCompanion(
        displayName: displayName == null
            ? const Value.absent()
            : Value(_validName(displayName)),
        pinHash: digest == null ? const Value.absent() : Value(digest.hash),
        pinSalt: digest == null ? const Value.absent() : Value(digest.salt),
        updatedAt: Value(now),
        revision: Value(current.revision + 1),
      ),
    );
    await _appendAudit(
      type: AuditEventType.accountUpdated,
      entityId: accountId,
      actorAccountId: manager.id,
      details: {
        if (displayName != null) 'displayName': displayName.trim(),
        'pinChanged': pin != null,
      },
    );
    return _find(accountId);
  });

  @override
  Future<void> archiveEmployee({
    required String managerAccountId,
    required String accountId,
  }) => _database.transaction(() async {
    final manager = await _activeManager(managerAccountId);
    final current = await _findRow(accountId);
    if (current.role == AccountRole.manager.name) {
      throw const domain.AccountFailure(
        domain.AccountFailureCode.cannotArchiveManager,
      );
    }
    final now = DateTime.now().toUtc();
    await (_database.update(
      _database.accounts,
    )..where((row) => row.id.equals(accountId))).write(
      AccountsCompanion(
        isActive: const Value(false),
        archivedAt: Value(now),
        updatedAt: Value(now),
        revision: Value(current.revision + 1),
      ),
    );
    await _appendAudit(
      type: AuditEventType.accountArchived,
      entityId: accountId,
      actorAccountId: manager.id,
      details: {'displayName': current.displayName},
    );
  });

  Future<domain.Account> _insert({
    required String name,
    required AccountRole role,
    required String pin,
  }) async {
    final digest = await _pinHasher.hash(pin);
    final now = DateTime.now().toUtc();
    final id = _uuid.v4();
    await _database
        .into(_database.accounts)
        .insert(
          AccountsCompanion.insert(
            id: id,
            displayName: name,
            role: role.name,
            pinHash: digest.hash,
            pinSalt: digest.salt,
            createdAt: now,
            updatedAt: now,
          ),
        );
    return _find(id);
  }

  Future<Account> _activeManager(String accountId) async {
    final account =
        await (_database.select(_database.accounts)..where(
              (row) => row.id.equals(accountId) & row.isActive.equals(true),
            ))
            .getSingleOrNull();
    if (account == null) {
      throw const domain.AccountFailure(
        domain.AccountFailureCode.inactiveManager,
      );
    }
    if (account.role != AccountRole.manager.name) {
      throw const domain.AccountFailure(
        domain.AccountFailureCode.managerRequired,
      );
    }
    return account;
  }

  Future<Account> _findRow(String id) async {
    final account = await (_database.select(
      _database.accounts,
    )..where((row) => row.id.equals(id))).getSingleOrNull();
    if (account == null) {
      throw const domain.AccountFailure(
        domain.AccountFailureCode.accountNotFound,
      );
    }
    return account;
  }

  Future<domain.Account> _find(String id) async => _map(await _findRow(id));

  String _validName(String name) {
    final value = name.trim();
    if (value.isEmpty) {
      throw const domain.AccountFailure(domain.AccountFailureCode.nameRequired);
    }
    return value;
  }

  Future<void> _appendAudit({
    required AuditEventType type,
    required String entityId,
    required String actorAccountId,
    required Map<String, Object> details,
  }) => _database
      .into(_database.auditEvents)
      .insert(
        AuditEventsCompanion.insert(
          id: _uuid.v4(),
          type: type.name,
          entityType: 'account',
          entityId: Value(entityId),
          actorAccountId: Value(actorAccountId),
          occurredAt: DateTime.now().toUtc(),
          detailsJson: Value(jsonEncode(details)),
        ),
      );

  domain.Account _map(Account row) => domain.Account(
    id: row.id,
    displayName: row.displayName,
    role: AccountRole.values.byName(row.role),
    isActive: row.isActive,
    createdAt: row.createdAt,
    updatedAt: row.updatedAt,
    revision: row.revision,
  );
}
