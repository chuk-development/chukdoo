import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:chukdoo/features/auth/services/backup_code_service.dart';

/// These tests lock in the cryptographic invariant that the cross-device
/// sign-in fix relies on: a Master Key wrapped with a password-derived key on
/// one device can be unwrapped on another device using only the same password
/// and the same (server-stored) salt. They use the pure crypto helpers and do
/// not touch Supabase.
void main() {
  List<int> randomSalt() =>
      List<int>.generate(16, (_) => Random.secure().nextInt(256));

  test('master key round-trips across "devices" with same password + salt',
      () async {
    final masterKey = BackupCodeService.generateMasterKey();
    final salt = randomSalt();
    const password = 'correct horse battery staple';

    // Device A: wrap the master key with the password-derived key.
    final keyA = await BackupCodeService.deriveKeyFromPassword(password, salt);
    final wrapped = await BackupCodeService.wrapMasterKey(masterKey, keyA);

    // Device B: derive the key again from the same password + salt and unwrap.
    final keyB = await BackupCodeService.deriveKeyFromPassword(password, salt);
    final unwrapped =
        await BackupCodeService.unwrapMasterKey(wrapped, keyB);

    expect(unwrapped, equals(masterKey));
  });

  test('wrong password cannot unwrap the master key', () async {
    final masterKey = BackupCodeService.generateMasterKey();
    final salt = randomSalt();

    final goodKey =
        await BackupCodeService.deriveKeyFromPassword('right-password', salt);
    final wrapped = await BackupCodeService.wrapMasterKey(masterKey, goodKey);

    final badKey =
        await BackupCodeService.deriveKeyFromPassword('wrong-password', salt);

    // AES-GCM authentication must reject the wrong key (MAC mismatch).
    await expectLater(
      BackupCodeService.unwrapMasterKey(wrapped, badKey),
      throwsA(isA<Object>()),
    );
  });

  test('a backup-code-derived key also unwraps the same master key', () async {
    final masterKey = BackupCodeService.generateMasterKey();
    final salt = randomSalt();
    final code = BackupCodeService.generateCode();

    final codeKey = await BackupCodeService.deriveKeyFromCode(
      BackupCodeService.normalizeCode(code),
      salt,
    );
    final wrapped = await BackupCodeService.wrapMasterKey(masterKey, codeKey);

    final codeKey2 = await BackupCodeService.deriveKeyFromCode(
      BackupCodeService.normalizeCode(code),
      salt,
    );
    final unwrapped = await BackupCodeService.unwrapMasterKey(wrapped, codeKey2);

    expect(unwrapped, equals(masterKey));
  });
}
