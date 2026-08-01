import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

class PinPolicyException implements Exception {
  const PinPolicyException(this.message);
  final String message;

  @override
  String toString() => 'PinPolicyException: $message';
}

class PinDigest {
  const PinDigest({required this.hash, required this.salt});
  final String hash;
  final String salt;
}

/// Versioned Argon2id PIN hashing with a fresh per-account salt.
class PinHasher {
  PinHasher({Random? random}) : _random = random ?? Random.secure();

  static const int _memoryKiB = 19 * 1024;
  static const int _iterations = 2;
  static const int _parallelism = 1;
  static const int _hashLength = 32;
  static const int _saltLength = 16;
  static const String _version = 'argon2id-v1';

  final Random _random;

  void validate(String pin) {
    if (!RegExp(r'^\d{4,8}$').hasMatch(pin)) {
      throw const PinPolicyException('PIN must contain 4 to 8 digits.');
    }
  }

  Future<PinDigest> hash(String pin) async {
    validate(pin);
    final salt = Uint8List.fromList(
      List<int>.generate(_saltLength, (_) => _random.nextInt(256)),
    );
    final bytes = await _derive(pin, salt);
    return PinDigest(
      hash:
          '$_version\$$_memoryKiB\$$_iterations\$$_parallelism\$${base64UrlEncode(bytes)}',
      salt: base64UrlEncode(salt),
    );
  }

  Future<bool> verify(
    String pin, {
    required String hash,
    required String salt,
  }) async {
    if (!RegExp(r'^\d{4,8}$').hasMatch(pin)) return false;
    final parts = hash.split(r'$');
    if (parts.length != 5 || parts.first != _version) return false;
    try {
      final algorithm = Argon2id(
        memory: int.parse(parts[1]),
        iterations: int.parse(parts[2]),
        parallelism: int.parse(parts[3]),
        hashLength: base64Url.decode(parts[4]).length,
      );
      final key = await algorithm.deriveKeyFromPassword(
        password: pin,
        nonce: base64Url.decode(salt),
      );
      final actual = await key.extractBytes();
      return _constantTimeEquals(actual, base64Url.decode(parts[4]));
    } on FormatException {
      return false;
    } on ArgumentError {
      return false;
    }
  }

  Future<List<int>> _derive(String pin, List<int> salt) async {
    final algorithm = Argon2id(
      memory: _memoryKiB,
      iterations: _iterations,
      parallelism: _parallelism,
      hashLength: _hashLength,
    );
    final key = await algorithm.deriveKeyFromPassword(
      password: pin,
      nonce: salt,
    );
    return key.extractBytes();
  }

  bool _constantTimeEquals(List<int> first, List<int> second) {
    if (first.length != second.length) return false;
    var difference = 0;
    for (var index = 0; index < first.length; index++) {
      difference |= first[index] ^ second[index];
    }
    return difference == 0;
  }
}
