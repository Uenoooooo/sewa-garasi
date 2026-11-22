import 'package:flutter/foundation.dart';

import 'package:sewa_garasi/core/constants/enums.dart';
import 'package:sewa_garasi/core/database/database_helper.dart';
import 'package:sewa_garasi/core/utils/date_helper.dart';
import 'package:sewa_garasi/models/garage.dart';
import 'package:sewa_garasi/models/rental.dart';
import 'package:sewa_garasi/models/rental_extension.dart';
import 'package:sewa_garasi/models/vehicle.dart';
import 'package:sewa_garasi/repositories/rental_repository.dart';

/// Sewa & Perpanjangan: hitung biaya, simpan sewa, riwayat, perpanjangan.
class RentalViewModel extends ChangeNotifier {
  RentalViewModel([RentalRepository? repository])
      : _repository = repository ?? RentalRepository();

  final RentalRepository _repository;

  List<Rental> activeRentals = [];

  List<Rental> upcomingRentals = [];
  List<Rental> rentalHistory = [];
  List<RentalExtension> extensions = [];
  bool isLoading = false;
  String? errorMessage;

  /// Sewa Garasi: biaya harian = hari x harga, bulanan = 25 x harga.
  int calculateRentalCost(RentalType type, int days, int dailyPrice,
      {DateTime? startDate}) {
    switch (type) {
      case RentalType.daily:
        final max = startDate == null
            ? DateHelper.maxDailyDaysAnyMonth
            : DateHelper.maxDailyDays(startDate);
        if (days < 1 || days > max) {
          throw ArgumentError('Sewa harian harus 1 - $max hari');
        }
        return days * dailyPrice;
      case RentalType.monthly:
        return Garage.monthlyMultiplier * dailyPrice;
    }
  }

  /// Sewa Garasi Listrik: biaya isi listrik sampai penuh.
  int calculateChargingCost(
      double capacity, double remaining, int pricePerKwh) {
    if (remaining < 0 || remaining > capacity) {
      throw ArgumentError('Sisa baterai harus 0 - $capacity kWh');
    }
    return ((capacity - remaining) * pricePerKwh).round();
  }

  /// Perpanjang Sewa: biaya = tambahan hari x harga harian.
  int calculateExtensionCost(int addedDays, int dailyPrice) {
    if (addedDays < 1) throw ArgumentError('Tambahan hari minimal 1');
    return addedDays * dailyPrice;
  }

  /// Sewa Garasi: susun data sewa lengkap dengan biaya.
  Rental buildRental({
    required Vehicle vehicle,
    required Garage garage,
    required RentalType rentalType,
    int days = 1,
    double? batteryRemainingKwh,
    required String paymentProofPath,
    DateTime? startDate,
  }) {
    if (vehicle.id == null) throw ArgumentError('Kendaraan belum disimpan');
    if (!vehicle.canParkIn(garage.type)) {
      throw DataException(
          '${vehicle.type.label} tidak boleh berada di ${garage.type.label}');
    }

    final start = DateHelper.dateOnly(startDate ?? DateTime.now());
    final end = rentalType == RentalType.daily
        ? DateHelper.dailyEndDate(start, days)
        : DateHelper.monthlyEndDate(start);
    final rentalDays = rentalType == RentalType.daily
        ? days
        : DateHelper.daysInclusive(start, end);
    final rentalCost = calculateRentalCost(rentalType, days, garage.dailyPrice,
        startDate: start);

    double? charged;
    int? pricePerKwh;
    var chargingCost = 0;
    if (vehicle is ElectricCar && garage is ElectricGarage) {
      if (batteryRemainingKwh == null) {
        throw DataException('Sisa baterai wajib diisi untuk garasi listrik');
      }
      charged = vehicle.kwhToFull(batteryRemainingKwh);
      pricePerKwh = garage.pricePerKwh;
      chargingCost = calculateChargingCost(
          vehicle.batteryCapacityKwh, batteryRemainingKwh, pricePerKwh);
    }

    return Rental(
      vehicleId: vehicle.id!,
      garageId: garage.id,
      rentalType: rentalType,
      days: rentalDays,
      startDate: start,
      endDate: end,
      dailyPrice: garage.dailyPrice,
      rentalCost: rentalCost,
      batteryRemainingKwh: charged == null ? null : batteryRemainingKwh,
      chargedKwh: charged,
      pricePerKwh: pricePerKwh,
      chargingCost: chargingCost,
      totalCost: rentalCost + chargingCost,
      paymentProofPath: paymentProofPath,
    );
  }

