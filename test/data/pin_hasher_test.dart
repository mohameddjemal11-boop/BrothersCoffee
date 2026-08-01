import 'dart:math';

import 'package:brothers_coffee_pos/data/security/pin_hasher.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('hashes and verifies a valid PIN without retaining the PIN', () async {
    final hasher = PinHasher(random: Random(42));
    final digest = await hasher.hash('1234');

    expect(digest.hash, isNot(contains('1234')));
    expect(
      await hasher.verify('1234', hash: digest.hash, salt: digest.salt),
      isTrue,
    );
    expect(
      await hasher.verify('9999', hash: digest.hash, salt: digest.salt),
      isFalse,
    );
  });

  test('uses a per-account salt', () async {
    final hasher = PinHasher(random: Random(9));
    final first = await hasher.hash('1234');
    final second = await hasher.hash('1234');

    expect(first.salt, isNot(second.salt));
    expect(first.hash, isNot(second.hash));
  });

  test('enforces the numeric 4 to 8 digit PIN policy', () async {
    final hasher = PinHasher(random: Random(1));

    await expectLater(hasher.hash('123'), throwsA(isA<PinPolicyException>()));
    await expectLater(hasher.hash('12a4'), throwsA(isA<PinPolicyException>()));
    await expectLater(
      hasher.hash('123456789'),
      throwsA(isA<PinPolicyException>()),
    );
  });
}
