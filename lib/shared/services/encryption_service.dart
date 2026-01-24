import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/app_constants.dart';
import '../../features/auth/services/backup_code_service.dart';
import 'supabase_service.dart';

/// Parameters for background encryption
class _EncryptionParams {
  final Uint8List bytes;
  final List<int> keyBytes;
  final String payloadVersion;

  _EncryptionParams({
    required this.bytes,
    required this.keyBytes,
    required this.payloadVersion,
  });
}

/// Parameters for background decryption
class _DecryptionParams {
  final String encrypted;
  final List<int> keyBytes;
  final String payloadVersion;

  _DecryptionParams({
    required this.encrypted,
    required this.keyBytes,
    required this.payloadVersion,
  });
}

/// Top-level function for background encryption
Future<String> _encryptBytesInBackground(_EncryptionParams params) async {
  final cipher = AesGcm.with256bits();
  final secretKey = SecretKey(params.keyBytes);
  final rng = Random.secure();

  final nonce = List<int>.generate(12, (_) => rng.nextInt(256));
  final secretBox = await cipher.encrypt(
    params.bytes,
    secretKey: secretKey,
    nonce: nonce,
  );

  final payload = <String, String>{
    'v': params.payloadVersion,
    'nonce': base64Encode(secretBox.nonce),
    'ciphertext': base64Encode(secretBox.cipherText),
    'mac': base64Encode(secretBox.mac.bytes),
  };

  return jsonEncode(payload);
}

/// Top-level function for background decryption
Future<Uint8List> _decryptBytesInBackground(_DecryptionParams params) async {
  final cipher = AesGcm.with256bits();
  final secretKey = SecretKey(params.keyBytes);

  final Map<String, dynamic> payload = jsonDecode(params.encrypted);
  final version = payload['v'];
  if (version != params.payloadVersion) {
    throw StateError('Unsupported ciphertext version: $version');
  }

  final nonce = base64Decode(payload['nonce'] as String);
  final cipherText = base64Decode(payload['ciphertext'] as String);
  final mac = Mac(base64Decode(payload['mac'] as String));
  final secretBox = SecretBox(cipherText, nonce: nonce, mac: mac);

  final cleartextBytes = await cipher.decrypt(
    secretBox,
    secretKey: secretKey,
  );

  return Uint8List.fromList(cleartextBytes);
}

/// Top-level function for background string decryption
Future<String> _decryptStringInBackground(_DecryptionParams params) async {
  final cipher = AesGcm.with256bits();
  final secretKey = SecretKey(params.keyBytes);

  final Map<String, dynamic> payload = jsonDecode(params.encrypted);
  final version = payload['v'];
  if (version != params.payloadVersion) {
    throw StateError('Unsupported ciphertext version: $version');
  }

  final nonce = base64Decode(payload['nonce'] as String);
  final cipherText = base64Decode(payload['ciphertext'] as String);
  final mac = Mac(base64Decode(payload['mac'] as String));
  final secretBox = SecretBox(cipherText, nonce: nonce, mac: mac);

  final cleartextBytes = await cipher.decrypt(
    secretBox,
    secretKey: secretKey,
  );

  return utf8.decode(cleartextBytes);
}

/// E2EE Encryption Service using PBKDF2 + AES-256-GCM
/// Adapted from chuk_chat's encryption implementation
class EncryptionService {
  const EncryptionService._();

  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  static final AesGcm _cipher = AesGcm.with256bits();
  static final Random _rng = Random.secure();

  static SecretKey? _cachedKey;
  static String? _cachedUserId;
  static Future<void> _lock = Future<void>.value();

  static bool get hasKey => _cachedKey != null;

