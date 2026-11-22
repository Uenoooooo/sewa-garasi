import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:sewa_garasi/app.dart';
import 'package:sewa_garasi/core/constants/app_colors.dart';
import 'package:sewa_garasi/core/constants/enums.dart';
import 'package:sewa_garasi/core/utils/currency_formatter.dart';
import 'package:sewa_garasi/core/utils/date_helper.dart';
import 'package:sewa_garasi/core/utils/validators.dart';
import 'package:sewa_garasi/models/garage.dart';
import 'package:sewa_garasi/models/rental.dart';
import 'package:sewa_garasi/models/vehicle.dart';
import 'package:sewa_garasi/viewmodels/auth_view_model.dart';
import 'package:sewa_garasi/viewmodels/garage_view_model.dart';
import 'package:sewa_garasi/viewmodels/rental_view_model.dart';
import 'package:sewa_garasi/viewmodels/vehicle_view_model.dart';
import 'package:sewa_garasi/views/components/app_card.dart';
import 'package:sewa_garasi/views/components/app_text_field.dart';
import 'package:sewa_garasi/views/components/image_picker_field.dart';
import 'package:sewa_garasi/views/components/info_row.dart';
import 'package:sewa_garasi/views/components/primary_button.dart';
import 'package:sewa_garasi/views/tenant/vehicle/vehicle_form_screen.dart';

class RentalFormScreen extends StatefulWidget {
  const RentalFormScreen({super.key});

  @override
  State<RentalFormScreen> createState() => _RentalFormScreenState();
}

