import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:sewa_garasi/core/utils/currency_formatter.dart';
import 'package:sewa_garasi/core/utils/date_helper.dart';
import 'package:sewa_garasi/models/rental.dart';
import 'package:sewa_garasi/viewmodels/rental_view_model.dart';
import 'package:sewa_garasi/views/components/empty_state.dart';
import 'package:sewa_garasi/views/components/image_picker_field.dart';
import 'package:sewa_garasi/views/components/info_row.dart';

class RentalDetailScreen extends StatefulWidget {
  const RentalDetailScreen({super.key, required this.rentalId});

  final int rentalId;

  @override
  State<RentalDetailScreen> createState() => _RentalDetailScreenState();
}

class _RentalDetailScreenState extends State<RentalDetailScreen> {
  Rental? _rental;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final vm = context.read<RentalViewModel>();
    final rental = await vm.findRental(widget.rentalId);
    await vm.loadExtensions(widget.rentalId);
    if (!mounted) return;
    setState(() {
      _rental = rental;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final extensions = context.watch<RentalViewModel>().extensions;
    final r = _rental;
    return Scaffold(
      appBar: AppBar(title: const Text('Detail Sewa')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : r == null
              ? const EmptyState(message: 'Data sewa tidak ditemukan')
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  children: [
                    InfoSection(
                        title: 'Garasi & Kendaraan',
                        icon: Icons.garage_outlined,
                        children: [
                          InfoRow(label: 'ID Garasi', value: r.garageId),
                          InfoRow(
                              label: 'Tipe Garasi',
                              value: r.garageType?.label ?? '-'),
                          InfoRow(
                              label: 'Kendaraan', value: r.vehicleName ?? '-'),
                          InfoRow(
                              label: 'Tipe Kendaraan',
                              value: r.vehicleType?.label ?? '-'),
                        ]),
                    InfoSection(
                        title: 'Periode Sewa',
                        icon: Icons.event_outlined,
                        children: [
                          InfoRow(
                              label: 'Tipe Sewa', value: r.rentalType.label),
                          InfoRow(label: 'Lama Sewa', value: '${r.days} hari'),
                          InfoRow(
                              label: 'Mulai',
                              value: DateHelper.display(r.startDate)),
                          InfoRow(
                              label: 'Selesai',
                              value: DateHelper.display(r.endDate)),
                        ]),
                    InfoSection(
                        title: 'Biaya',
                        icon: Icons.payments_outlined,
                        children: [
                          InfoRow(
                              label: 'Harga Harian',
                              value: CurrencyFormatter.rupiah(r.dailyPrice)),
                          InfoRow(
                              label: 'Biaya Sewa',
                              value: CurrencyFormatter.rupiah(r.rentalCost)),
                          if (r.chargedKwh != null) ...[
                            InfoRow(
                                label: 'Sisa Baterai',
                                value: '${r.batteryRemainingKwh} kWh'),
                            InfoRow(
                                label: 'Diisi',
                                value:
                                    '${r.chargedKwh!.toStringAsFixed(2)} kWh x '
                                    '${CurrencyFormatter.rupiah(r.pricePerKwh ?? 0)}'),
                            InfoRow(
                                label: 'Biaya Listrik',
                                value:
                                    CurrencyFormatter.rupiah(r.chargingCost)),
                          ],
                          const Divider(),
                          InfoRow(
                            label: 'Total Dibayar',
                            value: CurrencyFormatter.rupiah(r.totalCost),
                            isBold: true,
                          ),
                        ]),
                    if (extensions.isNotEmpty)
                      InfoSection(
                        title: 'Riwayat Perpanjangan',
                        icon: Icons.event_repeat_outlined,
                        children: extensions
                            .map((e) => InfoRow(
                                  label:
                                      '${DateHelper.display(e.oldEndDate)} → '
                                      '${DateHelper.display(e.newEndDate)}',
                                  value: '+${e.addedDays} hari\n'
                                      '${CurrencyFormatter.rupiah(e.extraCost)}',
                                ))
                            .toList(),
                      ),
                    InfoSection(
                      title: 'Bukti Pelunasan',
                      icon: Icons.receipt_outlined,
                      children: [
                        LocalImage(path: r.paymentProofPath),
                        const SizedBox(height: 6),
                      ],
                    ),
                  ],
                ),
    );
  }
}
