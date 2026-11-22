import 'package:flutter_test/flutter_test.dart';

import 'package:sewa_garasi/core/constants/enums.dart';
import 'package:sewa_garasi/models/garage.dart';
import 'package:sewa_garasi/repositories/garage_repository.dart';
import 'package:sewa_garasi/viewmodels/garage_view_model.dart';

import '../helpers/test_db.dart';

/// Repository palsu yang selalu gagal, untuk menguji pesan error.
class _BrokenGarageRepository extends GarageRepository {
  @override
  Future<int> lastNumberByType(GarageType type) => throw Exception('rusak');

  @override
  Future<List<Garage>> findAll({GarageType? type}) => throw Exception('rusak');
}

void main() {
  group('GarageViewModel tanpa database', () {
    final vm = GarageViewModel();

    /// Test: ID garasi = huruf tipe + 3 digit nomor.
    test('generateGarageId: huruf tipe + 3 digit, maks 999', () {
      expect(vm.generateGarageId(GarageType.bicycle, 1), 'S001');
      expect(vm.generateGarageId(GarageType.car, 10), 'C010');
      expect(vm.generateGarageId(GarageType.electric, 999), 'E999');
      expect(
          () => vm.generateGarageId(GarageType.car, 1000), throwsArgumentError);
    });

    /// Test: Membuat beberapa garasi sekaligus.
    test('buildGarages: melanjutkan nomor, listrik jadi ElectricGarage', () {
      final cars = vm.buildGarages(
          type: GarageType.car, count: 3, lastNumber: 9, dailyPrice: 20000);
      expect(cars.map((g) => g.id), ['C010', 'C011', 'C012']);

      final electric = vm.buildGarages(
          type: GarageType.electric,
          count: 2,
          lastNumber: 0,
          dailyPrice: 30000,
          pricePerKwh: 2500);
      expect(electric.first, isA<ElectricGarage>());
      expect(electric.first.pricePerKwh, 2500);
    });
  });

  late TestDb db;
  late GarageViewModel vm;

  setUpAll(TestDb.init);
  setUp(() {
    db = TestDb();
    vm = GarageViewModel(db.garages);
  });
  tearDown(() => db.close());

  group('GarageViewModel.createGarages', () {
    /// Test: Menyimpan garasi baru, nomor berlanjut per tipe.
    test('garasi baru masuk daftar, nomor berlanjut per tipe', () async {
      final ids = await vm.createGarages(GarageType.car, 2, 20000, null);
      expect(ids, ['C001', 'C002']);
      expect(vm.garages.map((g) => g.id), containsAll(['C001', 'C002']));
      expect(await vm.lastNumber(GarageType.car), 2);

      expect(await vm.createGarages(GarageType.car, 1, 20000, null), ['C003']);
      expect(
          await vm.createGarages(GarageType.bicycle, 1, 5000, null), ['S001']);
    });

    /// Test: Pembuatan garasi ditolak bila data tidak valid.
    test('ditolak: listrik tanpa harga kWh dan kuota 999 terlampaui', () async {
      expect(
          await vm.createGarages(GarageType.electric, 1, 30000, null), isNull);
      expect(vm.errorMessage, contains('kWh'));
      expect(vm.isLoading, isFalse);

      await vm.createGarages(GarageType.bicycle, 998, 5000, null);
      expect(await vm.createGarages(GarageType.bicycle, 2, 5000, null), isNull);
      expect(vm.errorMessage, contains('tersisa 1'));
    });

    /// Test: Pesan saat garasi gagal dibuat.
    test('error database diberi awalan "Gagal membuat garasi"', () async {
      final broken = GarageViewModel(_BrokenGarageRepository());
      expect(
          await broken.createGarages(GarageType.car, 1, 20000, null), isNull);
      expect(broken.errorMessage, contains('Gagal membuat garasi'));
    });
  });

  group('GarageViewModel daftar garasi', () {
    /// Test: Filter daftar garasi per tipe.
    test('filter per tipe', () async {
      await db.addCarGarage(id: 'C001');
      await db.addElectricGarage(id: 'E001');

      await vm.loadAllGarages();
      expect(vm.garages, hasLength(2));

      await vm.loadAllGarages(type: GarageType.electric);
      expect(vm.garages.map((g) => g.id), ['E001']);
    });

    /// Test: Pilihan garasi hanya yang tersedia.
    test('garasi tersedia: yang sedang disewa tidak muncul', () async {
      final car = await db.addCar(await db.addTenant());
      final rented = await db.addCarGarage(id: 'C001');
      await db.addCarGarage(id: 'C002');
      await db.rent(car, rented);

      await vm.loadAvailableGarages(GarageType.car);
      expect(vm.availableGarages.map((g) => g.id), ['C002']);

      // clearAvailable mengosongkan pilihan.
      vm.clearAvailable();
      expect(vm.availableGarages, isEmpty);
    });

    /// Test: Ketersediaan garasi untuk tanggal mendatang.
    test('garasi tersedia untuk periode di masa depan', () async {
      final car = await db.addCar(await db.addTenant());
      final garage = await db.addCarGarage(id: 'C001');
      final today = TestDb.today;
      await db.rent(car, garage,
          start: today.add(const Duration(days: 10)), days: 3);

      // Periode sebelum pesanan: garasi masih kosong.
      await vm.loadAvailableGarages(GarageType.car,
          start: today, end: today.add(const Duration(days: 5)));
      expect(vm.availableGarages, hasLength(1));

      // Periode yang beririsan dengan pesanan: garasi tidak tersedia.
      await vm.loadAvailableGarages(GarageType.car,
          start: today.add(const Duration(days: 8)),
          end: today.add(const Duration(days: 11)));
      expect(vm.availableGarages, isEmpty);
    });

    /// Test: Pesan saat daftar garasi gagal dimuat.
    test('error database diberi awalan "Gagal memuat garasi"', () async {
      final broken = GarageViewModel(_BrokenGarageRepository());
      await broken.loadAllGarages();
      expect(broken.errorMessage, contains('Gagal memuat garasi'));
      expect(broken.isLoading, isFalse);
    });
  });

  group('GarageViewModel.loadGarageDetail', () {
    /// Test: Detail garasi beserta pemakaiannya.
    test('memuat garasi beserta pemakaiannya', () async {
      // Garasi yang belum pernah disewa.
      await db.addCarGarage(id: 'C002');
      await vm.loadGarageDetail('C002');
      expect(vm.selectedUsage!.isRentedNow, isFalse);
      expect(vm.selectedUsage!.totalRentals, 0);

      // Garasi yang sedang disewa Budi.
      final car = await db.addCar(await db.addTenant(name: 'Budi'));
      await db.rent(car, await db.addCarGarage(id: 'C001'));
      await vm.loadGarageDetail('C001');

      expect(vm.selectedGarage!.id, 'C001');
      expect(vm.selectedGarage!.status, GarageStatus.used);
      expect(vm.selectedUsage!.isRentedNow, isTrue);
      expect(vm.selectedUsage!.currentTenant, 'Budi');
      expect(vm.selectedUsage!.totalRentals, 1);
    });

    /// Test: Detail garasi yang tidak ada.
    test('ID yang tidak ada menampilkan pesan', () async {
      await vm.loadGarageDetail('C999');
      expect(vm.selectedGarage, isNull);
      expect(vm.selectedUsage, isNull);
      expect(vm.errorMessage, 'Garasi C999 tidak ditemukan');
    });
  });
}