class _RentalFormScreenState extends State<RentalFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _daysCtrl = TextEditingController(text: '1');
  final _batteryCtrl = TextEditingController();

  DateTime _startDate = DateHelper.today();
  Vehicle? _vehicle;
  GarageType? _garageType;
  RentalType _rentalType = RentalType.daily;
  Garage? _garage;
  String? _proofPath;
  String? _proofError;

  List<Rental> _bookings = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<GarageViewModel>().clearAvailable();
      _loadVehicles();
    });
  }

  @override
  void dispose() {
    _daysCtrl.dispose();
    _batteryCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadVehicles() async {
    final userId = context.read<AuthViewModel>().currentUser!.id!;
    final rentalVm = context.read<RentalViewModel>();
    await context.read<VehicleViewModel>().loadVehicles(userId);
    final bookings = await rentalVm.loadBookings(userId);
    if (mounted) setState(() => _bookings = bookings);
  }

  Rental? get _conflict {
    final id = _vehicle?.id;
    if (id == null) return null;
    return context
        .read<RentalViewModel>()
        .vehicleConflict(_bookings, id, _startDate, _endDate ?? _startDate);
  }

  bool _isFreeOn(DateTime day) {
    final id = _vehicle?.id;
    if (id == null) return true;
    return context
            .read<RentalViewModel>()
            .vehicleConflict(_bookings, id, day, day) ==
        null;
  }

  DateTime _firstFreeDay(DateTime from) {
    final id = _vehicle?.id;
    if (id == null) return from;
    return context.read<RentalViewModel>().firstFreeDay(_bookings, id, from);
  }

  List<Rental> _bookingsOf(Vehicle? v) =>
      _bookings.where((r) => r.vehicleId == v?.id).toList();

  int get _days => int.tryParse(_daysCtrl.text) ?? 0;

  double? get _batteryRemaining =>
      double.tryParse(_batteryCtrl.text.replaceAll(',', '.'));

  bool get _needsCharging =>
      _vehicle is ElectricCar && _garageType == GarageType.electric;

  DateTime? get _endDate {
    if (_rentalType == RentalType.monthly) {
      return DateHelper.monthlyEndDate(_startDate);
    }
    if (Validators.rentalDays(_daysCtrl.text, _startDate) != null) return null;
    return DateHelper.dailyEndDate(_startDate, _days);
  }

  ({int rental, int charging, int total})? _cost(RentalViewModel vm) {
    final g = _garage;
    if (g == null || _endDate == null) return null;
    final rental = vm.calculateRentalCost(_rentalType, _days, g.dailyPrice,
        startDate: _startDate);
    var charging = 0;
    final v = _vehicle;
    if (_needsCharging && v is ElectricCar && g is ElectricGarage) {
      final remaining = _batteryRemaining;
      if (remaining == null ||
          Validators.batteryRemaining(
                  _batteryCtrl.text, v.batteryCapacityKwh) !=
              null) {
        return null;
      }
      charging = vm.calculateChargingCost(
          v.batteryCapacityKwh, remaining, g.pricePerKwh);
    }
    return (rental: rental, charging: charging, total: rental + charging);
  }

  void _onVehicleChanged(Vehicle? v) {
    setState(() {
      _vehicle = v;
      _garage = null;
      _batteryCtrl.clear();
      final allowed = v?.allowedGarageTypes ?? const <GarageType>[];
      _garageType = allowed.length == 1 ? allowed.first : null;
    });
    _loadGarages();
  }

  void _onGarageTypeChanged(GarageType? t) {
    setState(() {
      _garageType = t;
      _garage = null;
    });
    _loadGarages();
  }

  Future<void> _loadGarages() async {
    final vm = context.read<GarageViewModel>();
    final end = _endDate;
    if (_garageType == null || end == null || _conflict != null) {
      vm.clearAvailable();
      if (_garage != null) setState(() => _garage = null);
      return;
    }
    await vm.loadAvailableGarages(_garageType!, start: _startDate, end: end);
    if (!mounted) return;
    final stillFree = vm.availableGarages.any((g) => g.id == _garage?.id);
    if (_garage != null && !stillFree) setState(() => _garage = null);
  }

  void _onRentalTypeChanged(RentalType type) {
    setState(() => _rentalType = type);
    _loadGarages();
  }

  void _onDaysChanged(String _) {
    setState(() {});
    _loadGarages();
  }

  void _setStartDate(DateTime date) {
    setState(() => _startDate = DateHelper.dateOnly(date));
    _formKey.currentState?.validate();
    _loadGarages();
  }

  Future<void> _pickStartDate() async {
    final today = DateHelper.today();
    final last =
        today.add(const Duration(days: DateHelper.maxBookingAheadDays));
    final firstFree = _firstFreeDay(_startDate);
    final canBlockDays = !firstFree.isAfter(last);
    final picked = await showDatePicker(
      context: context,
      initialDate: canBlockDays ? firstFree : _startDate,
      firstDate: today,
      lastDate: last,
      selectableDayPredicate: canBlockDays ? _isFreeOn : null,
      helpText: 'Tanggal Mulai Sewa',
    );
    if (picked != null && mounted) _setStartDate(picked);
  }

  Future<void> _addVehicle() async {
    final saved = await Navigator.of(context).push<Vehicle>(
      MaterialPageRoute(builder: (_) => const VehicleFormScreen()),
    );
    if (!mounted) return;
    await _loadVehicles();
    if (!mounted || saved == null) return;
    final match = context
        .read<VehicleViewModel>()
        .vehicles
        .where((v) => v.id == saved.id);
    if (match.isNotEmpty) _onVehicleChanged(match.first);
  }

  Future<void> _submit() async {
    final valid = _formKey.currentState!.validate();
    setState(() => _proofError =
        _proofPath == null ? 'Bukti pelunasan wajib diupload' : null);
    final conflict = _conflict;
    if (conflict != null) {
      showMessage(
          context,
          'Kendaraan sudah parkir di Garasi ${conflict.garageId} pada '
          '${DateHelper.displayRange(conflict.startDate, conflict.endDate)}',
          isError: true);
      return;
    }
    if (_garage == null) {
      showMessage(context, 'Pilih garasi yang tersedia', isError: true);
      return;
    }
    if (!valid || _proofPath == null) return;

    final vm = context.read<RentalViewModel>();
    try {
      final rental = vm.buildRental(
        vehicle: _vehicle!,
        garage: _garage!,
        rentalType: _rentalType,
        days: _rentalType == RentalType.daily ? _days : 1,
        batteryRemainingKwh: _needsCharging ? _batteryRemaining : null,
        paymentProofPath: _proofPath!,
        startDate: _startDate,
      );
      final ok = await vm.createRental(rental);
      if (!mounted) return;
      if (!ok) {
        showMessage(context, vm.errorMessage ?? 'Gagal menyimpan',
            isError: true);
        await _loadVehicles();
        _loadGarages();
        return;
      }
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Sewa Berhasil'),
          content: Text('Garasi ${rental.garageId} disewa '
              '${DateHelper.display(rental.startDate)} s/d '
              '${DateHelper.display(rental.endDate)} (${rental.days} hari).\n'
              'Total: ${CurrencyFormatter.rupiah(rental.totalCost)}'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
          ],
        ),
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      showMessage(context, '$e', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vehicleVm = context.watch<VehicleViewModel>();
    final garageVm = context.watch<GarageViewModel>();
    final rentalVm = context.watch<RentalViewModel>();
    final isSaving = rentalVm.isLoading;
    final vehicles = vehicleVm.vehicles;
    final conflict = _conflict;
    final selectedVehicle =
        vehicles.where((v) => v.id == _vehicle?.id).firstOrNull;
    final schedule = _bookingsOf(selectedVehicle);
    final end = _endDate;
    final cost = _cost(rentalVm);

    return Scaffold(
      appBar: AppBar(title: const Text('Sewa Garasi Baru')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SectionLabel('Kendaraan', step: 1),
              FormSection(children: [
                AppDropdownField<Vehicle>(
                  label: 'Pilih Kendaraan',
                  items: vehicles,
                  itemLabel: _vehicleLabel,
                  value: selectedVehicle,
                  onChanged: _onVehicleChanged,
                  validator: (v) => v == null ? 'Pilih kendaraan' : null,
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: _addVehicle,
                    icon: const Icon(Icons.add),
                    label: const Text('Tambah kendaraan baru'),
                  ),
                ),
                if (schedule.isNotEmpty) _vehicleSchedule(schedule),
                if (selectedVehicle is ElectricCar)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(children: [
                      const Icon(Icons.battery_charging_full,
                          size: 18, color: AppColors.success),
                      const SizedBox(width: 6),
                      Text(
                          'Kapasitas baterai: ${selectedVehicle.batteryCapacityKwh} kWh',
                          style:
                              const TextStyle(color: AppColors.textSecondary)),
                    ]),
                  ),
              ]),
              const SectionLabel('Detail Sewa', step: 2),
              FormSection(children: [
                AppDropdownField<GarageType>(
                  label: 'Tipe Garasi',
                  items: _vehicle?.allowedGarageTypes ?? const [],
                  itemLabel: (t) => t.label,
                  value: _garageType,
                  enabled: _vehicle != null,
                  onChanged: _onGarageTypeChanged,
                  validator: (v) => v == null ? 'Pilih tipe garasi' : null,
                  helperText: _vehicle is ElectricCar
                      ? 'Mobil listrik hanya bisa di Garasi Mobil Listrik.'
                      : null,
                ),
                SegmentedButton<RentalType>(
                  segments: RentalType.values
                      .map((t) => ButtonSegment(value: t, label: Text(t.label)))
                      .toList(),
                  selected: {_rentalType},
                  onSelectionChanged: (s) => _onRentalTypeChanged(s.first),
                ),
                const SizedBox(height: 16),
                _startDateField(),
                if (_rentalType == RentalType.daily)
                  AppTextField(
                    label: 'Jumlah Hari '
                        '(maks. ${DateHelper.maxDailyDays(_startDate)})',
                    controller: _daysCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (v) => Validators.rentalDays(v, _startDate),
                    onChanged: _onDaysChanged,
                  ),
                _dateBox('Tanggal Selesai', end),
                const SizedBox(height: 12),
                _periodNote(),
                if (conflict != null) ...[
                  const SizedBox(height: 12),
                  _conflictNote(conflict),
                ],
                const SizedBox(height: 16),
              ]),
              SectionLabel(
                'Garasi Tersedia',
                step: 3,
                subtitle: end == null || conflict != null
                    ? null
                    : 'Kosong pada ${DateHelper.display(_startDate)} - '
                        '${DateHelper.display(end)}',
              ),
              _garageChooser(garageVm),
              const SizedBox(height: 20),
              if (_needsCharging && conflict == null) ...[
                const SectionLabel(
                  'Isi Daya Listrik',
                  step: 4,
                  subtitle:
                      'Mobil listrik di garasi listrik wajib diisi sampai penuh.',
                ),
                FormSection(children: [
                  AppTextField(
                    label: 'Sisa Baterai Saat Ini (kWh)',
                    controller: _batteryCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    validator: (v) => Validators.batteryRemaining(
                        v, (_vehicle as ElectricCar).batteryCapacityKwh),
                    onChanged: (_) => setState(() {}),
                  ),
                ]),
              ],
              _costCard(cost),
              const SizedBox(height: 20),
              ImagePickerField(
                label: 'Bukti Pelunasan Biaya',
                imagePath: _proofPath,
                folder: 'payments',
                errorText: _proofError,
                onChanged: (p) => setState(() {
                  _proofPath = p;
                  _proofError = null;
                }),
              ),
              PrimaryButton(
                label: 'Simpan Sewa',
                icon: Icons.check_circle_outline,
                isLoading: isSaving,
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _vehicleLabel(Vehicle v) {
    final label = '${v.type.label} - ${v.displayName}';
    final today = DateHelper.today();
    final parkedNow =
        _bookingsOf(v).where((r) => r.isActiveOn(today)).firstOrNull;
    if (parkedNow == null) return label;
    return '$label · parkir s/d ${DateHelper.shortDate(parkedNow.endDate)}';
  }

  Widget _startDateField() => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: InkWell(
          onTap: _pickStartDate,
          borderRadius: BorderRadius.circular(12),
          child: InputDecorator(
            decoration: const InputDecoration(
              labelText: 'Tanggal Mulai',
              prefixIcon: Icon(Icons.calendar_month_outlined, size: 20),
              suffixIcon: Icon(Icons.expand_more),
            ),
            child: Text(DateHelper.display(_startDate),
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
        ),
      );

  Widget _periodNote() {
    final month =
        '${DateHelper.monthName(_startDate.month)} ${_startDate.year}';
    final daysInMonth = DateHelper.daysInMonth(_startDate);
    final text = _rentalType == RentalType.monthly
        ? 'Sewa bulanan mulai $month berlaku $daysInMonth hari '
            '(sesuai jumlah hari di bulan $month).'
        : 'Sewa harian mulai $month maksimal '
            '${DateHelper.maxDailyDays(_startDate)} hari '
            '($daysInMonth hari - 1).';
    return NoticeCard(
      tone: NoticeTone.neutral,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline,
              size: 18, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          Expanded(
              child: Text(text,
                  style: const TextStyle(fontSize: 13, height: 1.4))),
        ],
      ),
    );
  }

  Widget _dateBox(String label, DateTime? date) => InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          enabled: false,
          filled: true,
          fillColor: AppColors.surfaceMuted,
          prefixIcon: const Icon(Icons.event_outlined, size: 18),
          prefixIconConstraints:
              const BoxConstraints(minWidth: 40, minHeight: 20),
        ),
        child: Text(date == null ? '-' : DateHelper.display(date),
            style: const TextStyle(
                fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
      );

  Widget _vehicleSchedule(List<Rental> bookings) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: NoticeCard(
          tone: NoticeTone.neutral,
          icon: Icons.event_busy_outlined,
          title: 'Jadwal parkir kendaraan ini',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final r in bookings)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                      '${DateHelper.displayRange(r.startDate, r.endDate)}'
                      ' · Garasi ${r.garageId}',
                      style: const TextStyle(fontSize: 13)),
                ),
              const SizedBox(height: 6),
              const Text(
                  'Di tanggal tersebut kendaraan sudah parkir, jadi tidak bisa '
                  'menyewa garasi lain.',
                  style:
                      TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            ],
          ),
        ),
      );

  Widget _conflictNote(Rental conflict) {
    final free = _firstFreeDay(_startDate);
    return NoticeCard(
      tone: NoticeTone.warning,
      icon: Icons.warning_amber_rounded,
      title: 'Sudah ada jadwal parkir',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
              'Kendaraan ini sudah parkir di Garasi ${conflict.garageId} '
              'pada ${DateHelper.displayRange(conflict.startDate, conflict.endDate)}. '
              'Satu kendaraan '
              'hanya bisa parkir di satu garasi pada hari yang sama.',
              style: const TextStyle(fontSize: 13, height: 1.4)),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => _setStartDate(free),
            icon: const Icon(Icons.event_available_outlined, size: 18),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.warning,
              side: const BorderSide(color: AppColors.warning),
              minimumSize: const Size(0, 40),
            ),
            label: Text('Mulai ${DateHelper.display(free)}'),
          ),
        ],
      ),
    );
  }

  Widget _garageChooser(GarageViewModel vm) {
    if (_conflict != null) {
      return const NoticeCard(
        tone: NoticeTone.warning,
        icon: Icons.event_busy_outlined,
        title: 'Periode bentrok',
        child: Text('Ganti tanggal mulai atau jumlah hari agar tidak '
            'bentrok dengan jadwal parkir kendaraan ini.'),
      );
    }
    if (_garageType == null) {
      return const NoticeCard(
        tone: NoticeTone.neutral,
        icon: Icons.touch_app_outlined,
        title: 'Belum ada pilihan',
        child: Text('Pilih kendaraan dan tipe garasi terlebih dahulu.'),
      );
    }
    if (vm.isLoading) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (vm.availableGarages.isEmpty) {
      return const NoticeCard(
        tone: NoticeTone.warning,
        icon: Icons.block_outlined,
        title: 'Garasi penuh',
        child: Text('Tidak ada garasi tersedia untuk tipe ini.'),
      );
    }
    return LayoutBuilder(builder: (context, constraints) {
      const spacing = 10.0;
      final columns = constraints.maxWidth >= 480 ? 4 : 3;
      final width = (constraints.maxWidth - spacing * (columns - 1)) / columns;
      return Wrap(
        spacing: spacing,
        runSpacing: spacing,
        children: vm.availableGarages.map((g) {
          final selected = _garage?.id == g.id;
          final price = _rentalType == RentalType.daily
              ? '${CurrencyFormatter.rupiah(g.dailyPrice)}/hari'
              : '${CurrencyFormatter.rupiah(g.monthlyPrice())}/bln';
          return SizedBox(
            width: width,
            child: Material(
              color: selected ? AppColors.primary : AppColors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                    color: selected ? AppColors.primary : AppColors.border),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => setState(() => _garage = g),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
                  child: Column(
                    children: [
                      Text(g.id,
                          style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                              color: selected
                                  ? Colors.white
                                  : AppColors.textPrimary)),
                      const SizedBox(height: 4),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(price,
                            style: TextStyle(
                                fontSize: 11,
                                color: selected
                                    ? Colors.white.withValues(alpha: 0.85)
                                    : AppColors.textSecondary)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      );
    });
  }

  Widget _costCard(({int rental, int charging, int total})? cost) {
    return NoticeCard(
      icon: Icons.receipt_long_outlined,
      title: 'Rincian Biaya',
      child: cost == null
          ? const Text('Lengkapi data untuk melihat total biaya.',
              style: TextStyle(color: AppColors.textSecondary))
          : Column(
              children: [
                InfoRow(
                  label: _rentalType == RentalType.daily
                      ? 'Sewa $_days hari'
                      : 'Sewa 1 bulan / '
                          '${DateHelper.daysInRentalMonth(_startDate)} hari '
                          '(25 x harian)',
                  value: CurrencyFormatter.rupiah(cost.rental),
                ),
                if (_needsCharging)
                  InfoRow(
                      label: 'Isi listrik',
                      value: CurrencyFormatter.rupiah(cost.charging)),
                const Divider(),
                InfoRow(
                  label: 'Total Biaya',
                  value: CurrencyFormatter.rupiah(cost.total),
                  isBold: true,
                ),
              ],
            ),
    );
  }
}
