import 'package:flutter/foundation.dart';

import 'package:sewa_garasi/core/constants/enums.dart';
import 'package:sewa_garasi/core/database/database_helper.dart';
import 'package:sewa_garasi/core/utils/date_helper.dart';
import 'package:sewa_garasi/models/garage.dart';
import 'package:sewa_garasi/repositories/garage_repository.dart';

/// Kelola Garasi: buat garasi, daftar, detail, dan garasi tersedia.
class GarageViewModel extends ChangeNotifier {
  GarageViewModel([GarageRepository? repository])
      : _repository = repository ?? GarageRepository();

  static const int maxGaragePerType = 999;

  final GarageRepository _repository;

  List<Garage> garages = [];
  List<Garage> availableGarages = [];

  Garage? selectedGarage;
  GarageUsage? selectedUsage;
  bool isLoading = false;
  String? errorMessage;

  /// Buat Garasi: bentuk ID, contoh (car, 10) -> "C010".
  String generateGarageId(GarageType type, int number) {
    if (number < 1 || number > maxGaragePerType) {
      throw ArgumentError('Nomor garasi harus 1 - $maxGaragePerType');
    }
    return '${type.idPrefix}${number.toString().padLeft(3, '0')}';
  }

  /// Buat Garasi: susun objek garasi baru (belum disimpan).
  List<Garage> buildGarages({
    required GarageType type,
    required int count,
    required int lastNumber,
    required int dailyPrice,
    int? pricePerKwh,
  }) {
    if (count < 1) throw ArgumentError('Jumlah garasi minimal 1');
    if (lastNumber + count > maxGaragePerType) {
      throw DataException(
          'Kuota ${type.label} tersisa ${maxGaragePerType - lastNumber} garasi');
    }
    if (type == GarageType.electric &&
        (pricePerKwh == null || pricePerKwh <= 0)) {
      throw DataException('Harga isi listrik per kWh wajib diisi');
    }
    return List.generate(count, (i) {
      final id = generateGarageId(type, lastNumber + i + 1);
      return type == GarageType.electric
          ? ElectricGarage(
              id: id, dailyPrice: dailyPrice, pricePerKwh: pricePerKwh!)
          : Garage(id: id, type: type, dailyPrice: dailyPrice);
    });
  }

  /// Buat Garasi: simpan beberapa garasi sekaligus.
  Future<List<String>?> createGarages(
    GarageType type,
    int count,
    int dailyPrice,
    int? pricePerKwh,
  ) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      final last = await _repository.lastNumberByType(type);
      final newGarages = buildGarages(
        type: type,
        count: count,
        lastNumber: last,
        dailyPrice: dailyPrice,
        pricePerKwh: pricePerKwh,
      );
      await _repository.insertAll(newGarages);
      garages = await _repository.findAll();
      return newGarages.map((g) => g.id).toList();
    } on DataException catch (e) {
      errorMessage = e.message;
      return null;
    } catch (e) {
      errorMessage = 'Gagal membuat garasi: $e';
      return null;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// Detail Garasi: muat garasi dan pemakaiannya.
  Future<void> loadGarageDetail(String id) async {
    await _load(() async {
      selectedGarage = await _repository.findById(id);
      selectedUsage = selectedGarage == null
          ? null
          : await _repository.usage(id, DateHelper.today());
    });
    if (selectedGarage == null && errorMessage == null) {
      errorMessage = 'Garasi $id tidak ditemukan';
      notifyListeners();
    }
  }

  /// Buat Garasi: nomor terakhir untuk pratinjau ID.
  Future<int> lastNumber(GarageType type) => _repository.lastNumberByType(type);

  /// Daftar Garasi: muat semua garasi (bisa difilter tipe).
  Future<void> loadAllGarages({GarageType? type}) async {
    await _load(() async => garages = await _repository.findAll(type: type));
  }

  /// Sewa Garasi: garasi kosong selama periode sewa.
  Future<void> loadAvailableGarages(GarageType type,
      {DateTime? start, DateTime? end}) async {
    final from = start ?? DateHelper.today();
    await _load(() async => availableGarages =
        await _repository.findAvailable(type, from, end ?? from));
  }

  void clearAvailable() {
    availableGarages = [];
    notifyListeners();
  }

  Future<void> _load(Future<void> Function() action) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      await action();
    } catch (e) {
      errorMessage = 'Gagal memuat garasi: $e';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}
