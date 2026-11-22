import 'package:flutter/foundation.dart';

import 'package:sewa_garasi/core/utils/date_helper.dart';
import 'package:sewa_garasi/models/rental.dart';
import 'package:sewa_garasi/repositories/garage_repository.dart';
import 'package:sewa_garasi/repositories/rental_repository.dart';

/// Dashboard Admin & Beranda Penyewa: data ringkasan.
class DashboardViewModel extends ChangeNotifier {
  DashboardViewModel([GarageRepository? garages, RentalRepository? rentals])
      : _garages = garages ?? GarageRepository(),
        _rentals = rentals ?? RentalRepository();

  static const int endingSoonDays = 7;

  final GarageRepository _garages;
  final RentalRepository _rentals;

  List<GarageAvailability> availability = [];

  List<Rental> endingSoon = [];

  bool isLoading = false;
  String? errorMessage;

  int get totalGarages => availability.fold(0, (s, a) => s + a.total);
  int get usedGarages =>
      availability.fold(0, (s, a) => s + a.total - a.available);

  /// Dashboard Admin: persentase garasi terisi (0..1).
  double get occupancyRate =>
      totalGarages == 0 ? 0 : usedGarages / totalGarages;

  /// Dashboard Admin: okupansi dan sewa yang segera berakhir.
  Future<void> loadAdminSummary() => _run(() async {
        final today = DateHelper.today();
        availability = await _garages.availabilityByType(today);
        endingSoon = await _rentals.findEndingSoon(today, endingSoonDays);
      });

  /// Beranda Penyewa: ketersediaan garasi per tipe.
  Future<void> loadGarageAvailability() => _run(() async {
        availability = await _garages.availabilityByType(DateHelper.today());
      });

  Future<void> _run(Future<void> Function() action) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      await action();
    } catch (e) {
      errorMessage = 'Gagal memuat ringkasan: $e';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}
