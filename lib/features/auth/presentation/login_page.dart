import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_shapes.dart';
import '../providers/auth_provider.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _displayNameController = TextEditingController();

  final _passwordFocus = FocusNode();

  bool _isSignInMode = true;
  bool _obscurePassword = true;
  bool _didPrefill = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _displayNameController.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  void _prefillCredentials() {
    if (_didPrefill) return;
    final authState = ref.read(authProvider);
    if (authState.pendingEmail != null) {
      _emailController.text = authState.pendingEmail!;
    }
    if (authState.pendingPassword != null) {
      _passwordController.text = authState.pendingPassword!;
    }
    // Clear the pending credentials after prefilling
    if (authState.pendingEmail != null || authState.pendingPassword != null) {
      ref.read(authProvider.notifier).clearPendingCredentials();
    }
    _didPrefill = true;
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_isSignInMode) {
      await ref.read(authProvider.notifier).signIn(
            email: _emailController.text.trim(),
            password: _passwordController.text,
          );
      // A wrong password must not cost the typed email: keep the field and
      // put the cursor straight back into the password.
      if (mounted && ref.read(authProvider).error != null) {
        _passwordController.selection = TextSelection(
          baseOffset: 0,
          extentOffset: _passwordController.text.length,
        );
        _passwordFocus.requestFocus();
      }
    } else {
      await ref.read(authProvider.notifier).signUp(
            email: _emailController.text.trim(),
            password: _passwordController.text,
            displayName: _displayNameController.text.trim().isEmpty
                ? null
                : _displayNameController.text.trim(),
          );
    }
  }

  void _toggleMode() {
    setState(() {
      _isSignInMode = !_isSignInMode;
    });
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    // Pre-fill credentials if coming from email confirmation
    _prefillCredentials();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Brand mark
                    Center(
                      child: Container(
                        width: 72,
                        height: 72,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Icon(
                          MdiIcons.checkAll,
                          size: 38,
                          color: AppColors.onPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      _isSignInMode ? 'Welcome back' : 'Create account',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _isSignInMode
                          ? 'Sign in to sync your tasks across devices.'
                          : 'Everything is free — an account only adds sync.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Fields — one rounded group, like every list in the app.
                    if (!_isSignInMode) ...[
                      _field(
                        child: TextFormField(
                          controller: _displayNameController,
                          decoration: const InputDecoration(
                            labelText: 'Name',
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            filled: false,
                          ),
                          textCapitalization: TextCapitalization.words,
                        ),
                        isFirst: true,
                        isLast: false,
                      ),
                    ],
                    _field(
                      isFirst: _isSignInMode,
                      isLast: false,
                      child: TextFormField(
                        controller: _emailController,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          filled: false,
                        ),
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Enter your email';
                          }
                          if (!value.contains('@')) {
                            return 'Enter a valid email';
                          }
                          return null;
                        },
                      ),
                    ),
                    _field(
                      isFirst: false,
                      isLast: true,
                      child: TextFormField(
                        controller: _passwordController,
                        focusNode: _passwordFocus,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          filled: false,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? MdiIcons.eyeOffOutline
                                  : MdiIcons.eyeOutline,
                            ),
                            onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword,
                            ),
                          ),
                        ),
                        obscureText: _obscurePassword,
                        textInputAction: TextInputAction.done,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Enter your password';
                          }
                          if (!_isSignInMode && value.length < 8) {
                            return 'Password must be at least 8 characters';
                          }
                          return null;
                        },
                        onFieldSubmitted: (_) => _handleSubmit(),
                      ),
                    ),

                    if (authState.error != null) ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(
                            AppShapes.dockField,
                          ),
                        ),
                        child: Text(
                          authState.error!,
                          style: const TextStyle(
                            color: AppColors.error,
                            fontSize: 13.5,
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),

                    SizedBox(
                      height: 54,
                      child: FilledButton(
                        onPressed: authState.isLoading ? null : _handleSubmit,
                        child: authState.isLoading
                            ? SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.onPrimary,
                                ),
                              )
                            : Text(
                                _isSignInMode ? 'Sign in' : 'Create account',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    TextButton(
                      onPressed: authState.isLoading ? null : _toggleMode,
                      child: Text(
                        _isSignInMode
                            ? "No account yet? Create one"
                            : 'Already have an account? Sign in',
                      ),
                    ),

                    const SizedBox(height: 4),

                    // Escape hatch: the app works without an account, so a
                    // failing sign-in must never lock anyone out.
                    SizedBox(
                      height: 50,
                      child: OutlinedButton.icon(
                        onPressed: authState.isLoading
                            ? null
                            : () => ref
                                  .read(authProvider.notifier)
                                  .returnToLocalMode(),
                        icon: Icon(MdiIcons.cellphone, size: 18),
                        label: const Text('Continue without account'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Local tasks stay on this device and are uploaded once '
                      'you sign in.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// One field of the rounded login group.
  Widget _field({
    required Widget child,
    required bool isFirst,
    required bool isLast,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppShapes.groupGap),
      child: Material(
        color: AppColors.surface,
        borderRadius: AppShapes.row(isFirst: isFirst, isLast: isLast),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: child,
        ),
      ),
    );
  }
}
