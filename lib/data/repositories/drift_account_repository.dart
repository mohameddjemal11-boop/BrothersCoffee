import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../domain/entities/account.dart' as domain;
import '../../domain/entities/enums.dart';
import '../../domain/repositories/account_repository.dart';
import '../database/app_database.dart';
import '../security/pin_hasher.dart';

class DriftAccountRepository implements AccountRepository {
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
      return _insert(name: name, role: AccountRole.manager, pin: pin);
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
  Future<domain.Account> create({
    required String displayName,
    required AccountRole role,
    required String pin,
  }) async {
    if (role == AccountRole.manager && await _hasManager()) {
      throw StateError('Only one manager account is supported.');
    }
    return _insert(name: _validName(displayName), role: role, pin: pin);
  }

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

  @override
  Future<domain.Account> update({
    required String id,
    String? displayName,
    AccountRole? role,
    String? pin,
  }) async {
    return _database.transaction(() async {
      final current = await _findRow(id);
      if (current.role == AccountRole.manager.name &&
          role == AccountRole.employee &&
          await _isLastActiveManager(id)) {
        throw StateError('The last active manager cannot become an employee.');
      }
      if (current.role != AccountRole.manager.name &&
          role == AccountRole.manager &&
          await _hasManager()) {
        throw StateError('Only one manager account is supported.');
      }
      PinDigest? digest;
      if (pin != null) digest = await _pinHasher.hash(pin);
      await (_database.update(
        _database.accounts,
      )..where((row) => row.id.equals(id))).write(
        AccountsCompanion(
          displayName: displayName == null
              ? const Value.absent()
              : Value(_validName(displayName)),
          role: role == null ? const Value.absent() : Value(role.name),
          pinHash: digest == null ? const Value.absent() : Value(digest.hash),
          pinSalt: digest == null ? const Value.absent() : Value(digest.salt),
          updatedAt: Value(DateTime.now().toUtc()),
          revision: Value(current.revision + 1),
        ),
      );
      return _find(id);
    });
  }

  @override
  Future<void> archive(String id) async {
    await _database.transaction(() async {
      final current = await _findRow(id);
      if (current.role == AccountRole.manager.name &&
          await _isLastActiveManager(id)) {
        throw StateError('The last active manager cannot be archived.');
      }
      final now = DateTime.now().toUtc();
      await (_database.update(
        _database.accounts,
      )..where((row) => row.id.equals(id))).write(
        AccountsCompanion(
          isActive: const Value(false),
          archivedAt: Value(now),
          updatedAt: Value(now),
          revision: Value(current.revision + 1),
        ),
      );
    });
  }

  Future<bool> _isLastActiveManager(String id) async {
    final managers =
        await (_database.select(_database.accounts)..where(
              (row) =>
                  row.isActive.equals(true) &
                  row.role.equals(AccountRole.manager.name),
            ))
            .get();
    return managers.length == 1 && managers.single.id == id;
  }

  Future<bool> _hasManager() async {
    final manager =
        await (_database.select(_database.accounts)
              ..where((row) => row.role.equals(AccountRole.manager.name))
              ..limit(1))
            .getSingleOrNull();
    return manager != null;
  }

  Future<Account> _findRow(String id) async => (_database.select(
    _database.accounts,
  )..where((row) => row.id.equals(id))).getSingle();

  Future<domain.Account> _find(String id) async => _map(await _findRow(id));

  String _validName(String name) {
    final value = name.trim();
    if (value.isEmpty) {
      throw ArgumentError.value(name, 'displayName', 'Must not be empty.');
    }
    return value;
  }

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
