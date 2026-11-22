import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:sewa_garasi/app.dart';
import 'package:sewa_garasi/core/utils/validators.dart';
import 'package:sewa_garasi/models/user.dart';
import 'package:sewa_garasi/viewmodels/auth_view_model.dart';
import 'package:sewa_garasi/views/components/app_card.dart';
import 'package:sewa_garasi/views/components/app_text_field.dart';
import 'package:sewa_garasi/views/components/image_picker_field.dart';
import 'package:sewa_garasi/views/components/primary_button.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nikCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  String? _ktpPath;
  String? _ktpError;

  @override
  void dispose() {
    for (final c in [
      _nikCtrl,
      _nameCtrl,
      _phoneCtrl,
      _emailCtrl,
      _passwordCtrl,
      _confirmCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    final valid = _formKey.currentState!.validate();
    setState(
        () => _ktpError = _ktpPath == null ? 'Foto KTP wajib diupload' : null);
    if (!valid || _ktpPath == null) return;

    final auth = context.read<AuthViewModel>();
    final ok = await auth.register(
      User(
        nik: _nikCtrl.text.trim(),
        fullName: _nameCtrl.text,
        phone: _phoneCtrl.text,
        email: _emailCtrl.text,
        ktpImagePath: _ktpPath,
      ),
      _passwordCtrl.text,
    );
    if (!mounted) return;
    if (!ok) {
      showMessage(context, auth.errorMessage ?? 'Pendaftaran gagal',
          isError: true);
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Pendaftaran Berhasil'),
        content: const Text(
            'Data Anda akan diverifikasi oleh admin. Silakan login setelah '
            'pendaftaran diterima.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
        ],
      ),
    );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = context.watch<AuthViewModel>().isLoading;
    return Scaffold(
      appBar: AppBar(title: const Text('Daftar Penyewa')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const NoticeCard(
                icon: Icons.info_outline,
                title: 'Verifikasi Admin',
                child: Text(
                  'Setelah mendaftar, data Anda akan dicek oleh admin. '
                  'Anda bisa login setelah pendaftaran diterima.',
                  style: TextStyle(height: 1.4),
                ),
              ),
              const SizedBox(height: 16),
              const SectionLabel('Data Diri'),
              FormSection(children: [
                AppTextField(
                  label: 'NIK (Nomor KTP)',
                  controller: _nikCtrl,
                  keyboardType: TextInputType.number,
                  maxLength: 16,
                  prefixIcon: Icons.badge_outlined,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: Validators.nik,
                ),
                AppTextField(
                  label: 'Nama Lengkap',
                  controller: _nameCtrl,
                  prefixIcon: Icons.person_outline,
                  validator: (v) => Validators.required(v, 'Nama lengkap'),
                ),
                AppTextField(
                  label: 'Nomor Telepon',
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  prefixIcon: Icons.phone_outlined,
                  validator: Validators.phone,
                ),
              ]),
              const SectionLabel('Akun'),
              FormSection(children: [
                AppTextField(
                  label: 'Email (username)',
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  prefixIcon: Icons.mail_outline,
                  validator: Validators.email,
                ),
                AppTextField(
                  label: 'Password',
                  controller: _passwordCtrl,
                  obscureText: true,
                  prefixIcon: Icons.lock_outline,
                  validator: Validators.password,
                ),
                AppTextField(
                  label: 'Konfirmasi Password',
                  controller: _confirmCtrl,
                  obscureText: true,
                  prefixIcon: Icons.lock_outline,
                  validator: (v) =>
                      v != _passwordCtrl.text ? 'Password tidak sama' : null,
                ),
              ]),
              const SectionLabel('Dokumen'),
              ImagePickerField(
                label: 'Foto KTP',
                imagePath: _ktpPath,
                folder: 'ktp',
                errorText: _ktpError,
                onChanged: (path) => setState(() {
                  _ktpPath = path;
                  _ktpError = null;
                }),
              ),
              const SizedBox(height: 8),
              PrimaryButton(
                label: 'Daftar',
                isLoading: isLoading,
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
