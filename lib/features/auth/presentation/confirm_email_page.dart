import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import '../providers/auth_provider.dart';

class ConfirmEmailPage extends ConsumerWidget {
  const ConfirmEmailPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final email = authState.pendingEmail ?? authState.user?.email ?? '';

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(
                  MdiIcons.emailOutline,
                  size: 64,
                  color: Colors.white70,
                ),
                const SizedBox(height: 24),
                const Text(
                  'Check your email',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  'We sent a confirmation link to:',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[400],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  email,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () {
                      ref.read(authProvider.notifier).goToLoginWithCredentials();
                    },
                    child: const Text('I confirmed my email'),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () {
                    ref.read(authProvider.notifier).signOut();
                  },
                  child: const Text('Use different email'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
