import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/services/supabase_service.dart';
import '../services/backup_code_service.dart';

/// Provider for the count of available (unused) backup codes
final availableBackupCodesProvider = FutureProvider<int>((ref) async {
  final user = SupabaseService.currentUser;
  if (user == null) return 0;

  return BackupCodeService.getAvailableCodesCount(user.id);
});

/// Provider to check if user has Master Key setup
final hasMasterKeySetupProvider = FutureProvider<bool>((ref) async {
  final user = SupabaseService.currentUser;
  if (user == null) return false;

  return BackupCodeService.hasMasterKeySetup(user.id);
});
