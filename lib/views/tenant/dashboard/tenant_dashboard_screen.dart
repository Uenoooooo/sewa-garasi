import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:sewa_garasi/app.dart';
import 'package:sewa_garasi/core/constants/app_colors.dart';
import 'package:sewa_garasi/core/utils/currency_formatter.dart';
import 'package:sewa_garasi/core/utils/date_helper.dart';
import 'package:sewa_garasi/models/rental.dart';
import 'package:sewa_garasi/repositories/garage_repository.dart';
import 'package:sewa_garasi/viewmodels/auth_view_model.dart';
import 'package:sewa_garasi/viewmodels/dashboard_view_model.dart';
import 'package:sewa_garasi/viewmodels/rental_view_model.dart';
import 'package:sewa_garasi/viewmodels/vehicle_view_model.dart';
import 'package:sewa_garasi/views/components/dashboard_widgets.dart';
import 'package:sewa_garasi/views/tenant/rental/rental_detail_screen.dart';
import 'package:sewa_garasi/views/tenant/rental/rental_form_screen.dart';
import 'package:sewa_garasi/views/tenant/rental/rental_history_screen.dart';
import 'package:sewa_garasi/views/tenant/vehicle/vehicle_list_screen.dart';
import 'package:sewa_garasi/views/components/type_icons.dart';

class TenantDashboardScreen extends StatefulWidget {
  const TenantDashboardScreen({super.key});

  @override
  State<TenantDashboardScreen> createState() => _TenantDashboardScreenState();
}

class _TenantDashboardScreenState extends State<TenantDashboardScreen> {
  static const int _rentIndex = 1;

  int _tab = 0;

  int _homeVersion = 0;

  Future<void> _openRentalForm() async {
    await Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const RentalFormScreen()));
    if (mounted) setState(() => _homeVersion++);
  }

  void _select(int index) {
    if (index == _rentIndex) {
      _openRentalForm();
      return;
    }
    setState(() => _tab = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: switch (_tab) {
        2 => const VehicleListScreen(),
        3 => const RentalHistoryScreen(),
        _ => _TenantHome(
            key: ValueKey(_homeVersion),
            onRent: _openRentalForm,
            onSelectTab: _select,
          ),
      },
      bottomNavigationBar: AppBottomNav(
        selectedIndex: _tab,
        onSelected: _select,
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded),
              label: 'Beranda'),
          NavigationDestination(
              icon: Icon(Icons.add_business_outlined), label: 'Sewa'),
          NavigationDestination(
              icon: Icon(Icons.directions_car_outlined),
              selectedIcon: Icon(Icons.directions_car_rounded),
              label: 'Kendaraan'),
          NavigationDestination(
              icon: Icon(Icons.history_rounded), label: 'Riwayat'),
        ],
      ),
    );
  }
}

class _TenantHome extends StatefulWidget {
  const _TenantHome({
    super.key,
    required this.onRent,
    required this.onSelectTab,
  });

  final VoidCallback onRent;
  final ValueChanged<int> onSelectTab;

  @override
  State<_TenantHome> createState() => _TenantHomeState();
}

class _TenantHomeState extends State<_TenantHome> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final userId = context.read<AuthViewModel>().currentUser!.id!;
    await Future.wait([
      context.read<RentalViewModel>().loadRentalHistory(userId),
      context.read<VehicleViewModel>().loadVehicles(userId),
      context.read<DashboardViewModel>().loadGarageAvailability(),
    ]);
  }

  Future<void> _openDetail(Rental rental) async {
    await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => RentalDetailScreen(rentalId: rental.id!)));
    if (mounted) await _load();
  }

  static String _greeting() {
    final h = DateTime.now().hour;
    if (h < 11) return 'Selamat pagi,';
    if (h < 15) return 'Selamat siang,';
    if (h < 18) return 'Selamat sore,';
    return 'Selamat malam,';
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthViewModel>().currentUser;
    final rentalVm = context.watch<RentalViewModel>();
    final vehicles = context.watch<VehicleViewModel>().vehicles;
    final dash = context.watch<DashboardViewModel>();

    final today = DateHelper.today();
    final rentals = rentalVm.rentalHistory;
    final active = rentals.where((r) => r.isActiveOn(today)).toList()
      ..sort((a, b) => a.endDate.compareTo(b.endDate));
    final upcoming = rentals.where((r) => r.startDate.isAfter(today)).toList()
      ..sort((a, b) => a.startDate.compareTo(b.startDate));
    final finished = rentals.where((r) => r.endDate.isBefore(today)).length;
    final name = user?.fullName ?? 'Penyewa';

    final heroList = active.isNotEmpty ? active : upcoming;

    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            DashboardHeader(
              avatar: AvatarCircle(
                text: initialsOf(name),
                color: Colors.white,
                background: AppColors.primary,
              ),
              caption: _greeting(),
              name: name,
              actions: [
                HeaderIconButton(
                    icon: Icons.logout_rounded,
                    tooltip: 'Logout',
                    onPressed: () => logout(context)),
              ],
            ),
            const SizedBox(height: 18),
            if (heroList.isNotEmpty)
              _RentalHero(
                rental: heroList.first,
                others: heroList.length - 1,
                onDetail: () => _openDetail(heroList.first),
                onSeeAll: () => widget.onSelectTab(3),
              )
            else
              _EmptyHero(
                loading: rentalVm.isLoading && rentals.isEmpty,
                onRent: widget.onRent,
              ),
            const SizedBox(height: 12),
            QuickActionRow(children: [
              QuickAction(
                icon: Icons.add_business_outlined,
                label: 'Sewa Garasi',
                onTap: widget.onRent,
              ),
              QuickAction(
                icon: Icons.directions_car_outlined,
                label: 'Kendaraan',
                color: AppColors.success,
                background: AppColors.successLight,
                onTap: () => widget.onSelectTab(2),
              ),
              QuickAction(
                icon: Icons.history_rounded,
                label: 'Riwayat',
                color: AppColors.warning,
                background: AppColors.warningLight,
                onTap: () => widget.onSelectTab(3),
              ),
            ]),
            const SizedBox(height: 12),
            _StatsStrip(items: [
              ('${vehicles.length}', 'Kendaraan'),
              ('${active.length}', 'Sewa aktif'),
              ('$finished', 'Selesai'),
            ]),
            const SizedBox(height: 24),
            const SectionHeader('Garasi tersedia hari ini'),
            GroupedCard(children: [
              if (dash.availability.every((a) => a.total == 0))
                InlineEmpty(
                    icon: Icons.garage_outlined,
                    message: dash.isLoading
                        ? 'Memuat...'
                        : 'Belum ada garasi yang disewakan.'),
              for (final a in dash.availability)
                if (a.total > 0) _AvailabilityRow(a, onRent: widget.onRent),
            ]),
          ],
        ),
      ),
    );
  }
}

