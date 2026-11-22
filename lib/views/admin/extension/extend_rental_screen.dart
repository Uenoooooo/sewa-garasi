import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:sewa_garasi/app.dart';
import 'package:sewa_garasi/core/utils/currency_formatter.dart';
import 'package:sewa_garasi/core/utils/date_helper.dart';
import 'package:sewa_garasi/models/rental.dart';
import 'package:sewa_garasi/viewmodels/auth_view_model.dart';
import 'package:sewa_garasi/viewmodels/rental_view_model.dart';
import 'package:sewa_garasi/views/components/app_card.dart';
import 'package:sewa_garasi/views/components/image_picker_field.dart';
import 'package:sewa_garasi/views/components/info_row.dart';
import 'package:sewa_garasi/views/components/primary_button.dart';

class ExtendRentalScreen extends StatefulWidget {
  const ExtendRentalScreen({super.key, required this.rental});

  final Rental rental;

  @override
  State<ExtendRentalScreen> createState() => _ExtendRentalScreenState();
}

class _ExtendRentalScreenState extends State<ExtendRentalScreen> {
  DateTime? _newEnd;
  String? _proofPath;
  String? _proofError;

  Rental get _rental => widget.rental;

  int get _addedDays =>
      _newEnd == null ? 0 : DateHelper.daysBetween(_rental.endDate, _newEnd!);

  int _extraCost(RentalViewModel vm) => _addedDays < 1
      ? 0
      : vm.calculateExtensionCost(_addedDays, _rental.dailyPrice);

  Future<void> _pickDate() async {
    final first = _rental.endDate.add(const Duration(days: 1));
    final picked = await showDatePicker(
      context: context,
      initialDate: _newEnd ?? first,
      firstDate: first,
      lastDate: _rental.endDate.add(const Duration(days: 365)),
      helpText: 'Tanggal Selesai Sewa Baru',
    );
    if (picked != null) setState(() => _newEnd = picked);
  }

  Future<void> _submit() async {
    setState(() =>
        _proofError = _proofPath == null ? 'Bukti bayar wajib diupload' : null);
    if (_newEnd == null) {
      showMessage(context, 'Pilih tanggal selesai baru', isError: true);
      return;
    }
    if (_proofPath == null) return;

    final vm = context.read<RentalViewModel>();
    final adminId = context.read<AuthViewModel>().currentUser!.id!;
    try {
      final ext = vm.buildExtension(
        rental: _rental,
        newEndDate: _newEnd!,
        adminId: adminId,
        paymentProofPath: _proofPath!,
      );
      final ok = await vm.extendRental(ext);
      if (!mounted) return;
      if (!ok) {
        showMessage(context, vm.errorMessage ?? 'Gagal', isError: true);
        return;
      }
      showMessage(context,
          'Sewa ${_rental.garageId} diperpanjang sampai ${DateHelper.display(ext.newEndDate)}');
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      showMessage(context, '$e', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rentalVm = context.watch<RentalViewModel>();
    final isLoading = rentalVm.isLoading;
    final r = _rental;
    return Scaffold(
      appBar: AppBar(title: Text('Perpanjang ${r.garageId}')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          InfoSection(
              title: 'Data Sewa',
              icon: Icons.receipt_long_outlined,
              children: [
                InfoRow(label: 'Garasi', value: r.garageId),
                InfoRow(label: 'Penyewa', value: r.tenantName ?? '-'),
                InfoRow(label: 'Kendaraan', value: r.vehicleName ?? '-'),
                InfoRow(
                    label: 'Tipe Kendaraan',
                    value: r.vehicleType?.label ?? '-'),
                InfoRow(label: 'Tipe Sewa', value: r.rentalType.label),
                InfoRow(label: 'Mulai', value: DateHelper.display(r.startDate)),
                InfoRow(
                    label: 'Selesai Saat Ini',
                    value: DateHelper.display(r.endDate)),
                InfoRow(
                    label: 'Harga Harian',
                    value: CurrencyFormatter.rupiah(r.dailyPrice)),
              ]),
          const SectionLabel('Tanggal Selesai Sewa Baru'),
          InkWell(
            onTap: _pickDate,
            borderRadius: BorderRadius.circular(12),
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Tanggal selesai baru',
                prefixIcon: Icon(Icons.calendar_month_outlined, size: 20),
                suffixIcon: Icon(Icons.expand_more),
              ),
              isEmpty: _newEnd == null,
              child: Text(
                _newEnd == null ? '' : DateHelper.display(_newEnd!),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(height: 16),
          NoticeCard(
            tone: NoticeTone.warning,
            icon: Icons.payments_outlined,
            title: 'Rincian Perpanjangan',
            child: Column(children: [
              InfoRow(label: 'Tambahan Hari', value: '$_addedDays hari'),
              InfoRow(
                label: 'Sisa Biaya',
                value: CurrencyFormatter.rupiah(_extraCost(rentalVm)),
                isBold: true,
              ),
            ]),
          ),
          const SizedBox(height: 20),
          ImagePickerField(
            label: 'Bukti Bayar',
            imagePath: _proofPath,
            folder: 'payments',
            errorText: _proofError,
            onChanged: (p) => setState(() {
              _proofPath = p;
              _proofError = null;
            }),
          ),
          PrimaryButton(
            label: 'Simpan Perpanjangan',
            icon: Icons.save_outlined,
            isLoading: isLoading,
            onPressed: _submit,
          ),
        ],
      ),
    );
  }
}
