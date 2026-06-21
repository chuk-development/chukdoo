import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../providers/auth_provider.dart';

class UnlockPage extends ConsumerStatefulWidget {
  const UnlockPage({super.key});

  @override
  ConsumerState<UnlockPage> createState() => _UnlockPageState();
}

class _UnlockPageState extends ConsumerState<UnlockPage> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleUnlock() async {
    if (!_formKey.currentState!.validate()) return;

    await ref.read(authProvider.notifier).unlockWithPassword(
          _passwordController.text,
        );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Unlock',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),

                  // Password
                  TextFormField(
                    controller: _passwordController,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? MdiIcons.eyeOffOutline
                              : MdiIcons.eyeOutline,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                    ),
                    obscureText: _obscurePassword,
                    autofocus: true,
                    textInputAction: TextInputAction.done,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Enter your password';
                      }
                      return null;
                    },
                    onFieldSubmitted: (_) => _handleUnlock(),
                  ),

                  // Error message
                  if (authState.error != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      authState.error!,
                      style: const TextStyle(
                        color: AppColors.error,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],

                  const SizedBox(height: 24),

                  // Unlock button
                  SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: authState.isLoading ? null : _handleUnlock,
                      child: authState.isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Unlock'),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Recovery option
                  TextButton(
                    onPressed: () {
                      Navigator.pushNamed(context, '/recovery');
                    },
                    child: const Text('Forgot password?'),
                  ),

                  const SizedBox(height: 8),

                  // Sign out option
                  TextButton(
                    onPressed: () {
                      ref.read(authProvider.notifier).signOut();
                    },
                    child: const Text('Use a different account'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
