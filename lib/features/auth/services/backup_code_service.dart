import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';

import '../../../core/constants/app_constants.dart';
import '../../../shared/services/supabase_service.dart';

/// Result of backup code generation
class BackupCodesResult {
  final List<String> codes;
  final bool success;
  final String? error;

  const BackupCodesResult({
    required this.codes,
    required this.success,
    this.error,
  });
}

/// Result of recovery attempt
class RecoveryResult {
  final bool success;
  final String? error;
  final int remainingAttempts;

  const RecoveryResult({
    required this.success,
    this.error,
    this.remainingAttempts = 5,
  });
}

/// Service for managing backup codes and Master Key wrapping
class BackupCodeService {
  const BackupCodeService._();

  // Character set excluding 0/O/1/I to prevent confusion
  static const String _chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  static const int _codeLength = 12;

  /// Generate a single backup code in XXXX-XXXX-XXXX format
  static String generateCode() {
    final random = Random.secure();
    final chars = List.generate(
      _codeLength,
      (_) => _chars[random.nextInt(_chars.length)],
    );
    return '${chars.sublist(0, 4).join()}-${chars.sublist(4, 8).join()}-${chars.sublist(8, 12).join()}';
  }

  /// Normalize code (remove dashes, uppercase)
  static String normalizeCode(String code) {
    return code.replaceAll('-', '').toUpperCase().trim();
  }

  /// Hash a backup code using SHA-256
  static Future<String> computeCodeHash(String code) async {
    final sha256 = Sha256();
    final hash = await sha256.hash(utf8.encode(normalizeCode(code)));
    return base64Encode(hash.bytes);
  }

