import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:sewa_garasi/app.dart';
import 'package:sewa_garasi/core/constants/enums.dart';
import 'package:sewa_garasi/core/utils/currency_formatter.dart';
import 'package:sewa_garasi/core/utils/validators.dart';
import 'package:sewa_garasi/models/garage.dart';
import 'package:sewa_garasi/viewmodels/garage_view_model.dart';
import 'package:sewa_garasi/views/components/app_card.dart';
import 'package:sewa_garasi/views/components/app_text_field.dart';
import 'package:sewa_garasi/views/components/info_row.dart';
import 'package:sewa_garasi/views/components/primary_button.dart';

class CreateGarageScreen extends StatefulWidget {
  const CreateGarageScreen({super.key});

  @override
  State<CreateGarageScreen> createState() => _CreateGarageScreenState();
}

class _CreateGarageScreenState extends State<CreateGarageScreen> {
  final _formKey = GlobalKey<FormState>();
  final _countCtrl = TextEditingController(text: '1');
  final _priceCtrl = TextEditingController();
  final _kwhCtrl = TextEditingController();
  GarageType? _type;
  int? _lastNumber;

  @override
  void dispose() {
    _countCtrl.dispose();
    _priceCtrl.dispose();
    _kwhCtrl.dispose();
    super.dispose();
  }

  Future<void> _onTypeChanged(GarageType? type) async {
    setState(() {
      _type = type;
      _lastNumber = null;
    });
    if (type == null) return;
    final last = await context.read<GarageViewModel>().lastNumber(type);
    if (mounted) setState(() => _lastNumber = last);
  }

  String? _idPreview(GarageViewModel vm) {
    final count = int.tryParse(_countCtrl.text);
    if (_type == null || _lastNumber == null || count == null || count < 1) {
      return null;
    }
    final from = _lastNumber! + 1;
    final to = _lastNumber! + count;
    if (to > GarageViewModel.maxGaragePerType) {
      return 'Melebihi batas 999 garasi (sisa '
          '${GarageViewModel.maxGaragePerType - _lastNumber!})';
    }
    final first = vm.generateGarageId(_type!, from);
    return count == 1 ? first : '$first s/d ${vm.generateGarageId(_type!, to)}';
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final vm = context.read<GarageViewModel>();
    final ids = await vm.createGarages(
      _type!,
      int.parse(_countCtrl.text),
      int.parse(_priceCtrl.text),
      _type == GarageType.electric ? int.parse(_kwhCtrl.text) : null,
    );
    if (!mounted) return;
    if (ids == null) {
      showMessage(context, vm.errorMessage ?? 'Gagal membuat garasi',
          isError: true);
      return;
    }
    showMessage(
        context, '${ids.length} garasi dibuat (${ids.first} - ${ids.last})');
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<GarageViewModel>();
    final isLoading = vm.isLoading;
    final daily = int.tryParse(_priceCtrl.text);
    final preview = _idPreview(vm);
    return Scaffold(
      appBar: AppBar(title: const Text('Buat Garasi')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FormSection(children: [
                AppDropdownField<GarageType>(
                  label: 'Tipe Garasi',
                  items: GarageType.values,
                  itemLabel: (t) => t.label,
                  value: _type,
                  onChanged: _onTypeChanged,
                  validator: (v) => v == null ? 'Pilih tipe garasi' : null,
                ),
                AppTextField(
                  label: 'Jumlah Garasi (maks. 999)',
                  controller: _countCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: Validators.garageCount,
                  onChanged: (_) => setState(() {}),
                ),
                AppTextField(
                  label: 'Harga Sewa Harian (Rp)',
                  controller: _priceCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: (v) => Validators.positiveInt(v, 'Harga sewa'),
                  onChanged: (_) => setState(() {}),
                ),
                if (_type == GarageType.electric)
                  AppTextField(
                    label: 'Harga Isi Listrik per kWh (Rp)',
                    controller: _kwhCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (v) =>
                        Validators.positiveInt(v, 'Harga per kWh'),
                  ),
              ]),
              NoticeCard(
                icon: Icons.visibility_outlined,
                title: 'Pratinjau',
                child: Column(children: [
                  InfoRow(label: 'ID garasi', value: preview ?? '-'),
                  InfoRow(
                    label: 'Harga bulanan (25 x harian)',
                    value: daily == null
                        ? '-'
                        : CurrencyFormatter.rupiah(
                            daily * Garage.monthlyMultiplier),
                  ),
                ]),
              ),
              const SizedBox(height: 20),
              PrimaryButton(
                label: 'Simpan Garasi',
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