class _RentalHero extends StatelessWidget {
  const _RentalHero({
    required this.rental,
    required this.others,
    required this.onDetail,
    required this.onSeeAll,
  });

  final Rental rental;

  final int others;
  final VoidCallback onDetail;
  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context) {
    final r = rental;
    final today = DateHelper.today();
    final running = r.isActiveOn(today);
    final faded = Colors.white.withValues(alpha: 0.75);

    final String middle;
    final double progress;
    if (running) {
      final left = DateHelper.daysBetween(today, r.endDate);
      middle = left == 0 ? 'Hari terakhir' : 'Sisa $left hari';
      progress = (DateHelper.daysBetween(r.startDate, today) + 1) /
          DateHelper.daysInclusive(r.startDate, r.endDate);
    } else {
      final startsIn = DateHelper.daysBetween(today, r.startDate);
      middle = startsIn == 1 ? 'Mulai besok' : 'Mulai $startsIn hari lagi';
      progress = 0;
    }

    return HeroCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(running ? 'SEWA AKTIF' : 'SEWA BERIKUTNYA',
                    style: TextStyle(
                        color: faded,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8)),
              ),
              PillLabel(
                text: running ? 'Berjalan' : 'Akan datang',
                color: running ? AppColors.success : AppColors.info,
                background:
                    running ? AppColors.successLight : AppColors.infoLight,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(r.garageType?.icon ?? Icons.garage_outlined,
                    color: Colors.white, size: 26),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Garasi ${r.garageId}',
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text(r.vehicleName ?? '-',
                        style: TextStyle(color: faded, fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text(DateHelper.display(r.startDate),
                  style: TextStyle(color: faded, fontSize: 12)),
              Expanded(
                child: Text(middle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w700)),
              ),
              Text(DateHelper.display(r.endDate),
                  style: TextStyle(color: faded, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 8),
          HeroProgress(value: progress),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onDetail,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.primary,
                minimumSize: const Size.fromHeight(46),
              ),
              child: const Text('Lihat detail',
                  style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
          if (others > 0) ...[
            const SizedBox(height: 4),
            Center(
              child: TextButton(
                onPressed: onSeeAll,
                style: TextButton.styleFrom(foregroundColor: Colors.white),
                child: Text('+$others sewa lainnya di Riwayat'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _EmptyHero extends StatelessWidget {
  const _EmptyHero({required this.loading, required this.onRent});

  final bool loading;
  final VoidCallback onRent;

  @override
  Widget build(BuildContext context) {
    return HeroCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(loading ? 'Memuat sewa...' : 'Belum ada sewa aktif',
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(
            'Pilih tanggal mulai dan sewa garasi harian atau bulanan.',
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8), fontSize: 13),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onRent,
              icon: const Icon(Icons.add_business_outlined, size: 20),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.primary,
                minimumSize: const Size.fromHeight(46),
              ),
              label: const Text('Sewa Garasi',
                  style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsStrip extends StatelessWidget {
  const _StatsStrip({required this.items});

  final List<(String, String)> items;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: IntrinsicHeight(
        child: Row(
          children: [
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0)
                const VerticalDivider(
                    width: 1,
                    indent: 14,
                    endIndent: 14,
                    color: AppColors.border),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Column(
                    children: [
                      Text(items[i].$1,
                          style: const TextStyle(
                              fontSize: 22, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 2),
                      Text(items[i].$2,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: AppColors.textSecondary, fontSize: 12)),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AvailabilityRow extends StatelessWidget {
  const _AvailabilityRow(this.item, {required this.onRent});

  final GarageAvailability item;
  final VoidCallback onRent;

  @override
  Widget build(BuildContext context) {
    final a = item;
    final full = a.available == 0;
    final (color, bg) = a.type.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
                color: bg, borderRadius: BorderRadius.circular(12)),
            child: Icon(a.type.icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(a.type.label,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 15)),
                const SizedBox(height: 2),
                Text(
                  full
                      ? 'Penuh hari ini · ${a.total} garasi'
                      : '${a.available} dari ${a.total} kosong · mulai '
                          '${CurrencyFormatter.rupiah(a.minDailyPrice ?? 0)}'
                          '/hari',
                  style: TextStyle(
                      color: full ? AppColors.danger : AppColors.textSecondary,
                      fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            height: 38,
            child: ElevatedButton(
              onPressed: onRent,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(0, 38),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Sewa',
                  style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}