  /// Derive key from backup code using PBKDF2
  static Future<List<int>> deriveKeyFromCode(String code, List<int> salt) async {
    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: AppConstants.backupCodeKdfIterations,
      bits: 256,
    );
    final secretKey = await pbkdf2.deriveKeyFromPassword(
      password: normalizeCode(code),
      nonce: salt,
    );
    return secretKey.extractBytes();
  }

  /// Derive key from password using PBKDF2
  static Future<List<int>> deriveKeyFromPassword(
    String password,
    List<int> salt,
  ) async {
    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: AppConstants.kdfIterations,
      bits: 256,
    );
    final secretKey = await pbkdf2.deriveKeyFromPassword(
      password: password,
      nonce: salt,
    );
    return secretKey.extractBytes();
  }

  /// Generate Master Key (random 256 bits)
  static List<int> generateMasterKey() {
    final random = Random.secure();
    return List.generate(32, (_) => random.nextInt(256));
  }

  /// Wrap Master Key with a derived key using AES-GCM
  static Future<String> wrapMasterKey(
    List<int> masterKey,
    List<int> wrappingKey,
  ) async {
    final cipher = AesGcm.with256bits();
    final secretKey = SecretKey(wrappingKey);
    final random = Random.secure();
    final nonce = List.generate(12, (_) => random.nextInt(256));

    final secretBox = await cipher.encrypt(
      masterKey,
      secretKey: secretKey,
      nonce: nonce,
    );

    final payload = {
      'v': '1',
      'nonce': base64Encode(secretBox.nonce),
      'ciphertext': base64Encode(secretBox.cipherText),
      'mac': base64Encode(secretBox.mac.bytes),
    };
    return jsonEncode(payload);
  }

  /// Unwrap Master Key using a derived key
  static Future<List<int>> unwrapMasterKey(
    String wrapped,
    List<int> unwrappingKey,
  ) async {
    final cipher = AesGcm.with256bits();
    final secretKey = SecretKey(unwrappingKey);

    final payload = jsonDecode(wrapped) as Map<String, dynamic>;
    final nonce = base64Decode(payload['nonce'] as String);
    final cipherText = base64Decode(payload['ciphertext'] as String);
    final mac = Mac(base64Decode(payload['mac'] as String));

    final secretBox = SecretBox(cipherText, nonce: nonce, mac: mac);
    final decrypted = await cipher.decrypt(secretBox, secretKey: secretKey);
    return decrypted;
  }

  /// Setup encryption for new user (generates Master Key + backup codes)
  static Future<BackupCodesResult> setupEncryption({
    required String userId,
    required String password,
    required List<int> salt,
  }) async {
    try {
      // 1. Generate Master Key
      final masterKey = generateMasterKey();

      // 2. Derive password key and wrap Master Key
      final passwordKey = await deriveKeyFromPassword(password, salt);
      final wrappedWithPassword = await wrapMasterKey(masterKey, passwordKey);

      // 3. Store password-wrapped key
      await SupabaseService.client.from('user_keys').insert({
        'user_id': userId,
        'key_type': 'password',
        'wrapped_key': wrappedWithPassword,
      });

      // 4. Generate and store backup codes
      final codes = <String>[];
      for (var i = 0; i < AppConstants.backupCodeCount; i++) {
        final code = generateCode();
        codes.add(code);

        final codeKey = await deriveKeyFromCode(code, salt);
        final wrappedWithCode = await wrapMasterKey(masterKey, codeKey);
        final codeHash = await computeCodeHash(code);

        await SupabaseService.client.from('user_keys').insert({
          'user_id': userId,
          'key_type': 'backup_$i',
          'wrapped_key': wrappedWithCode,
          'code_hash': codeHash,
        });
      }

      return BackupCodesResult(codes: codes, success: true);
    } catch (e) {
      debugPrint('BackupCodeService: setupEncryption error: $e');
      return BackupCodesResult(codes: [], success: false, error: e.toString());
    }
  }

  /// Recover account with backup code
  static Future<RecoveryResult> recoverWithBackupCode({
    required String userId,
    required String code,
    required String newPassword,
    required List<int> salt,
  }) async {
    try {
      // 1. Check rate limit
      final canAttempt = await _checkRateLimit(userId);
      if (!canAttempt) {
        return const RecoveryResult(
          success: false,
          error: 'Too many attempts. Please wait 15 minutes.',
          remainingAttempts: 0,
        );
      }

      // 2. Find the backup code by hash
      final codeHash = await computeCodeHash(code);
      final result = await SupabaseService.client
          .from('user_keys')
          .select()
          .eq('user_id', userId)
          .eq('code_hash', codeHash)
          .isFilter('used_at', null)
          .maybeSingle();

      if (result == null) {
        await _logRecoveryAttempt(userId, false);
        return const RecoveryResult(
          success: false,
          error: 'Invalid or already used code.',
        );
      }

      // 3. Unwrap Master Key with backup code
      final codeKey = await deriveKeyFromCode(code, salt);
      final wrappedKey = result['wrapped_key'] as String;
      final masterKey = await unwrapMasterKey(wrappedKey, codeKey);

      // 4. Wrap Master Key with new password
      final newPasswordKey = await deriveKeyFromPassword(newPassword, salt);
      final newWrappedKey = await wrapMasterKey(masterKey, newPasswordKey);

      // 5. Update password-wrapped key
      await SupabaseService.client
          .from('user_keys')
          .update({'wrapped_key': newWrappedKey})
          .eq('user_id', userId)
          .eq('key_type', 'password');

      // 6. Mark backup code as used
      await SupabaseService.client
          .from('user_keys')
          .update({'used_at': DateTime.now().toIso8601String()})
          .eq('id', result['id']);

      // 7. Log successful attempt
      await _logRecoveryAttempt(userId, true);

      return const RecoveryResult(success: true);
    } catch (e) {
      debugPrint('BackupCodeService: recoverWithBackupCode error: $e');
      return RecoveryResult(success: false, error: e.toString());
    }
  }

  /// Regenerate backup codes (requires current password)
  static Future<BackupCodesResult> regenerateBackupCodes({
    required String userId,
    required String currentPassword,
    required List<int> salt,
  }) async {
    try {
      // 1. Get Master Key using current password
      final masterKey = await getMasterKeyWithPassword(
        userId,
        currentPassword,
        salt,
      );
      if (masterKey == null) {
        return const BackupCodesResult(
          codes: [],
          success: false,
          error: 'Wrong password.',
        );
      }

      // 2. Delete old backup codes
      await SupabaseService.client
          .from('user_keys')
          .delete()
          .eq('user_id', userId)
          .like('key_type', 'backup_%');

      // 3. Generate new backup codes
      final codes = <String>[];
      for (var i = 0; i < AppConstants.backupCodeCount; i++) {
        final code = generateCode();
        codes.add(code);

        final codeKey = await deriveKeyFromCode(code, salt);
        final wrappedWithCode = await wrapMasterKey(masterKey, codeKey);
        final codeHash = await computeCodeHash(code);

        await SupabaseService.client.from('user_keys').insert({
          'user_id': userId,
          'key_type': 'backup_$i',
          'wrapped_key': wrappedWithCode,
          'code_hash': codeHash,
        });
      }

      return BackupCodesResult(codes: codes, success: true);
    } catch (e) {
      debugPrint('BackupCodeService: regenerateBackupCodes error: $e');
      return BackupCodesResult(codes: [], success: false, error: e.toString());
    }
  }

  /// Get Master Key using password
  static Future<List<int>?> getMasterKeyWithPassword(
    String userId,
    String password,
    List<int> salt,
  ) async {
    try {
      final result = await SupabaseService.client
          .from('user_keys')
          .select('wrapped_key')
          .eq('user_id', userId)
          .eq('key_type', 'password')
          .maybeSingle();

      if (result == null) return null;

      final passwordKey = await deriveKeyFromPassword(password, salt);
      final wrappedKey = result['wrapped_key'] as String;
      return await unwrapMasterKey(wrappedKey, passwordKey);
    } catch (e) {
      debugPrint('BackupCodeService: getMasterKeyWithPassword error: $e');
      return null;
    }
  }

  /// Get count of available (unused) backup codes
  static Future<int> getAvailableCodesCount(String userId) async {
    try {
      final result = await SupabaseService.client
          .from('user_keys')
          .select('id')
          .eq('user_id', userId)
          .like('key_type', 'backup_%')
          .isFilter('used_at', null);

      return (result as List).length;
    } catch (e) {
      debugPrint('BackupCodeService: getAvailableCodesCount error: $e');
      return 0;
    }
  }

  /// Check if user has Master Key architecture (vs legacy)
  static Future<bool> hasMasterKeySetup(String userId) async {
    try {
      final result = await SupabaseService.client
          .from('user_keys')
          .select('id')
          .eq('user_id', userId)
          .eq('key_type', 'password')
          .maybeSingle();

      return result != null;
    } catch (e) {
      debugPrint('BackupCodeService: hasMasterKeySetup error: $e');
      return false;
    }
  }

  /// Update wrapped key when password is changed
  static Future<bool> updatePasswordWrappedKey({
    required String userId,
    required String oldPassword,
    required String newPassword,
    required List<int> salt,
  }) async {
    try {
      // 1. Get Master Key with old password
      final masterKey = await getMasterKeyWithPassword(userId, oldPassword, salt);
      if (masterKey == null) {
        return false;
      }

      // 2. Wrap with new password
      final newPasswordKey = await deriveKeyFromPassword(newPassword, salt);
      final newWrappedKey = await wrapMasterKey(masterKey, newPasswordKey);

      // 3. Update in database
      await SupabaseService.client
          .from('user_keys')
          .update({'wrapped_key': newWrappedKey})
          .eq('user_id', userId)
          .eq('key_type', 'password');

      return true;
    } catch (e) {
      debugPrint('BackupCodeService: updatePasswordWrappedKey error: $e');
      return false;
    }
  }

  // Private helpers

  static Future<bool> _checkRateLimit(String userId) async {
    try {
      final result = await SupabaseService.client
          .rpc('check_recovery_rate_limit', params: {'p_user_id': userId});
      return result as bool? ?? true;
    } catch (e) {
      debugPrint('BackupCodeService: _checkRateLimit error: $e');
      return true; // Allow on error
    }
  }

  static Future<void> _logRecoveryAttempt(String userId, bool success) async {
    try {
      await SupabaseService.client.from('recovery_attempts').insert({
        'user_id': userId,
        'success': success,
      });
    } catch (e) {
      debugPrint('BackupCodeService: _logRecoveryAttempt error: $e');
    }
  }
}