  /// Perpanjang Sewa: susun data perpanjangan.
  RentalExtension buildExtension({
    required Rental rental,
    required DateTime newEndDate,
    required int adminId,
    required String paymentProofPath,
  }) {
    final newEnd = DateHelper.dateOnly(newEndDate);
    final addedDays = DateHelper.daysBetween(rental.endDate, newEnd);
    if (addedDays < 1) {
      throw DataException('Tanggal selesai baru harus setelah '
          '${DateHelper.display(rental.endDate)}');
    }
    return RentalExtension(
      rentalId: rental.id!,
      adminId: adminId,
      oldEndDate: rental.endDate,
      newEndDate: newEnd,
      addedDays: addedDays,
      dailyPrice: rental.dailyPrice,
      extraCost: calculateExtensionCost(addedDays, rental.dailyPrice),
      paymentProofPath: paymentProofPath,
    );
  }

  /// Sewa Garasi: cek kendaraan bentrok dengan sewa lain.
  Rental? vehicleConflict(
      List<Rental> bookings, int vehicleId, DateTime start, DateTime end) {
    for (final r in bookings) {
      if (r.vehicleId == vehicleId &&
          !r.startDate.isAfter(end) &&
          !r.endDate.isBefore(start)) {
        return r;
      }
    }
    return null;
  }

  /// Sewa Garasi: hari pertama kendaraan bebas.
  DateTime firstFreeDay(List<Rental> bookings, int vehicleId, DateTime from) {
    var day = DateHelper.dateOnly(from);
    while (true) {
      final busy = vehicleConflict(bookings, vehicleId, day, day);
      if (busy == null) return day;
      day = busy.endDate.add(const Duration(days: 1));
    }
  }

  /// Sewa Garasi: jadwal sewa penyewa yang belum selesai.
  Future<List<Rental>> loadBookings(int userId) =>
      _repository.findBookingsByUser(userId, DateHelper.today());

  /// Sewa Garasi: simpan sewa baru.
  Future<bool> createRental(Rental rental) =>
      _run(() async => await _repository.insert(rental));

  /// Perpanjang Sewa: sewa berjalan dan akan datang.
  Future<void> loadExtendableRentals(DateTime date) => _run(() async {
        activeRentals = await _repository.findActive(date);
        upcomingRentals = await _repository.findUpcoming(date);
      });

  /// Riwayat Sewa: muat sewa milik penyewa.
  Future<void> loadRentalHistory(int userId) {
    rentalHistory = [];
    return _run(
        () async => rentalHistory = await _repository.findByUser(userId));
  }

  /// Detail Sewa: muat daftar perpanjangan.
  Future<void> loadExtensions(int rentalId) =>
      _run(() async => extensions = await _repository.findExtensions(rentalId));

  /// Perpanjang Sewa: simpan perpanjangan.
  Future<bool> extendRental(RentalExtension ext) => _run(() async {
        await _repository.insertExtension(ext);
        final today = DateHelper.today();
        activeRentals = await _repository.findActive(today);
        upcomingRentals = await _repository.findUpcoming(today);
      });

  Future<Rental?> findRental(int id) => _repository.findById(id);

  Future<bool> _run(Future<void> Function() action) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      await action();
      return true;
    } on DataException catch (e) {
      errorMessage = e.message;
      return false;
    } catch (e) {
      errorMessage = 'Terjadi kesalahan: $e';
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}
