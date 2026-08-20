import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isRegistering = false;
  bool _isSubmitting = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final auth = ref.read(authProvider.notifier);
      if (_isRegistering) {
        await auth.register(
          name: _nameController.text,
          email: _emailController.text,
          password: _passwordController.text,
        );
      } else {
        await auth.login(
          email: _emailController.text,
          password: _passwordController.text,
        );
      }

      if (!mounted) return;
      context.go(_isRegistering ? '/onboarding' : '/home/dashboard');
    } catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = _readableError(error));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  String _readableError(Object error) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map<String, dynamic> && data['detail'] != null) {
        return data['detail'].toString();
      }
      if (error.type == DioExceptionType.connectionError ||
          error.type == DioExceptionType.connectionTimeout) {
        return 'Cannot reach Budgcoach. Check that the API is running and try again.';
      }
    }
    return 'We could not complete that request. Please try again.';
  }

  void _toggleMode() {
    setState(() {
      _isRegistering = !_isRegistering;
      _errorMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 88,
                    height: 88,
                    decoration: const BoxDecoration(
                      color: Color(0xFFE8F5EF),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.energy_savings_leaf,
                      color: AppColors.primary,
                      size: 50,
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  _isRegistering ? 'Create your account' : 'Welcome back',
                  style: AppTextStyles.displayLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  _isRegistering
                      ? 'Start building a clearer picture of your money.'
                      : 'Sign in to continue to your budget coach.',
                  style: AppTextStyles.bodyLarge.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                if (_isRegistering) ...[
                  TextFormField(
                    controller: _nameController,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.name],
                    decoration: const InputDecoration(
                      labelText: 'Full name',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    validator: (value) =>
                        value == null || value.trim().length < 2
                        ? 'Enter your full name'
                        : null,
                  ),
                  const SizedBox(height: 16),
                ],
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.email],
                  autocorrect: false,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  validator: (value) {
                    final email = value?.trim() ?? '';
                    return email.contains('@')
                        ? null
                        : 'Enter a valid email address';
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.password],
                  onFieldSubmitted: (_) {
                    if (!_isSubmitting) _submit();
                  },
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                    ),
                  ),
                  validator: (value) => value == null || value.length < 8
                      ? 'Use at least 8 characters'
                      : null,
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.danger.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.danger,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(_isRegistering ? 'CREATE ACCOUNT' : 'SIGN IN'),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _isSubmitting ? null : _toggleMode,
                  child: Text(
                    _isRegistering
                        ? 'Already have an account? Sign in'
                        : 'New to Budgcoach? Create an account',
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'By continuing, you agree to our Terms of Service and Privacy Policy.',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