  /// Initialize encryption with user password after login
  static Future<void> initializeForPassword(String password) async {
    await _runExclusive(() async {
      User user = await _requireAuthenticatedUser();
      final userId = user.id;
      final saltKey = '${AppConstants.keyEncryptionSalt}$userId';
      final keyKey = '${AppConstants.keyEncryptionKey}$userId';
      final versionKey = '${AppConstants.keyKeyVersion}$userId';
      final storedSaltBase64 = await _storage.read(key: saltKey);
      final storedKeyBase64 = await _storage.read(key: keyKey);

      if (storedKeyBase64 != null && storedSaltBase64 == null) {
        throw StateError(
          'Stored encryption key is missing its salt; please sign in again.',
        );
      }

      final metadataUpdates = <String, dynamic>{};
      final remoteSaltBase64 =
          user.userMetadata?[AppConstants.metadataSaltKey] as String?;
      final remoteVersion =
          user.userMetadata?[AppConstants.metadataVersionKey] as String?;

      final canonicalSaltBase64 = await _resolveCanonicalSalt(
        userId: userId,
        password: password,
        storedSaltBase64: storedSaltBase64,
        remoteSaltBase64: remoteSaltBase64,
        storedKeyBase64: storedKeyBase64,
        metadataUpdates: metadataUpdates,
      );

      if (remoteVersion != AppConstants.payloadVersion) {
        metadataUpdates[AppConstants.metadataVersionKey] =
            AppConstants.payloadVersion;
      }

      if (metadataUpdates.isNotEmpty) {
        final updatedUser = await _updateUserMetadata(user, metadataUpdates);
        if (updatedUser != null) {
          user = updatedUser;
        }
      }

      final saltBytes = _decodeBase64OrThrow(
        canonicalSaltBase64,
        'Stored encryption salt is corrupted; please sign in again.',
      );

      final derivedKeyBytes = await _deriveKey(password, saltBytes);
      if (storedKeyBase64 != null) {
        final storedKeyBytes = _decodeBase64OrThrow(
          storedKeyBase64,
          'Stored encryption key is corrupted; please sign in again.',
        );
        if (!_constantTimeEquals(derivedKeyBytes, storedKeyBytes)) {
          throw StateError('Incorrect password provided.');
        }
      } else {
        await _storage.write(key: keyKey, value: base64Encode(derivedKeyBytes));
      }

      await _storage.write(key: versionKey, value: AppConstants.payloadVersion);
      _cachedKey = SecretKey(derivedKeyBytes);
      _cachedUserId = user.id;
    });
  }

  /// Initialize encryption for new user with Master Key architecture
  /// Returns backup codes that must be shown to user
  static Future<BackupCodesResult> initializeForNewUser({
    required String userId,
    required String password,
  }) async {
    return _runExclusive(() async {
      // 1. Generate salt
      final saltBytes = _randomNonce(AppConstants.saltLength);
      final saltBase64 = base64Encode(saltBytes);

      // 2. Setup Master Key + backup codes in database
      final result = await BackupCodeService.setupEncryption(
        userId: userId,
        password: password,
        salt: saltBytes,
      );

      if (!result.success) {
        return result;
      }

      // 3. Get and cache the Master Key
      final masterKey = await BackupCodeService.getMasterKeyWithPassword(
        userId,
        password,
        saltBytes,
      );

      if (masterKey == null) {
        return const BackupCodesResult(
          codes: [],
          success: false,
          error: 'Failed to retrieve Master Key after setup.',
        );
      }

      // 4. Store salt and key locally
      final saltKey = '${AppConstants.keyEncryptionSalt}$userId';
      final keyKey = '${AppConstants.keyEncryptionKey}$userId';
      final versionKey = '${AppConstants.keyKeyVersion}$userId';

      await _storage.write(key: saltKey, value: saltBase64);
      await _storage.write(key: keyKey, value: base64Encode(masterKey));
      await _storage.write(key: versionKey, value: AppConstants.payloadVersion);

      // 5. Update user metadata with salt
      final user = SupabaseService.auth.currentUser;
      if (user != null) {
        await _updateUserMetadata(user, {
          AppConstants.metadataSaltKey: saltBase64,
          AppConstants.metadataVersionKey: AppConstants.payloadVersion,
        });
      }

      // 6. Cache key for immediate use
      _cachedKey = SecretKey(masterKey);
      _cachedUserId = userId;

      return result;
    });
  }

