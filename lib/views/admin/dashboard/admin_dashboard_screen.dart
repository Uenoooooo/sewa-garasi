import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:sewa_garasi/app.dart';
import 'package:sewa_garasi/core/constants/app_colors.dart';
import 'package:sewa_garasi/core/utils/date_helper.dart';
import 'package:sewa_garasi/models/rental.dart';
import 'package:sewa_garasi/models/user.dart';
import 'package:sewa_garasi/viewmodels/auth_view_model.dart';
import 'package:sewa_garasi/viewmodels/dashboard_view_model.dart';
import 'package:sewa_garasi/views/admin/extension/active_rental_list_screen.dart';
import 'package:sewa_garasi/views/admin/extension/extend_rental_screen.dart';
import 'package:sewa_garasi/views/admin/garage/garage_list_screen.dart';
import 'package:sewa_garasi/views/admin/report/report_screen.dart';
import 'package:sewa_garasi/views/admin/verification/pending_tenant_list_screen.dart';
import 'package:sewa_garasi/views/admin/verification/tenant_detail_screen.dart';
import 'package:sewa_garasi/views/components/dashboard_widgets.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final pending = context.watch<AuthViewModel>().pendingTenants.length;
    return Scaffold(
      body: switch (_tab) {
        1 => const GarageListScreen(),
        2 => const PendingTenantListScreen(),
        3 => const ReportScreen(),
        _ => _AdminHome(onSelectTab: (i) => setState(() => _tab = i)),
      },
      bottomNavigationBar: AppBottomNav(
        selectedIndex: _tab,
        onSelected: (i) => setState(() => _tab = i),
        destinations: [
          const NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded),
              label: 'Beranda'),
          const NavigationDestination(
              icon: Icon(Icons.garage_outlined),
              selectedIcon: Icon(Icons.garage_rounded),
              label: 'Garasi'),
          NavigationDestination(
              icon: Badge(
                isLabelVisible: pending > 0,
                label: Text('$pending'),
                backgroundColor: AppColors.danger,
                child: const Icon(Icons.how_to_reg_outlined),
              ),
              selectedIcon: const Icon(Icons.how_to_reg_rounded),
              label: 'Penyewa'),
          const NavigationDestination(
              icon: Icon(Icons.bar_chart_outlined),
              selectedIcon: Icon(Icons.bar_chart_rounded),
              label: 'Laporan'),
        ],
      ),
    );
  }
}

class _AdminHome extends StatefulWidget {
  const _AdminHome({required this.onSelectTab});

  final ValueChanged<int> onSelectTab;

  @override
  State<_AdminHome> createState() => _AdminHomeState();
}

class _AdminHomeState extends State<_AdminHome> {
  static const int _previewCount = 3;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    await Future.wait([
      context.read<AuthViewModel>().loadPendingTenants(),
      context.read<DashboardViewModel>().loadAdminSummary(),
    ]);
  }

  Future<void> _open(Widget page) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
    if (mounted) await _load();
  }

  Future<void> _verify(User user, bool approved) async {
    if (!approved) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Tolak Pendaftar?'),
          content: Text('${user.fullName} (${user.email})'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Batal')),
            TextButton(
                style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Tolak')),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    final vm = context.read<AuthViewModel>();
    final ok = await vm.verifyTenant(user.id!, approved);
    if (!mounted) return;
    showMessage(
      context,
      ok
          ? '${user.fullName} ${approved ? 'diterima' : 'ditolak'}'
          : vm.errorMessage ?? 'Gagal memverifikasi',
      isError: !ok,
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthViewModel>();
    final dash = context.watch<DashboardViewModel>();
    final pending = auth.pendingTenants;
    final ending = dash.endingSoon;

    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            DashboardHeader(
              avatar: const AvatarCircle(
                icon: Icons.admin_panel_settings_outlined,
                color: Colors.white,
                background: AppColors.primary,
              ),
              caption: 'Dashboard Admin',
              name: auth.currentUser?.fullName ?? 'Admin',
              actions: [
                HeaderIconButton(
                    icon: Icons.logout_rounded,
                    tooltip: 'Logout',
                    onPressed: () => logout(context)),
              ],
            ),
            const SizedBox(height: 18),
            _OccupancyCard(
              used: dash.usedGarages,
              total: dash.totalGarages,
              rate: dash.occupancyRate,
              onTap: () => widget.onSelectTab(1),
            ),
            const SizedBox(height: 12),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: StatTile(
                      label: 'Menunggu verifikasi',
                      value: '${pending.length}',
                      valueColor: pending.isEmpty
                          ? AppColors.textPrimary
                          : AppColors.warning,
                      onTap: () => widget.onSelectTab(2),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: StatTile(
                      label:
                          'Berakhir ≤ ${DashboardViewModel.endingSoonDays} hari',
                      value: '${ending.length}',
                      onTap: () => _open(const ActiveRentalListScreen()),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            QuickActionRow(children: [
              QuickAction(
                icon: Icons.garage_outlined,
                label: 'Garasi',
                onTap: () => widget.onSelectTab(1),
              ),
              QuickAction(
                icon: Icons.verified_user_outlined,
                label: 'Verifikasi',
                color: AppColors.success,
                background: AppColors.successLight,
                badgeCount: pending.length,
                onTap: () => widget.onSelectTab(2),
              ),
              QuickAction(
                icon: Icons.event_repeat_outlined,
                label: 'Perpanjang',
                color: AppColors.warning,
                background: AppColors.warningLight,
                onTap: () => _open(const ActiveRentalListScreen()),
              ),
              QuickAction(
                icon: Icons.bar_chart_rounded,
                label: 'Laporan',
                color: AppColors.purple,
                background: AppColors.purpleLight,
                onTap: () => widget.onSelectTab(3),
              ),
            ]),
            const SizedBox(height: 24),
            SectionHeader(
              'Perlu verifikasi',
              onSeeAll: pending.isEmpty ? null : () => widget.onSelectTab(2),
            ),
            GroupedCard(children: [
              if (pending.isEmpty)
                const InlineEmpty(
                    icon: Icons.how_to_reg_outlined,
                    message: 'Tidak ada pendaftar yang menunggu.'),
              for (final u in pending.take(_previewCount))
                _PendingRow(
                  user: u,
                  busy: auth.isLoading,
                  onOpen: () => _open(TenantDetailScreen(user: u)),
                  onAccept: () => _verify(u, true),
                  onReject: () => _verify(u, false),
                ),
            ]),
            const SizedBox(height: 24),
            SectionHeader(
              'Segera berakhir',
              onSeeAll: () => _open(const ActiveRentalListScreen()),
            ),
            GroupedCard(children: [
              if (ending.isEmpty)
                InlineEmpty(
                    icon: Icons.event_available_outlined,
                    message: dash.isLoading
                        ? 'Memuat...'
                        : 'Tidak ada sewa yang berakhir dalam '
                            '${DashboardViewModel.endingSoonDays} hari.'),
              for (final r in ending.take(_previewCount))
                _EndingRow(
                  rental: r,
                  onTap: () => _open(ExtendRentalScreen(rental: r)),
                ),
            ]),
          ],
        ),
      ),
    );
  }
}

