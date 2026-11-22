import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:sewa_garasi/core/utils/date_helper.dart';
import 'package:sewa_garasi/viewmodels/auth_view_model.dart';
import 'package:sewa_garasi/views/admin/verification/tenant_detail_screen.dart';
import 'package:sewa_garasi/views/components/app_card.dart';
import 'package:sewa_garasi/views/components/empty_state.dart';

class PendingTenantListScreen extends StatefulWidget {
  const PendingTenantListScreen({super.key});

  @override
  State<PendingTenantListScreen> createState() =>
      _PendingTenantListScreenState();
}

class _PendingTenantListScreenState extends State<PendingTenantListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
        (_) => context.read<AuthViewModel>().loadPendingTenants());
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AuthViewModel>();
    return Scaffold(
      appBar: AppBar(title: const Text('Verifikasi Pendaftar')),
      body: _body(vm),
    );
  }

  Widget _body(AuthViewModel vm) {
    if (vm.pendingTenants.isEmpty && vm.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (vm.pendingTenants.isEmpty) {
      return const EmptyState(
          message: 'Tidak ada pendaftar yang menunggu verifikasi.',
          icon: Icons.how_to_reg_outlined);
    }
    return RefreshIndicator(
      onRefresh: vm.loadPendingTenants,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: vm.pendingTenants.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) {
          final u = vm.pendingTenants[i];
          return AppListCard(
            leading: LeadingBox(
              text:
                  u.fullName.isEmpty ? '?' : u.fullName.trim()[0].toUpperCase(),
            ),
            title: u.fullName,
            lines: [
              'NIK ${u.nik}',
              u.email,
              'Daftar ${DateHelper.display(u.createdAt)}',
            ],
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => TenantDetailScreen(user: u)),
            ),
          );
        },
      ),
    );
  }
}