  /// Initialize encryption after recovery with backup code
  /// The password has already been updated in the database
  static Future<void> initializeAfterRecovery({
    required String userId,
    required String newPassword,
  }) async {
    await _runExclusive(() async {
      // 1. Get salt
      final saltKey = '${AppConstants.keyEncryptionSalt}$userId';
      final saltBase64 = await _storage.read(key: saltKey);

      if (saltBase64 == null) {
        // Try to get from user metadata
        final user = await _requireAuthenticatedUser();
        final remoteSalt = user.userMetadata?[AppConstants.metadataSaltKey] as String?;
        if (remoteSalt == null) {
          throw StateError('No salt found for recovery.');
        }
        await _storage.write(key: saltKey, value: remoteSalt);
      }

      final salt = base64Decode(saltBase64 ?? (await _storage.read(key: saltKey))!);

      // 2. Get Master Key with new password (already re-wrapped in recovery)
      final masterKey = await BackupCodeService.getMasterKeyWithPassword(
        userId,
        newPassword,
        salt,
      );

      if (masterKey == null) {
        throw StateError('Failed to retrieve Master Key after recovery.');
      }

      // 3. Store locally
      final keyKey = '${AppConstants.keyEncryptionKey}$userId';
      final versionKey = '${AppConstants.keyKeyVersion}$userId';

      await _storage.write(key: keyKey, value: base64Encode(masterKey));
      await _storage.write(key: versionKey, value: AppConstants.payloadVersion);

      // 4. Cache for use
      _cachedKey = SecretKey(masterKey);
      _cachedUserId = userId;
    });
  }

  /// Get salt bytes for a user (for use with BackupCodeService)
  static Future<List<int>?> getSaltBytes(String userId) async {
    final saltKey = '${AppConstants.keyEncryptionSalt}$userId';
    final saltBase64 = await _storage.read(key: saltKey);

    if (saltBase64 != null) {
      return base64Decode(saltBase64);
    }

    // Try to get from user metadata
    try {
      final user = SupabaseService.auth.currentUser;
      if (user != null) {
        final remoteSalt = user.userMetadata?[AppConstants.metadataSaltKey] as String?;
        if (remoteSalt != null) {
          await _storage.write(key: saltKey, value: remoteSalt);
          return base64Decode(remoteSalt);
        }
      }
    } catch (e) {
      debugPrint('EncryptionService: getSaltBytes error: $e');
    }

    return null;
  }

  /// Check if user has Master Key architecture setup
  static Future<bool> hasMasterKeySetup(String userId) async {
    return BackupCodeService.hasMasterKeySetup(userId);
  }

  /// Try to load existing key from secure storage (LOCAL ONLY - instant, no network)
  /// Use this for app startup to ensure instant opening
  static Future<bool> tryLoadKeyLocal(String? userId) async {
    if (userId == null) {
      _cachedKey = null;
      _cachedUserId = null;
      return false;
    }

    final keyKey = '${AppConstants.keyEncryptionKey}$userId';
    final encoded = await _storage.read(key: keyKey);

    if (encoded == null) {
      _cachedKey = null;
      _cachedUserId = null;
      return false;
    }

    try {
      _cachedKey = SecretKey(
        _decodeBase64OrThrow(
          encoded,
          'Stored encryption key is corrupted; please sign in again.',
        ),
      );
      _cachedUserId = userId;
      return true;
    } catch (e) {
      _cachedKey = null;
      _cachedUserId = null;
      return false;
    }
  }

  /// Sync encryption metadata with server (BACKGROUND - can be slow)
  /// Call this after app is already open to sync salt/version with server
  static Future<void> syncKeyMetadata() async {
    if (!SupabaseService.isAvailable) return;
    if (_cachedUserId == null) return;

    try {
      final currentUser = SupabaseService.auth.currentUser;
      if (currentUser == null) return;

      User user = currentUser;
      try {
        final response = await SupabaseService.auth.getUser().timeout(
          const Duration(seconds: 5),
        );
        user = response.user ?? user;
      } on TimeoutException {
        return; // Offline, skip sync
      } catch (_) {
        return; // Error, skip sync
      }

      final userId = user.id;
      final saltKey = '${AppConstants.keyEncryptionSalt}$userId';
      final versionKey = '${AppConstants.keyKeyVersion}$userId';

      final saltBase64 = await _storage.read(key: saltKey);
      final remoteSaltBase64 =
          user.userMetadata?[AppConstants.metadataSaltKey] as String?;
      final remoteVersion =
          user.userMetadata?[AppConstants.metadataVersionKey] as String?;

      final metadataUpdates = <String, dynamic>{};

      // Sync salt
      if (saltBase64 != null) {
        if (remoteSaltBase64 == null || remoteSaltBase64 != saltBase64) {
          metadataUpdates[AppConstants.metadataSaltKey] = saltBase64;
        }
      } else if (remoteSaltBase64 != null) {
        await _storage.write(key: saltKey, value: remoteSaltBase64);
      }

      // Sync version
      if (remoteVersion != AppConstants.payloadVersion) {
        metadataUpdates[AppConstants.metadataVersionKey] =
            AppConstants.payloadVersion;
      }

      final version = await _storage.read(key: versionKey);
      if (version == null) {
        await _storage.write(key: versionKey, value: AppConstants.payloadVersion);
      }

      // Upload metadata if needed
      if (metadataUpdates.isNotEmpty) {
        await _updateUserMetadata(user, metadataUpdates).timeout(
          const Duration(seconds: 5),
        );
      }

      debugPrint('EncryptionService: Metadata synced successfully');
    } catch (e) {
      debugPrint('EncryptionService: Metadata sync failed (will retry later): $e');
    }
  }

