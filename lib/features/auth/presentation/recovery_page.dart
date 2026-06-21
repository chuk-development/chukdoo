import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../providers/auth_provider.dart';

class RecoveryPage extends ConsumerStatefulWidget {
  const RecoveryPage({super.key});

  @override
  ConsumerState<RecoveryPage> createState() => _RecoveryPageState();
}

class _RecoveryPageState extends ConsumerState<RecoveryPage> {
  final _formKey = GlobalKey<FormState>();
  final _code1Controller = TextEditingController();
  final _code2Controller = TextEditingController();
  final _code3Controller = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  final _code1Focus = FocusNode();
  final _code2Focus = FocusNode();
  final _code3Focus = FocusNode();
  final _passwordFocus = FocusNode();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _code1Controller.dispose();
    _code2Controller.dispose();
    _code3Controller.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _code1Focus.dispose();
    _code2Focus.dispose();
    _code3Focus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  String get _fullCode {
    return '${_code1Controller.text}-${_code2Controller.text}-${_code3Controller.text}';
  }

  Future<void> _handleRecovery() async {
    if (!_formKey.currentState!.validate()) return;

    await ref.read(authProvider.notifier).recoverWithBackupCode(
          code: _fullCode,
          newPassword: _passwordController.text,
        );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Recover account'),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          MdiIcons.keyOutline,
                          size: 48,
                          color: AppColors.primary,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Enter one of your backup codes to reset your password.',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Backup code input
                  const Text(
                    'Backup code',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _buildCodeField(
                          controller: _code1Controller,
                          focusNode: _code1Focus,
                          nextFocusNode: _code2Focus,
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          '-',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                      Expanded(
                        child: _buildCodeField(
                          controller: _code2Controller,
                          focusNode: _code2Focus,
                          nextFocusNode: _code3Focus,
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          '-',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                      Expanded(
                        child: _buildCodeField(
                          controller: _code3Controller,
                          focusNode: _code3Focus,
                          nextFocusNode: _passwordFocus,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // New password
                  TextFormField(
                    controller: _passwordController,
                    focusNode: _passwordFocus,
                    decoration: InputDecoration(
                      labelText: 'New password',
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
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Enter a password';
                      }
                      if (value.length < 8) {
                        return 'At least 8 characters';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 16),

                  // Confirm password
                  TextFormField(
                    controller: _confirmPasswordController,
                    decoration: InputDecoration(
                      labelText: 'Confirm password',
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureConfirmPassword
                              ? MdiIcons.eyeOffOutline
                              : MdiIcons.eyeOutline,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscureConfirmPassword = !_obscureConfirmPassword;
                          });
                        },
                      ),
                    ),
                    obscureText: _obscureConfirmPassword,
                    validator: (value) {
                      if (value != _passwordController.text) {
                        return 'Passwords do not match';
                      }
                      return null;
                    },
                    onFieldSubmitted: (_) => _handleRecovery(),
                  ),

                  // Error message
                  if (authState.error != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.error.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            MdiIcons.alertOutline,
                            size: 20,
                            color: AppColors.error,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              authState.error!,
                              style: const TextStyle(
                                color: AppColors.error,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),

                  // Recovery button
                  SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: authState.isLoading ? null : _handleRecovery,
                      child: authState.isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Reset password'),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Cancel button
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCodeField({
    required TextEditingController controller,
    required FocusNode focusNode,
    FocusNode? nextFocusNode,
  }) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      textAlign: TextAlign.center,
      textCapitalization: TextCapitalization.characters,
      style: const TextStyle(
        fontFamily: 'monospace',
        fontSize: 18,
        fontWeight: FontWeight.bold,
        letterSpacing: 2,
      ),
      decoration: const InputDecoration(
        counterText: '',
        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 16),
      ),
      maxLength: 4,
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
        UpperCaseTextFormatter(),
      ],
      validator: (value) {
        if (value == null || value.length != 4) {
          return '';
        }
        return null;
      },
      onChanged: (value) {
        if (value.length == 4 && nextFocusNode != null) {
          nextFocusNode.requestFocus();
        }
      },
    );
  }
}

/// Formatter to convert text to uppercase
class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}
