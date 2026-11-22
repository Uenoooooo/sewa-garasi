import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:sewa_garasi/core/constants/app_colors.dart';
import 'package:sewa_garasi/core/utils/date_helper.dart';
import 'package:sewa_garasi/models/rental.dart';
import 'package:sewa_garasi/viewmodels/rental_view_model.dart';
import 'package:sewa_garasi/views/admin/extension/extend_rental_screen.dart';
import 'package:sewa_garasi/views/components/app_card.dart';
import 'package:sewa_garasi/views/components/empty_state.dart';
import 'package:sewa_garasi/views/components/status_badge.dart';
import 'package:sewa_garasi/views/components/type_icons.dart';

class ActiveRentalListScreen extends StatefulWidget {
  const ActiveRentalListScreen({super.key});

  @override
  State<ActiveRentalListScreen> createState() => _ActiveRentalListScreenState();
}

class _ActiveRentalListScreenState extends State<ActiveRentalListScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() =>
      context.read<RentalViewModel>().loadExtendableRentals(DateHelper.today());

  Future<void> _openExtend(Rental r) async {
    await Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => ExtendRentalScreen(rental: r)));
    if (mounted) await _load();
  }

  List<Rental> _filter(List<Rental> rentals) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return rentals;
    return rentals.where((r) {
      final haystack = [
        r.garageId,
        r.garageType?.label,
        r.tenantName,
        r.vehicleName,
        r.vehicleType?.label,
      ].whereType<String>().join(' ').toLowerCase();
      return haystack.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<RentalViewModel>();
    final active = _filter(vm.activeRentals);
    final upcoming = _filter(vm.upcomingRentals);
    final firstLoad =
        vm.isLoading && vm.activeRentals.isEmpty && vm.upcomingRentals.isEmpty;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Perpanjang Sewa'),
          bottom: TabBar(
            tabAlignment: TabAlignment.fill,
            tabs: [
              _CountTab(label: 'Berjalan', count: active.length),
              _CountTab(label: 'Akan Datang', count: upcoming.length),
            ],
          ),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: TextField(
                controller: _searchCtrl,
                onChanged: (v) => setState(() => _query = v),
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Cari garasi, penyewa, plat',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Hapus pencarian',
                          icon: const Icon(Icons.close, size: 20),
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() => _query = '');
                          },
                        ),
                ),
              ),
            ),
            Expanded(
              child: firstLoad
                  ? const Center(child: CircularProgressIndicator())
                  : TabBarView(
                      children: [
                        _list(
                          rentals: active,
                          upcoming: false,
                          emptyMessage: _query.isEmpty
                              ? 'Tidak ada garasi yang sedang disewa hari ini.'
                              : 'Tidak ada sewa berjalan yang cocok dengan '
                                  '"$_query".',
                          emptyIcon: Icons.event_busy_outlined,
                        ),
                        _list(
                          rentals: upcoming,
                          upcoming: true,
                          emptyMessage: _query.isEmpty
                              ? 'Belum ada sewa yang dipesan untuk tanggal '
                                  'mendatang.'
                              : 'Tidak ada sewa akan datang yang cocok dengan '
                                  '"$_query".',
                          emptyIcon: Icons.event_available_outlined,
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _list({
    required List<Rental> rentals,
    required bool upcoming,
    required String emptyMessage,
    required IconData emptyIcon,
  }) {
    if (rentals.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: LayoutBuilder(
          builder: (context, c) => SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: SizedBox(
              height: c.maxHeight,
              child: EmptyState(message: emptyMessage, icon: emptyIcon),
            ),
          ),
        ),
      );
    }

    Widget card(Rental r) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _RentalCard(rental: r, upcoming: upcoming, onTap: _openExtend),
        );

    final children = <Widget>[];
    if (upcoming) {
      final byMonth = <String, List<Rental>>{};
      for (final r in rentals) {
        final month =
            '${DateHelper.monthName(r.startDate.month)} ${r.startDate.year}';
        byMonth.putIfAbsent(month, () => []).add(r);
      }
      byMonth.forEach((month, list) {
        children.add(_MonthHeader(month: month, count: list.length));
        children.addAll(list.map(card));
      });
    } else {
      children.add(const Padding(
        padding: EdgeInsets.only(bottom: 10),
        child: Text('Diurutkan dari yang paling cepat selesai',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
      ));
      children.addAll(rentals.map(card));
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: children,
      ),
    );
  }
}

