import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:sewa_garasi/core/constants/app_colors.dart';
import 'package:sewa_garasi/core/utils/currency_formatter.dart';
import 'package:sewa_garasi/core/utils/date_helper.dart';
import 'package:sewa_garasi/models/rental.dart';
import 'package:sewa_garasi/viewmodels/auth_view_model.dart';
import 'package:sewa_garasi/viewmodels/rental_view_model.dart';
import 'package:sewa_garasi/views/components/app_card.dart';
import 'package:sewa_garasi/views/components/empty_state.dart';
import 'package:sewa_garasi/views/components/status_badge.dart';
import 'package:sewa_garasi/views/tenant/rental/rental_detail_screen.dart';

class RentalHistoryScreen extends StatefulWidget {
  const RentalHistoryScreen({super.key});

  @override
  State<RentalHistoryScreen> createState() => _RentalHistoryScreenState();
}

class _RentalHistoryScreenState extends State<RentalHistoryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() {
    final userId = context.read<AuthViewModel>().currentUser!.id!;
    return context.read<RentalViewModel>().loadRentalHistory(userId);
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<RentalViewModel>();
    final rentals = vm.rentalHistory;
    return Scaffold(
      appBar: AppBar(title: const Text('Riwayat Sewa')),
      body: _body(vm.isLoading, rentals),
    );
  }

  Widget _body(bool isLoading, List<Rental> rentals) {
    if (rentals.isEmpty && isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (rentals.isEmpty) {
      return const EmptyState(
          message: 'Belum ada riwayat sewa.', icon: Icons.history);
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: rentals.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) => _RentalCard(rentals[i]),
      ),
    );
  }
}

class _RentalCard extends StatelessWidget {
  const _RentalCard(this.rental);

  final Rental rental;

  @override
  Widget build(BuildContext context) {
    final r = rental;
    final today = DateHelper.today();

    String status;
    BadgeTone tone;
    Color color;
    Color background;
    if (today.isBefore(r.startDate)) {
      status = 'Akan datang';
      tone = BadgeTone.warning;
      color = AppColors.warning;
      background = AppColors.warningLight;
    } else if (!today.isAfter(r.endDate)) {
      status = 'Aktif';
      tone = BadgeTone.success;
      color = AppColors.success;
      background = AppColors.successLight;
    } else {
      status = 'Selesai';
      tone = BadgeTone.info;
      color = AppColors.textSecondary;
      background = AppColors.surfaceMuted;
    }

    return AppListCard(
      leading: LeadingBox(
        text: r.garageId.substring(0, 1),
        color: color,
        background: background,
      ),
      title: '${r.garageId} • ${r.garageType?.label ?? ''}',
      lines: [
        r.vehicleName ?? '-',
        '${r.rentalType.label}: ${DateHelper.display(r.startDate)} - '
            '${DateHelper.display(r.endDate)}',
      ],
      trailing: StatusBadge(label: status, tone: tone),
      footer: Row(
        children: [
          const Text('Total',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          const Spacer(),
          Text(CurrencyFormatter.rupiah(r.totalCost),
              style: const TextStyle(
                  fontWeight: FontWeight.w800, color: AppColors.primary)),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right,
              size: 20, color: AppColors.textSecondary),
        ],
      ),
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => RentalDetailScreen(rentalId: r.id!))),
    );
  }
}
