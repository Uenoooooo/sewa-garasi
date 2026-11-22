import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:sewa_garasi/core/constants/app_colors.dart';
import 'package:sewa_garasi/core/constants/enums.dart';
import 'package:sewa_garasi/core/utils/currency_formatter.dart';
import 'package:sewa_garasi/models/garage.dart';
import 'package:sewa_garasi/viewmodels/garage_view_model.dart';
import 'package:sewa_garasi/views/admin/garage/create_garage_screen.dart';
import 'package:sewa_garasi/views/admin/garage/garage_detail_screen.dart';
import 'package:sewa_garasi/views/components/app_card.dart';
import 'package:sewa_garasi/views/components/empty_state.dart';
import 'package:sewa_garasi/views/components/status_badge.dart';

class GarageListScreen extends StatefulWidget {
  const GarageListScreen({super.key});

  @override
  State<GarageListScreen> createState() => _GarageListScreenState();
}

class _GarageListScreenState extends State<GarageListScreen> {
  GarageType? _filter;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() =>
      context.read<GarageViewModel>().loadAllGarages(type: _filter);

  Future<void> _openCreate() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const CreateGarageScreen()),
    );
    if (mounted) await _load();
  }

  Future<void> _openDetail(Garage garage) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
          builder: (_) => GarageDetailScreen(garageId: garage.id)),
    );
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<GarageViewModel>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Daftar Garasi'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton.icon(
              onPressed: _openCreate,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Tambah'),
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 38),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                visualDensity: VisualDensity.compact,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Row(
              children: [
                _chip('Semua', null),
                for (final t in GarageType.values) _chip(t.label, t),
              ],
            ),
          ),
          Expanded(child: _body(vm)),
        ],
      ),
    );
  }

  Widget _body(GarageViewModel vm) {
    if (vm.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (vm.garages.isEmpty) {
      return const EmptyState(
          message: 'Belum ada garasi.\nTekan "Tambah" di kanan atas.',
          icon: Icons.garage_outlined);
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        itemCount: vm.garages.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) => _GarageTile(
          vm.garages[i],
          onTap: () => _openDetail(vm.garages[i]),
        ),
      ),
    );
  }

  Widget _chip(String label, GarageType? type) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          label: Text(label),
          selected: _filter == type,
          onSelected: (_) {
            setState(() => _filter = type);
            _load();
          },
        ),
      );
}

class _GarageTile extends StatelessWidget {
  const _GarageTile(this.garage, {required this.onTap});

  final Garage garage;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final g = garage;
    final kwh = g.pricePerKwh;
    return AppListCard(
      onTap: onTap,
      leading: LeadingBox(
        text: g.type.idPrefix,
        color: g.isAvailable ? AppColors.primary : AppColors.warning,
        background:
            g.isAvailable ? AppColors.primaryLight : AppColors.warningLight,
      ),
      title: g.id,
      lines: [
        g.type.label,
        if (kwh != null) 'Listrik ${CurrencyFormatter.rupiah(kwh)}/kWh',
      ],
      trailing: StatusBadge(
        label: g.status.label,
        tone: g.isAvailable ? BadgeTone.success : BadgeTone.warning,
      ),
      footer: Row(
        children: [
          Expanded(
              child: _Price('Harian', CurrencyFormatter.rupiah(g.dailyPrice))),
          Expanded(
              child: _Price(
                  'Bulanan', CurrencyFormatter.rupiah(g.monthlyPrice()))),
        ],
      ),
    );
  }
}

class _Price extends StatelessWidget {
  const _Price(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style:
                const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
      ],
    );
  }
}
