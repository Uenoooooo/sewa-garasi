import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:sewa_garasi/app.dart';
import 'package:sewa_garasi/core/constants/app_colors.dart';
import 'package:sewa_garasi/core/utils/validators.dart';
import 'package:sewa_garasi/viewmodels/auth_view_model.dart';
import 'package:sewa_garasi/views/admin/dashboard/admin_dashboard_screen.dart';
import 'package:sewa_garasi/views/auth/register_screen.dart';
import 'package:sewa_garasi/views/components/app_text_field.dart';
import 'package:sewa_garasi/views/components/primary_button.dart';
import 'package:sewa_garasi/views/tenant/dashboard/tenant_dashboard_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthViewModel>();
    final ok = await auth.login(_emailCtrl.text, _passwordCtrl.text);
    if (!mounted) return;
    if (!ok) {
      showMessage(context, auth.errorMessage ?? 'Login gagal', isError: true);
      return;
    }
    final Widget home = auth.currentUser!.isAdmin()
        ? const AdminDashboardScreen()
        : const TenantDashboardScreen();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => home),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = context.watch<AuthViewModel>().isLoading;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 84,
                        height: 84,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppColors.primary, AppColors.primaryDark],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.3),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.garage_rounded,
                            size: 44, color: Colors.white),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text('Sewa Garasi',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 28, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    const Text('Masuk untuk melanjutkan',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: AppColors.textSecondary, fontSize: 15)),
                    const SizedBox(height: 32),
                    AppTextField(
                      label: 'Email',
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      prefixIcon: Icons.mail_outline,
                      validator: Validators.email,
                    ),
                    AppTextField(
                      label: 'Password',
                      controller: _passwordCtrl,
                      obscureText: _obscure,
                      prefixIcon: Icons.lock_outline,
                      validator: Validators.password,
                      suffix: IconButton(
                        icon: Icon(_obscure
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                    const SizedBox(height: 4),
                    PrimaryButton(
                      label: 'Login',
                      isLoading: isLoading,
                      onPressed: _submit,
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => const RegisterScreen()),
                      ),
                      child: const Text(
                          'Belum punya akun? Daftar sebagai Penyewa'),
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