class _CountTab extends StatelessWidget {
  const _CountTab({required this.label, required this.count});

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Tab(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(child: Text(label, textAlign: TextAlign.center)),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text('$count',
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary)),
          ),
        ],
      ),
    );
  }
}

class _MonthHeader extends StatelessWidget {
  const _MonthHeader({required this.month, required this.count});

  final String month;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 10),
      child: Row(
        children: [
          const Icon(Icons.calendar_month_outlined,
              size: 18, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(month,
                style:
                    const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          ),
          Text('$count sewa',
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 13)),
        ],
      ),
    );
  }
}

class _RentalCard extends StatelessWidget {
  static BadgeTone _toneFor(int daysLeft) {
    if (daysLeft <= 1) return BadgeTone.danger;
    if (daysLeft <= 3) return BadgeTone.warning;
    return BadgeTone.info;
  }

  const _RentalCard({
    required this.rental,
    required this.upcoming,
    required this.onTap,
  });

  final Rental rental;
  final bool upcoming;
  final ValueChanged<Rental> onTap;

  @override
  Widget build(BuildContext context) {
    final r = rental;
    final today = DateHelper.today();
    final type = r.vehicleType;
    final (iconColor, iconBg) =
        type?.colors ?? (AppColors.primary, AppColors.primaryLight);

    final totalDays = DateHelper.daysInclusive(r.startDate, r.endDate);
    final StatusBadge badge;
    final Widget progress;
    if (upcoming) {
      final startsIn = DateHelper.daysBetween(today, r.startDate);
      badge = StatusBadge(
        label: startsIn == 1 ? 'Mulai besok' : '$startsIn hari lagi',
        tone: BadgeTone.warning,
      );
      progress = _MetaRow(
        icon: Icons.hourglass_top_outlined,
        text: 'Mulai ${DateHelper.display(r.startDate)} • $totalDays hari',
      );
    } else {
      final daysLeft = DateHelper.daysBetween(today, r.endDate);
      final dayNo = DateHelper.daysBetween(r.startDate, today) + 1;
      badge = StatusBadge(
        label: daysLeft == 0 ? 'Hari terakhir' : 'Sisa $daysLeft hari',
        tone: _toneFor(daysLeft),
      );
      progress = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (dayNo / totalDays).clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: AppColors.primaryLight,
              color: daysLeft <= 1 ? AppColors.danger : AppColors.primary,
            ),
          ),
          const SizedBox(height: 6),
          Text('Hari ke-$dayNo dari $totalDays',
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 12)),
        ],
      );
    }

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => onTap(r),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LeadingBox(
                    icon: type?.icon ?? Icons.garage_outlined,
                    color: iconColor,
                    background: iconBg,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  [r.garageId, r.garageType?.label]
                                      .whereType<String>()
                                      .join(' • '),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            badge,
                          ],
                        ),
                        const SizedBox(height: 8),
                        _MetaRow(
                          icon: Icons.person_outline,
                          text: r.tenantName ?? '-',
                        ),
                        _MetaRow(
                          icon: type?.icon ?? Icons.directions_car_outlined,
                          text: [type?.label, r.vehicleName]
                              .whereType<String>()
                              .join(' • '),
                          highlight: type?.label,
                        ),
                        _MetaRow(
                          icon: Icons.event_outlined,
                          text: '${r.rentalType.label}: '
                              '${DateHelper.display(r.startDate)} – '
                              '${DateHelper.display(r.endDate)}',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(child: progress),
                  const SizedBox(width: 12),
                  const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Perpanjang',
                          style: TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700)),
                      Icon(Icons.chevron_right,
                          color: AppColors.primary, size: 20),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.icon, required this.text, this.highlight});

  final IconData icon;
  final String text;
  final String? highlight;

  @override
  Widget build(BuildContext context) {
    const base = TextStyle(color: AppColors.textSecondary, fontSize: 13);
    final h = highlight;
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(icon, size: 15, color: AppColors.textSecondary),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: h != null && text.startsWith(h)
                ? Text.rich(TextSpan(style: base, children: [
                    TextSpan(
                        text: h,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary)),
                    TextSpan(text: text.substring(h.length)),
                  ]))
                : Text(text, style: base),
          ),
        ],
      ),
    );
  }
}
