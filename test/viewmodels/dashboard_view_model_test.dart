import 'package:flutter_test/flutter_test.dart';

import 'package:sewa_garasi/core/constants/enums.dart';
import 'package:sewa_garasi/repositories/garage_repository.dart';
import 'package:sewa_garasi/viewmodels/dashboard_view_model.dart';

import '../helpers/test_db.dart';

/// Repository palsu yang selalu gagal, untuk menguji pesan error.
class _BrokenGarageRepository extends GarageRepository {
  @override
  Future<List<GarageAvailability>> availabilityByType(DateTime date) =>
      throw Exception('rusak');
}

void main() {
  late TestDb db;
  late DashboardViewModel vm;

  setUpAll(TestDb.init);
  setUp(() {
    db = TestDb();
    vm = DashboardViewModel(db.garages, db.rentals);
  });
  tearDown(() => db.close());

  /// Test: Persentase garasi terisi (okupansi) di dashboard admin.
  test('okupansi: belum ada garasi = 0, 1 dari 4 terisi = 25%', () async {
    // Tanpa garasi tidak terjadi pembagian nol.
    await vm.loadAdminSummary();
    expect(vm.totalGarages, 0);
    expect(vm.occupancyRate, 0);

    final car = await db.addCar(await db.addTenant());
    final c1 = await db.addCarGarage(id: 'C001');
    await db.addCarGarage(id: 'C002');
    await db.addCarGarage(id: 'C003');
    await db.addElectricGarage();
    await db.rent(car, c1);

    await vm.loadAdminSummary();

    expect(vm.totalGarages, 4);
    expect(vm.usedGarages, 1);
    expect(vm.occupancyRate, 0.25);
  });

  /// Test: Daftar sewa yang segera berakhir (7 hari).
  test('sewa segera berakhir: dalam 7 hari dan sudah mulai', () async {
    final budi = await db.addTenant();
    final soon = await db.addCar(budi, plate: 'L 1 AA');
    final later = await db.addCar(budi, plate: 'L 2 BB');
    final notStarted = await db.addCar(budi, plate: 'L 3 CC');
    await db.rent(soon, await db.addCarGarage(id: 'C001'), days: 3);
    await db.rent(later, await db.addCarGarage(id: 'C002'), days: 20);
    // Pesanan yang belum mulai tidak ikut.
    await db.rent(notStarted, await db.addCarGarage(id: 'C003'),
        start: TestDb.today.add(const Duration(days: 2)), days: 1);

    await vm.loadAdminSummary();

    expect(vm.endingSoon.map((r) => r.garageId), ['C001']);
  });

  group('DashboardViewModel beranda penyewa', () {
    /// Test: Ketersediaan garasi dan harga termurah di beranda penyewa.
    test('ketersediaan per tipe garasi dan harga termurah', () async {
      await db.addCarGarage(id: 'C001', price: 25000);
      await db.addCarGarage(id: 'C002', price: 20000);

      await vm.loadGarageAvailability();

      final car = vm.availability.firstWhere((a) => a.type == GarageType.car);
      expect(car.available, 2);
      expect(car.total, 2);
      expect(car.minDailyPrice, 20000);

      // Tipe tanpa garasi tetap muncul, tanpa harga.
      final bike =
          vm.availability.firstWhere((a) => a.type == GarageType.bicycle);
      expect(bike.total, 0);
      expect(bike.minDailyPrice, isNull);
      expect(vm.isLoading, isFalse);
    });

    /// Test: Pesan saat ringkasan dashboard gagal dimuat.
    test('error saat memuat ringkasan', () async {
      final broken = DashboardViewModel(_BrokenGarageRepository(), db.rentals);
      await broken.loadGarageAvailability();
      expect(broken.errorMessage, contains('Gagal memuat ringkasan'));
      expect(broken.isLoading, isFalse);
    });
  });
}