  /// Try to load existing key from secure storage (FULL - with network sync)
  /// Use tryLoadKeyLocal() for instant startup, then call syncKeyMetadata() in background
  static Future<bool> tryLoadKey() {
    return _runExclusive(() async {
      final currentUser = SupabaseService.auth.currentUser;
      if (currentUser == null) {
        _cachedKey = null;
        _cachedUserId = null;
        return false;
      }
      User user = currentUser;
      try {
        // Timeout to prevent hanging when offline
        final response = await SupabaseService.auth.getUser().timeout(
          const Duration(seconds: 3),
        );
        user = response.user ?? user;
      } on TimeoutException {
        // Use cached user when offline
      } catch (_) {
        // Ignore refresh failures - use cached user
      }

      final userId = user.id;
      final keyKey = '${AppConstants.keyEncryptionKey}$userId';
      final saltKey = '${AppConstants.keyEncryptionSalt}$userId';
      final versionKey = '${AppConstants.keyKeyVersion}$userId';

      final encoded = await _storage.read(key: keyKey);
      if (encoded == null) {
        _cachedKey = null;
        _cachedUserId = null;
        return false;
      }

      final saltBase64 = await _storage.read(key: saltKey);
      final remoteSaltBase64 =
          user.userMetadata?[AppConstants.metadataSaltKey] as String?;
      final remoteVersion =
          user.userMetadata?[AppConstants.metadataVersionKey] as String?;

      final metadataUpdates = <String, dynamic>{};

      if (saltBase64 != null) {
        if (remoteSaltBase64 == null || remoteSaltBase64 != saltBase64) {
          metadataUpdates[AppConstants.metadataSaltKey] = saltBase64;
        }
      } else if (remoteSaltBase64 != null) {
        await _storage.write(key: saltKey, value: remoteSaltBase64);
      }

      if (remoteVersion != AppConstants.payloadVersion) {
        metadataUpdates[AppConstants.metadataVersionKey] =
            AppConstants.payloadVersion;
      }

      if (metadataUpdates.isNotEmpty) {
        try {
          // Timeout to prevent hanging when offline
          final updated = await _updateUserMetadata(user, metadataUpdates).timeout(
            const Duration(seconds: 3),
            onTimeout: () => null,
          );
          if (updated != null) {
            user = updated;
          }
        } catch (_) {
          // Ignore metadata sync failures - will sync next time online
        }
      }

      final version = await _storage.read(key: versionKey);
      if (version == null) {
        await _storage.write(key: versionKey, value: AppConstants.payloadVersion);
      }

      _cachedKey = SecretKey(
        _decodeBase64OrThrow(
          encoded,
          'Stored encryption key is corrupted; please sign in again.',
        ),
      );
      _cachedUserId = user.id;
      return true;
    });
  }

  /// Clear encryption key on logout
  static Future<void> clearKey() {
    return _runExclusive(() async {
      final userId = SupabaseService.auth.currentUser?.id ?? _cachedUserId;
      if (userId != null) {
        await _storage.delete(key: '${AppConstants.keyEncryptionKey}$userId');
        await _storage.delete(key: '${AppConstants.keyEncryptionSalt}$userId');
        await _storage.delete(key: '${AppConstants.keyKeyVersion}$userId');
      }
      _cachedKey = null;
      _cachedUserId = null;
    });
  }