class _OccupancyCard extends StatelessWidget {
  const _OccupancyCard({
    required this.used,
    required this.total,
    required this.rate,
    required this.onTap,
  });

  final int used;
  final int total;
  final double rate;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final faded = Colors.white.withValues(alpha: 0.75);
    return GestureDetector(
      onTap: onTap,
      child: HeroCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Okupansi garasi',
                      style: TextStyle(color: faded, fontSize: 13)),
                ),
                Text('hari ini', style: TextStyle(color: faded, fontSize: 13)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text('$used',
                    style: const TextStyle(
                        fontSize: 34, fontWeight: FontWeight.w800)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                      total == 0 ? 'belum ada garasi' : '/ $total terisi',
                      style: TextStyle(color: faded, fontSize: 15)),
                ),
                if (total > 0)
                  Text('${(rate * 100).round()}%',
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 12),
            HeroProgress(value: rate),
          ],
        ),
      ),
    );
  }
}

class _PendingRow extends StatelessWidget {
  const _PendingRow({
    required this.user,
    required this.busy,
    required this.onOpen,
    required this.onAccept,
    required this.onReject,
  });

  final User user;
  final bool busy;
  final VoidCallback onOpen;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onOpen,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
        child: Row(
          children: [
            AvatarCircle(text: initialsOf(user.fullName), size: 42),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(user.fullName,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 15)),
                  const SizedBox(height: 2),
                  Text('Daftar ${DateHelper.shortDate(user.createdAt)}',
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 13)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 40,
              height: 40,
              child: OutlinedButton(
                onPressed: busy ? null : onReject,
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(40, 40),
                  foregroundColor: AppColors.danger,
                  side: BorderSide(
                      color: AppColors.danger.withValues(alpha: 0.4)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: const Icon(Icons.close_rounded, size: 20),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              height: 40,
              child: ElevatedButton(
                onPressed: busy ? null : onAccept,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(0, 40),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Terima',
                    style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EndingRow extends StatelessWidget {
  const _EndingRow({required this.rental, required this.onTap});

  final Rental rental;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final r = rental;
    final left = DateHelper.daysBetween(DateHelper.today(), r.endDate);
    final urgent = left <= 2;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Garasi ${r.garageId} · ${r.vehicleName ?? '-'}',
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 15)),
                  const SizedBox(height: 2),
                  Text(
                      '${r.tenantName ?? '-'} · selesai '
                      '${DateHelper.shortDate(r.endDate)}',
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 13)),
                ],
              ),
            ),
            const SizedBox(width: 10),
            PillLabel(
              text: left == 0 ? 'Hari ini' : '$left hari',
              color: urgent ? AppColors.danger : AppColors.warning,
              background:
                  urgent ? AppColors.dangerLight : AppColors.warningLight,
            ),
          ],
        ),
      ),
    );
  }
}
