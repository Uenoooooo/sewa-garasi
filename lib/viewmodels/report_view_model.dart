import 'package:flutter/foundation.dart';

import 'package:sewa_garasi/repositories/report_repository.dart';

/// Laporan: pendapatan bulanan, harian, per tipe garasi, per penyewa.
class ReportViewModel extends ChangeNotifier {
  ReportViewModel([ReportRepository? repository])
      : _repository = repository ?? ReportRepository();

  final ReportRepository _repository;

  List<ReportRow> reportRows = [];
  bool isLoading = false;
  String? errorMessage;

  Map<int, List<int>> availablePeriods = {};

  List<int> get availableYears => availablePeriods.keys.toList();

  List<int> monthsOf(int year) => [...?availablePeriods[year]]..sort();

  /// Laporan: pilihan tahun dan bulan yang ada transaksinya.
  Future<void> loadAvailablePeriods() async {
    try {
      availablePeriods = await _repository.availablePeriods();
    } catch (e) {
      availablePeriods = {};
      errorMessage = 'Gagal memuat periode laporan: $e';
    }
    notifyListeners();
  }

  /// Laporan: total pendapatan yang ditampilkan.
  int get totalRevenue => reportRows.fold(0, (sum, r) => sum + r.revenue);

  Future<void> loadMonthlyReport(int year) =>
      _load(() => _repository.monthly(year));

  Future<void> loadDailyReport(int year, int month) =>
      _load(() => _repository.daily(year, month));

  Future<void> loadReportByGarageType() => _load(_repository.byGarageType);

  Future<void> loadReportByTenant() => _load(_repository.byTenant);

  Future<void> _load(Future<List<ReportRow>> Function() query) async {
    isLoading = true;
    errorMessage = null;
    reportRows = [];
    notifyListeners();
    try {
      reportRows = await query();
    } catch (e) {
      errorMessage = 'Gagal memuat laporan: $e';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}