  /// Encrypt a string
  static Future<String> encrypt(String plaintext) async {
    final secretKey = await _ensureKey();
    final nonce = _randomNonce(12);
    final secretBox = await _cipher.encrypt(
      utf8.encode(plaintext),
      secretKey: secretKey,
      nonce: nonce,
    );
    final payload = <String, String>{
      'v': AppConstants.payloadVersion,
      'nonce': base64Encode(secretBox.nonce),
      'ciphertext': base64Encode(secretBox.cipherText),
      'mac': base64Encode(secretBox.mac.bytes),
    };
    return jsonEncode(payload);
  }

  /// Decrypt a string
  static Future<String> decrypt(String encrypted) async {
    final secretKey = await _ensureKey();
    final Map<String, dynamic> payload = jsonDecode(encrypted);
    final version = payload['v'];
    if (version != AppConstants.payloadVersion) {
      throw StateError('Unsupported ciphertext version: $version');
    }
    final nonce = base64Decode(payload['nonce'] as String);
    final cipherText = base64Decode(payload['ciphertext'] as String);
    final mac = Mac(base64Decode(payload['mac'] as String));
    final secretBox = SecretBox(cipherText, nonce: nonce, mac: mac);
    final cleartextBytes = await _cipher.decrypt(
      secretBox,
      secretKey: secretKey,
    );
    return utf8.decode(cleartextBytes);
  }

  /// Encrypt binary data in background isolate
  static Future<String> encryptBytes(Uint8List bytes) async {
    final secretKey = await _ensureKey();
    final keyBytes = await secretKey.extractBytes();

    final params = _EncryptionParams(
      bytes: bytes,
      keyBytes: keyBytes,
      payloadVersion: AppConstants.payloadVersion,
    );

    return await compute(_encryptBytesInBackground, params);
  }

  /// Decrypt binary data in background isolate
  static Future<Uint8List> decryptBytes(String encrypted) async {
    final secretKey = await _ensureKey();
    final keyBytes = await secretKey.extractBytes();

    final params = _DecryptionParams(
      encrypted: encrypted,
      keyBytes: keyBytes,
      payloadVersion: AppConstants.payloadVersion,
    );

    return await compute(_decryptBytesInBackground, params);
  }

  /// Decrypt string in background isolate
  static Future<String> decryptInBackground(String encrypted) async {
    final secretKey = await _ensureKey();
    final keyBytes = await secretKey.extractBytes();

    final params = _DecryptionParams(
      encrypted: encrypted,
      keyBytes: keyBytes,
      payloadVersion: AppConstants.payloadVersion,
    );

    return await compute(_decryptStringInBackground, params);
  }

  /// Encrypt a JSON-serializable map
  static Future<String> encryptJson(Map<String, dynamic> data) async {
    final jsonString = jsonEncode(data);
    return encrypt(jsonString);
  }

  /// Decrypt a JSON string to a map
  static Future<Map<String, dynamic>> decryptJson(String encrypted) async {
    final decrypted = await decrypt(encrypted);
    return jsonDecode(decrypted) as Map<String, dynamic>;
  }

  // Private helpers

  static Future<SecretKey> _ensureKey() async {
    final user = SupabaseService.auth.currentUser;
    if (user == null) {
      _cachedKey = null;
      _cachedUserId = null;
      throw StateError('Cannot use encryption without an authenticated user.');
    }

    if (_cachedKey != null) {
      if (_cachedUserId == user.id) {
        return _cachedKey!;
      }
      _cachedKey = null;
      _cachedUserId = null;
      throw StateError('Encryption key does not match active user.');
    }

    final loaded = await tryLoadKey();
    if (!loaded || _cachedUserId != user.id) {
      throw StateError('Encryption key is not available for the current user.');
    }
    return _cachedKey!;
  }

