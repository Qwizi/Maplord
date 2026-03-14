import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _loading = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Color _passwordStrengthColor() {
    final length = _passwordController.text.length;
    if (length < 6) return Colors.red.shade400;
    if (length < 8) return Colors.orange.shade400;
    return Colors.green.shade400;
  }

  double _passwordStrengthValue() {
    final length = _passwordController.text.length;
    if (length == 0) return 0;
    if (length < 6) return 0.33;
    if (length < 8) return 0.66;
    return 1.0;
  }

  String _passwordStrengthLabel() {
    final length = _passwordController.text.length;
    if (length == 0) return '';
    if (length < 6) return 'Weak';
    if (length < 8) return 'Fair';
    return 'Strong';
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: Colors.grey.shade400),
      prefixIcon: Icon(prefixIcon, color: Colors.grey.shade400),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Colors.white.withOpacity(0.05),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF22D3EE)),
      ),
    );
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await context.read<AuthProvider>().register(
        _usernameController.text.trim(),
        _emailController.text.trim(),
        _passwordController.text,
      );
      // Auto login after successful registration
      await context.read<AuthProvider>().login(
        _emailController.text.trim(),
        _passwordController.text,
      );
      if (mounted) context.go('/dashboard');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0F172A),
              Color(0xFF1E293B),
              Color(0xFF0F172A),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.public,
                      size: 80,
                      color: Color(0xFF22D3EE),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'MAPLORD',
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF22D3EE),
                        letterSpacing: 4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Create your account',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade400,
                      ),
                    ),
                    const SizedBox(height: 40),
                    // Username field
                    TextFormField(
                      controller: _usernameController,
                      style: const TextStyle(color: Colors.white),
                      decoration: _inputDecoration(
                        label: 'Username',
                        prefixIcon: Icons.person_outline,
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Username is required';
                        }
                        if (v.trim().length < 3) {
                          return 'Min 3 characters';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    // Email field
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      style: const TextStyle(color: Colors.white),
                      decoration: _inputDecoration(
                        label: 'Email',
                        prefixIcon: Icons.email_outlined,
                      ),
                      validator: (v) =>
                          v == null || v.isEmpty ? 'Email is required' : null,
                    ),
                    const SizedBox(height: 16),
                    // Password field
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      style: const TextStyle(color: Colors.white),
                      onChanged: (_) => setState(() {}),
                      decoration: _inputDecoration(
                        label: 'Password',
                        prefixIcon: Icons.lock_outline,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                            color: Colors.grey.shade400,
                          ),
                          onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword,
                          ),
                        ),
                      ),
                      validator: (v) =>
                          v == null || v.length < 6 ? 'Min 6 characters' : null,
                    ),
                    // Password strength indicator
                    if (_passwordController.text.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: _passwordStrengthValue(),
                                backgroundColor: Colors.white.withOpacity(0.1),
                                color: _passwordStrengthColor(),
                                minHeight: 4,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            _passwordStrengthLabel(),
                            style: TextStyle(
                              fontSize: 12,
                              color: _passwordStrengthColor(),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 16),
                    // Confirm password field
                    TextFormField(
                      controller: _confirmPasswordController,
                      obscureText: _obscureConfirmPassword,
                      style: const TextStyle(color: Colors.white),
                      decoration: _inputDecoration(
                        label: 'Confirm Password',
                        prefixIcon: Icons.lock_outline,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureConfirmPassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                            color: Colors.grey.shade400,
                          ),
                          onPressed: () => setState(
                            () => _obscureConfirmPassword =
                                !_obscureConfirmPassword,
                          ),
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) {
                          return 'Please confirm your password';
                        }
                        if (v != _passwordController.text) {
                          return 'Passwords do not match';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    // Register button
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _register,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF22D3EE),
                          foregroundColor: const Color(0xFF0F172A),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        child: _loading
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Color(0xFF0F172A),
                                ),
                              )
                            : const Text('Create Account'),
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Sign in link
                    TextButton(
                      onPressed: () => context.go('/login'),
                      child: RichText(
                        text: TextSpan(
                          text: 'Already have an account? ',
                          style: TextStyle(color: Colors.grey.shade400),
                          children: const [
                            TextSpan(
                              text: 'Sign In',
                              style: TextStyle(
                                color: Color(0xFF22D3EE),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
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
}
