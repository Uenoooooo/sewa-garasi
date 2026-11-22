import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:sewa_garasi/app.dart';
import 'package:sewa_garasi/core/constants/enums.dart';
import 'package:sewa_garasi/core/utils/validators.dart';
import 'package:sewa_garasi/models/vehicle.dart';
import 'package:sewa_garasi/viewmodels/auth_view_model.dart';
import 'package:sewa_garasi/viewmodels/vehicle_view_model.dart';
import 'package:sewa_garasi/views/components/app_card.dart';
import 'package:sewa_garasi/views/components/app_text_field.dart';
import 'package:sewa_garasi/views/components/primary_button.dart';

class VehicleFormScreen extends StatefulWidget {
  const VehicleFormScreen({super.key});

  @override
  State<VehicleFormScreen> createState() => _VehicleFormScreenState();
}

class _VehicleFormScreenState extends State<VehicleFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _plateCtrl = TextEditingController();
  final _brandCtrl = TextEditingController();
  final _batteryCtrl = TextEditingController();
  VehicleType? _type;

  @override
  void dispose() {
    _plateCtrl.dispose();
    _brandCtrl.dispose();
    _batteryCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final userId = context.read<AuthViewModel>().currentUser!.id!;
    final vm = context.read<VehicleViewModel>();
    final type = _type!;

    final vehicle = Vehicle.create(
      type: type,
      userId: userId,
      plateNumber:
          type.requiresPlate ? _plateCtrl.text.trim().toUpperCase() : null,
      brandModel: _brandCtrl.text.trim(),
      batteryCapacityKwh: type.hasBattery
          ? double.parse(_batteryCtrl.text.trim().replaceAll(',', '.'))
          : null,
    );

    final saved = await vm.addVehicle(vehicle);
    if (!mounted) return;
    if (saved == null) {
      showMessage(context, vm.errorMessage ?? 'Gagal menyimpan', isError: true);
      return;
    }
    showMessage(context, 'Kendaraan disimpan');
    Navigator.of(context).pop(saved);
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = context.watch<VehicleViewModel>().isLoading;
    return Scaffold(
      appBar: AppBar(title: const Text('Tambah Kendaraan')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FormSection(children: [
                AppDropdownField<VehicleType>(
                  label: 'Tipe Kendaraan',
                  items: VehicleType.values,
                  itemLabel: (t) => t.label,
                  value: _type,
                  onChanged: (t) => setState(() => _type = t),
                  validator: (v) => v == null ? 'Pilih tipe kendaraan' : null,
                ),
                if (_type?.requiresPlate ?? false)
                  AppTextField(
                    label: 'Nomor Plat',
                    hint: 'L 1234 AB',
                    controller: _plateCtrl,
                    validator: Validators.plateNumber,
                  ),
                AppTextField(
                  label: 'Merek dan Tipe',
                  hint: 'Contoh: Honda Vario 125',
                  controller: _brandCtrl,
                  validator: (v) => Validators.required(v, 'Merek dan tipe'),
                ),
                if (_type?.hasBattery ?? false)
                  AppTextField(
                    label: 'Kapasitas Baterai (kWh)',
                    controller: _batteryCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    validator: (v) =>
                        Validators.positiveDouble(v, 'Kapasitas baterai'),
                  ),
              ]),
              if (_type != null) ...[
                NoticeCard(
                  icon: Icons.info_outline,
                  title: 'Garasi yang bisa dipakai',
                  child: Text(
                      _type!.allowedGarageTypes.map((g) => g.label).join(', ')),
                ),
                const SizedBox(height: 20),
              ],
              PrimaryButton(
                label: 'Simpan Kendaraan',
                icon: Icons.save_outlined,
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
