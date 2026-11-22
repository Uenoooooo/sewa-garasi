import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:sewa_garasi/core/constants/app_colors.dart';
import 'package:sewa_garasi/core/utils/currency_formatter.dart';
import 'package:sewa_garasi/core/utils/date_helper.dart';
import 'package:sewa_garasi/models/garage.dart';
import 'package:sewa_garasi/repositories/garage_repository.dart';
import 'package:sewa_garasi/viewmodels/garage_view_model.dart';
import 'package:sewa_garasi/views/components/app_card.dart';
import 'package:sewa_garasi/views/components/empty_state.dart';
import 'package:sewa_garasi/views/components/info_row.dart';
import 'package:sewa_garasi/views/components/status_badge.dart';
import 'package:sewa_garasi/views/components/type_icons.dart';

class GarageDetailScreen extends StatefulWidget {
  const GarageDetailScreen({super.key, required this.garageId});

  final String garageId;

  @override
  State<GarageDetailScreen> createState() => _GarageDetailScreenState();
}

class _GarageDetailScreenState extends State<GarageDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() =>
      context.read<GarageViewModel>().loadGarageDetail(widget.garageId);

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<GarageViewModel>();
    final garage =
        vm.selectedGarage?.id == widget.garageId ? vm.selectedGarage : null;
    final usage = garage == null ? null : vm.selectedUsage;

    Widget body;
    if (garage == null || usage == null) {
      body = vm.isLoading || vm.errorMessage == null
          ? const Center(child: CircularProgressIndicator())
          : EmptyState(message: vm.errorMessage!, icon: Icons.error_outline);
    } else {
      body = RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          children: [
            _Header(garage: garage, icon: garage.type.icon),
            const SizedBox(height: 14),
            InfoSection(
              title: 'Harga',
              icon: Icons.payments_outlined,
              children: [
                InfoRow(
                    label: 'Harian',
                    value: CurrencyFormatter.rupiah(garage.dailyPrice)),
                InfoRow(
                    label: 'Bulanan',
                    value: CurrencyFormatter.rupiah(garage.monthlyPrice())),
                if (garage.pricePerKwh != null)
                  InfoRow(
                      label: 'Isi listrik',
                      value:
                          '${CurrencyFormatter.rupiah(garage.pricePerKwh!)}/kWh'),
              ],
            ),
            _UsageSection(usage: usage),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text('Garasi ${widget.garageId}')),
      body: body,
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.garage, required this.icon});

  final Garage garage;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final available = garage.isAvailable;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            LeadingBox(
              icon: icon,
              size: 56,
              color: available ? AppColors.primary : AppColors.warning,
              background:
                  available ? AppColors.primaryLight : AppColors.warningLight,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(garage.id,
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text(garage.type.label,
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 14)),
                  const SizedBox(height: 8),
                  StatusBadge(
                    label: garage.status.label,
                    tone: available ? BadgeTone.success : BadgeTone.warning,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UsageSection extends StatelessWidget {
  const _UsageSection({required this.usage});

  final GarageUsage usage;

  @override
  Widget build(BuildContext context) {
    return InfoSection(
      title: 'Pemakaian',
      icon: Icons.event_note_outlined,
      children: [
        if (usage.isRentedNow) ...[
          InfoRow(label: 'Penyewa', value: usage.currentTenant!),
          InfoRow(label: 'Kendaraan', value: usage.currentVehicle ?? '-'),
          InfoRow(
              label: 'Disewa sampai',
              value: DateHelper.display(usage.currentEndDate!)),
        ] else
          const InfoRow(label: 'Hari ini', value: 'Kosong'),
        InfoRow(
            label: 'Akan datang',
            value: usage.upcomingRentals == 0
                ? '-'
                : '${usage.upcomingRentals} sewa'),
        InfoRow(
            label: 'Total disewa',
            value: usage.totalRentals == 0
                ? 'Belum pernah'
                : '${usage.totalRentals} kali'),
      ],
    );
  }
}
