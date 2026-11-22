import 'package:flutter/foundation.dart';

import 'package:sewa_garasi/core/database/database_helper.dart';
import 'package:sewa_garasi/core/utils/date_helper.dart';
import 'package:sewa_garasi/models/vehicle.dart';
import 'package:sewa_garasi/repositories/vehicle_repository.dart';

/// Kendaraan Penyewa: daftar dan tambah kendaraan.
class VehicleViewModel extends ChangeNotifier {
  VehicleViewModel([VehicleRepository? repository])
      : _repository = repository ?? VehicleRepository();

  final VehicleRepository _repository;

  List<Vehicle> vehicles = [];

  Set<int> parkedVehicleIds = {};
  bool isLoading = false;
  String? errorMessage;

  /// Daftar Kendaraan: muat kendaraan dan yang sedang parkir.
  Future<void> loadVehicles(int userId) async {
    vehicles = [];
    parkedVehicleIds = {};
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      vehicles = await _repository.findByUser(userId);
      parkedVehicleIds = await _repository.findParkedVehicleIds(
          userId, DateHelper.toDb(DateHelper.today()));
    } catch (e) {
      errorMessage = 'Gagal memuat kendaraan: $e';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// Tambah Kendaraan: simpan kendaraan baru.
  Future<Vehicle?> addVehicle(Vehicle vehicle) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      final id = await _repository.insert(vehicle);
      final saved = Vehicle.fromMap({...vehicle.toMap(), 'id': id});
      vehicles = [saved, ...vehicles];
      return saved;
    } on DataException catch (e) {
      errorMessage = e.message;
      return null;
    } catch (e) {
      errorMessage = 'Gagal menyimpan kendaraan: $e';
      return null;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}
