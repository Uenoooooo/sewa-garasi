import 'package:flutter_test/flutter_test.dart';

import 'package:sewa_garasi/core/database/database_helper.dart';
import 'package:sewa_garasi/models/vehicle.dart';
import 'package:sewa_garasi/repositories/vehicle_repository.dart';
import 'package:sewa_garasi/viewmodels/vehicle_view_model.dart';

import '../helpers/test_db.dart';

/// Repository palsu yang selalu gagal, untuk menguji pesan error.
class _BrokenVehicleRepository extends VehicleRepository {
  @override
  Future<List<Vehicle>> findByUser(int userId) => throw Exception('rusak');

  @override
  Future<int> insert(Vehicle vehicle) => throw Exception('rusak');
}

class _DuplicateVehicleRepository extends VehicleRepository {
  @override
  Future<int> insert(Vehicle vehicle) =>
      throw DataException('Plat sudah terdaftar');
}

void main() {
  late TestDb db;
  late VehicleViewModel vm;

  setUpAll(TestDb.init);
  setUp(() {
    db = TestDb();
    vm = VehicleViewModel(db.vehicles);
  });
  tearDown(() => db.close());

  group('VehicleViewModel.loadVehicles', () {
    /// Test: Daftar kendaraan hanya milik penyewa yang login.
    test('memuat semua kendaraan milik penyewa', () async {
      final budi = await db.addTenant(n: 1);
      final ani = await db.addTenant(name: 'Ani', n: 2);
      await db.addCar(budi, plate: 'L 1 AA');
      await db.addElectricCar(budi);
      await db.addCar(ani, plate: 'L 9 ZZ');

      await vm.loadVehicles(budi);

      expect(vm.vehicles, hasLength(2));
      expect(vm.vehicles.every((v) => v.userId == budi), isTrue);
      expect(vm.isLoading, isFalse);
      expect(vm.errorMessage, isNull);
    });

    /// Test: Penanda kendaraan yang sedang parkir.
    test('menandai kendaraan yang sedang parkir hari ini saja', () async {
      final budi = await db.addTenant();
      final parked = await db.addCar(budi, plate: 'L 1 AA');
      final free = await db.addCar(budi, plate: 'L 2 BB');
      final booked = await db.addCar(budi, plate: 'L 3 CC');
      await db.rent(parked, await db.addCarGarage(id: 'C001'));
      // Pesanan untuk tanggal mendatang belum dihitung parkir.
      await db.rent(booked, await db.addCarGarage(id: 'C002'),
          start: TestDb.today.add(const Duration(days: 5)));

      await vm.loadVehicles(budi);

      expect(vm.parkedVehicleIds, {parked.id});
      expect(vm.parkedVehicleIds.contains(free.id), isFalse);
    });

    /// Test: Pesan saat kendaraan gagal dimuat.
    test('error database ditampilkan sebagai pesan', () async {
      final broken = VehicleViewModel(_BrokenVehicleRepository());
      await broken.loadVehicles(1);
      expect(broken.errorMessage, contains('Gagal memuat kendaraan'));
      expect(broken.isLoading, isFalse);
    });
  });

  group('VehicleViewModel.addVehicle', () {
    /// Test: Menambah kendaraan baru.
    test('kendaraan baru tersimpan dan muncul paling atas', () async {
      final budi = await db.addTenant();
      await db.addCar(budi, plate: 'L 1 AA');
      await vm.loadVehicles(budi);

      final saved = await vm.addVehicle(
          Motorcycle(userId: budi, plateNumber: 'L 3 CC', brandModel: 'Vario'));

      expect(saved, isNotNull);
      expect(saved!.id, isNotNull);
      expect(saved, isA<Motorcycle>());
      expect(vm.vehicles.first.id, saved.id);
      expect(await db.vehicles.findByUser(budi), hasLength(2));
    });

    /// Test: Pesan saat kendaraan gagal disimpan.
    test(
        'gagal simpan: pesan DataException apa adanya, error lain diberi awalan',
        () async {
      final duplicate = VehicleViewModel(_DuplicateVehicleRepository());
      expect(
          await duplicate.addVehicle(Bicycle(userId: 1, brandModel: 'Polygon')),
          isNull);
      expect(duplicate.errorMessage, 'Plat sudah terdaftar');

      final broken = VehicleViewModel(_BrokenVehicleRepository());
      expect(await broken.addVehicle(Bicycle(userId: 1, brandModel: 'Polygon')),
          isNull);
      expect(broken.errorMessage, contains('Gagal menyimpan kendaraan'));
    });
  });
}