  static Future<List<int>> _deriveKey(String password, List<int> salt) async {
    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: AppConstants.kdfIterations,
      bits: 256,
    );
    final newSecretKey = await pbkdf2.deriveKeyFromPassword(
      password: password,
      nonce: salt,
    );
    return newSecretKey.extractBytes();
  }

  static List<int> _randomNonce(int length) {
    return List<int>.generate(length, (_) => _rng.nextInt(256));
  }

  static Future<T> _runExclusive<T>(Future<T> Function() action) {
    final completer = Completer<T>();
    _lock = _lock.then((_) => action()).then<void>(
      (result) {
        completer.complete(result);
      },
      onError: (Object error, StackTrace stackTrace) {
        completer.completeError(error, stackTrace);
      },
    );
    return completer.future;
  }

  static bool _constantTimeEquals(List<int> a, List<int> b) {
    if (a.length != b.length) {
      return false;
    }
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }

  static Future<User> _requireAuthenticatedUser() async {
    final currentUser = SupabaseService.auth.currentUser;
    if (currentUser == null) {
      throw StateError(
        'Cannot initialise encryption without an authenticated user.',
      );
    }
    User user = currentUser;
    try {
      // Timeout to prevent hanging when offline
      final response = await SupabaseService.auth.getUser().timeout(
        const Duration(seconds: 3),
      );
      user = response.user ?? user;
    } on TimeoutException {
      // Use cached user when offline
    } catch (_) {
      // Fallback to cached user data
    }
    return user;
  }

  static Future<String> _resolveCanonicalSalt({
    required String userId,
    required String password,
    required String? storedSaltBase64,
    required String? remoteSaltBase64,
    required String? storedKeyBase64,
    required Map<String, dynamic> metadataUpdates,
  }) async {
    final saltKey = '${AppConstants.keyEncryptionSalt}$userId';

    if (storedSaltBase64 != null && remoteSaltBase64 != null) {
      if (remoteSaltBase64 == storedSaltBase64) {
        return storedSaltBase64;
      }

      if (storedKeyBase64 != null) {
        final storedKeyBytes = _decodeBase64OrThrow(
          storedKeyBase64,
          'Stored encryption key is corrupted; please sign out and sign in again.',
        );

        final remoteSaltBytes = _decodeBase64OrThrow(
          remoteSaltBase64,
          'Remote encryption salt is corrupted. Sign out on other devices and retry.',
        );
        final derivedWithRemote = await _deriveKey(password, remoteSaltBytes);
        if (_constantTimeEquals(derivedWithRemote, storedKeyBytes)) {
          await _storage.write(key: saltKey, value: remoteSaltBase64);
          metadataUpdates[AppConstants.metadataSaltKey] = remoteSaltBase64;
          return remoteSaltBase64;
        }

        final storedSaltBytes = _decodeBase64OrThrow(
          storedSaltBase64,
          'Stored encryption salt is corrupted; please sign out and sign in again.',
        );
        final derivedWithStored = await _deriveKey(password, storedSaltBytes);
        if (_constantTimeEquals(derivedWithStored, storedKeyBytes)) {
          metadataUpdates[AppConstants.metadataSaltKey] = storedSaltBase64;
          return storedSaltBase64;
        }

        throw StateError(
          'Encryption data mismatch detected. Sign out everywhere, then sign back in.',
        );
      }

      await _storage.write(key: saltKey, value: remoteSaltBase64);
      metadataUpdates[AppConstants.metadataSaltKey] = remoteSaltBase64;
      return remoteSaltBase64;
    }

    if (remoteSaltBase64 != null) {
      await _storage.write(key: saltKey, value: remoteSaltBase64);
      return remoteSaltBase64;
    }

    if (storedSaltBase64 != null) {
      metadataUpdates[AppConstants.metadataSaltKey] = storedSaltBase64;
      return storedSaltBase64;
    }

    final generatedSalt =
        base64Encode(_randomNonce(AppConstants.saltLength));
    await _storage.write(key: saltKey, value: generatedSalt);
    metadataUpdates[AppConstants.metadataSaltKey] = generatedSalt;
    return generatedSalt;
  }

  static List<int> _decodeBase64OrThrow(String data, String errorMessage) {
    try {
      return base64Decode(data);
    } on FormatException {
      throw StateError(errorMessage);
    }
  }

  static Future<User?> _updateUserMetadata(
    User user,
    Map<String, dynamic> patch,
  ) async {
    if (patch.isEmpty) return null;
    final existing = Map<String, dynamic>.from(user.userMetadata ?? {});
    var hasChanges = false;
    for (final entry in patch.entries) {
      if (existing[entry.key] != entry.value) {
        hasChanges = true;
        existing[entry.key] = entry.value;
      }
    }
    if (!hasChanges) return null;

    try {
      final response = await SupabaseService.auth.updateUser(
        UserAttributes(data: existing),
      );
      return response.user;
    } on AuthException catch (error) {
      throw StateError('Failed to sync encryption metadata: ${error.message}');
    }
  }
}
