import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:sewa_garasi/app.dart';
import 'package:sewa_garasi/core/constants/app_colors.dart';
import 'package:sewa_garasi/core/utils/date_helper.dart';
import 'package:sewa_garasi/models/user.dart';
import 'package:sewa_garasi/viewmodels/auth_view_model.dart';
import 'package:sewa_garasi/views/components/app_card.dart';
import 'package:sewa_garasi/views/components/image_picker_field.dart';
import 'package:sewa_garasi/views/components/info_row.dart';
import 'package:sewa_garasi/views/components/primary_button.dart';

class TenantDetailScreen extends StatelessWidget {
  const TenantDetailScreen({super.key, required this.user});

  final User user;

  Future<void> _verify(BuildContext context, bool approved) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(approved ? 'Terima Pendaftar?' : 'Tolak Pendaftar?'),
        content: Text('${user.fullName} (${user.email})'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(approved ? 'Terima' : 'Tolak')),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final vm = context.read<AuthViewModel>();
    final ok = await vm.verifyTenant(user.id!, approved);
    if (!context.mounted) return;
    if (!ok) {
      showMessage(context, vm.errorMessage ?? 'Gagal', isError: true);
      return;
    }
    showMessage(context, approved ? 'Pendaftar diterima' : 'Pendaftar ditolak');
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = context.watch<AuthViewModel>().isLoading;
    return Scaffold(
      appBar: AppBar(title: const Text('Detail Pendaftar')),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: PrimaryButton(
                  label: 'Tolak',
                  icon: Icons.close,
                  color: AppColors.danger,
                  isLoading: isLoading,
                  onPressed: () => _verify(context, false),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: PrimaryButton(
                  label: 'Terima',
                  icon: Icons.check,
                  color: AppColors.success,
                  isLoading: isLoading,
                  onPressed: () => _verify(context, true),
                ),
              ),
            ],
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        children: [
          InfoSection(
              title: 'Data Pendaftar',
              icon: Icons.person_outline,
              children: [
                InfoRow(label: 'NIK', value: user.nik ?? '-'),
                InfoRow(label: 'Nama Lengkap', value: user.fullName),
                InfoRow(label: 'Telepon', value: user.phone),
                InfoRow(label: 'Email', value: user.email),
                InfoRow(
                    label: 'Tanggal Daftar',
                    value: DateHelper.display(user.createdAt)),
              ]),
          InfoSection(
            title: 'Foto KTP',
            icon: Icons.badge_outlined,
            children: [
              LocalImage(path: user.ktpImagePath, height: 220),
              const SizedBox(height: 8),
              const Text('Ketuk gambar untuk memperbesar',
                  style:
                      TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              const SizedBox(height: 4),
            ],
          ),
          const NoticeCard(
            tone: NoticeTone.neutral,
            icon: Icons.fact_check_outlined,
            title: 'Cocokkan data',
            child: Text('Pastikan NIK dan nama sesuai dengan foto KTP sebelum '
                'menerima pendaftar.'),
          ),
        ],
      ),
    );
  }
}
