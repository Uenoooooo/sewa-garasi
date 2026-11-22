import 'package:flutter_test/flutter_test.dart';

import 'package:sewa_garasi/core/constants/enums.dart';
import 'package:sewa_garasi/repositories/report_repository.dart';
import 'package:sewa_garasi/viewmodels/report_view_model.dart';

import '../helpers/test_db.dart';

/// Repository palsu yang selalu gagal, untuk menguji pesan error.
class _BrokenReportRepository extends ReportRepository {
  @override
  Future<List<ReportRow>> monthly(int year) => throw Exception('rusak');

  @override
  Future<Map<int, List<int>>> availablePeriods() => throw Exception('rusak');
}

void main() {
  late TestDb db;
  late ReportViewModel vm;

  setUpAll(TestDb.init);
  setUp(() {
    db = TestDb();
    vm = ReportViewModel(db.reports);
  });
  tearDown(() => db.close());

  /// Dua sewa: Budi 2 hari (40.000) dan Ani 3 hari (60.000), mulai hari ini.
  Future<void> seedTwoRentals() async {
    final budi = await db.addTenant(name: 'Budi', n: 1);
    final ani = await db.addTenant(name: 'Ani', n: 2);
    await db.rent(await db.addCar(budi, plate: 'L 1 AA'),
        await db.addCarGarage(id: 'C001'),
        days: 2);
    await db.rent(await db.addCar(ani, plate: 'L 2 BB'),
        await db.addCarGarage(id: 'C002'),
        days: 3);
  }

  group('ReportViewModel periode', () {
    /// Test: Pilihan tahun dan bulan laporan.
    test('tahun dan bulan diambil dari transaksi yang ada', () async {
      // Tanpa transaksi: tidak ada tahun yang bisa dipilih.
      await vm.loadAvailablePeriods();
      expect(vm.availableYears, isEmpty);
      expect(vm.monthsOf(2026), isEmpty);

      await seedTwoRentals();
      await vm.loadAvailablePeriods();
      final today = TestDb.today;
      expect(vm.availableYears, [today.year]);
      expect(vm.monthsOf(today.year), [today.month]);
    });

    /// Test: Urutan bulan di pilihan periode.
    test('monthsOf diurutkan Januari..Desember', () {
      vm.availablePeriods = {
        2026: [11, 3, 7]
      };
      expect(vm.monthsOf(2026), [3, 7, 11]);
    });

    /// Test: Pesan saat periode laporan gagal dimuat.
    test('error saat memuat periode', () async {
      final broken = ReportViewModel(_BrokenReportRepository());
      await broken.loadAvailablePeriods();
      expect(broken.availablePeriods, isEmpty);
      expect(broken.errorMessage, contains('Gagal memuat periode'));
    });
  });

  group('ReportViewModel laporan', () {
    /// Test: Laporan bulanan.
    test('bulanan: satu baris per bulan dan total pendapatan', () async {
      await seedTwoRentals();
      await vm.loadMonthlyReport(TestDb.today.year);
      expect(vm.reportRows, hasLength(1));
      expect(vm.reportRows.first.rentalCount, 2);
      expect(vm.totalRevenue, 100000);
      expect(vm.isLoading, isFalse);

      // Tahun tanpa transaksi menghasilkan daftar kosong.
      await vm.loadMonthlyReport(2000);
      expect(vm.reportRows, isEmpty);
      expect(vm.totalRevenue, 0);
    });

    /// Test: Laporan harian.
    test('harian: dikelompokkan per tanggal mulai', () async {
      await seedTwoRentals();
      final today = TestDb.today;
      await vm.loadDailyReport(today.year, today.month);
      expect(vm.reportRows, hasLength(1));
      expect(vm.totalRevenue, 100000);
    });

    /// Test: Laporan per tipe garasi.
    test('per tipe garasi', () async {
      await seedTwoRentals();
      await vm.loadReportByGarageType();
      expect(vm.reportRows.map((r) => r.label), [GarageType.car.name]);
      expect(vm.totalRevenue, 100000);
    });

    /// Test: Laporan per penyewa.
    test('per penyewa: satu baris per orang', () async {
      await seedTwoRentals();
      await vm.loadReportByTenant();
      expect(vm.reportRows, hasLength(2));
      expect(vm.reportRows.map((r) => r.revenue).toSet(), {40000, 60000});
    });

    /// Test: Pesan saat laporan gagal dimuat.
    test('error saat memuat laporan', () async {
      final broken = ReportViewModel(_BrokenReportRepository());
      await broken.loadMonthlyReport(2026);
      expect(broken.reportRows, isEmpty);
      expect(broken.errorMessage, contains('Gagal memuat laporan'));
      expect(broken.isLoading, isFalse);
    });
  });
}
