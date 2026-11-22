import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:sewa_garasi/models/vehicle.dart';
import 'package:sewa_garasi/viewmodels/auth_view_model.dart';
import 'package:sewa_garasi/viewmodels/vehicle_view_model.dart';
import 'package:sewa_garasi/views/components/app_card.dart';
import 'package:sewa_garasi/views/components/empty_state.dart';
import 'package:sewa_garasi/views/components/status_badge.dart';
import 'package:sewa_garasi/views/components/type_icons.dart';
import 'package:sewa_garasi/views/tenant/vehicle/vehicle_form_screen.dart';

class VehicleListScreen extends StatefulWidget {
  const VehicleListScreen({super.key});

  @override
  State<VehicleListScreen> createState() => _VehicleListScreenState();
}

class _VehicleListScreenState extends State<VehicleListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() {
    final userId = context.read<AuthViewModel>().currentUser!.id!;
    return context.read<VehicleViewModel>().loadVehicles(userId);
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<VehicleViewModel>();
    return Scaffold(
      appBar: AppBar(title: const Text('Kendaraan Saya')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const VehicleFormScreen()));
          if (mounted) await _load();
        },
        icon: const Icon(Icons.add),
        label: const Text('Tambah'),
      ),
      body: _body(vm),
    );
  }

  Widget _body(VehicleViewModel vm) {
    if (vm.vehicles.isEmpty && vm.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (vm.vehicles.isEmpty) {
      return const EmptyState(
          message: 'Belum ada kendaraan terdaftar.\n'
              'Tekan "Tambah" untuk menambahkan.',
          icon: Icons.directions_car_outlined);
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      itemCount: vm.vehicles.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        final v = vm.vehicles[i];
        final parked = vm.parkedVehicleIds.contains(v.id);
        final (color, background) = v.type.colors;
        return AppListCard(
          leading: LeadingBox(
            icon: v.type.icon,
            color: color,
            background: background,
          ),
          title: v.brandModel,
          lines: [_subtitle(v)],
          trailing: StatusBadge(
            label: parked ? 'Di garasi' : 'Bebas',
            tone: parked ? BadgeTone.info : BadgeTone.success,
          ),
        );
      },
    );
  }

  String _subtitle(Vehicle v) {
    final parts = [v.type.label, if (v.plateNumber != null) v.plateNumber!];
    if (v is ElectricCar) parts.add('${v.batteryCapacityKwh} kWh');
    return parts.join(' • ');
  }
}
