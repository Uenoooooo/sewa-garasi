import 'package:flutter_test/flutter_test.dart';

import 'package:sewa_garasi/core/constants/enums.dart';
import 'package:sewa_garasi/core/database/database_helper.dart';
import 'package:sewa_garasi/models/user.dart';
import 'package:sewa_garasi/models/vehicle.dart';
import 'package:sewa_garasi/repositories/report_repository.dart';

import '../helpers/test_db.dart';

/// Test tambahan untuk repository: bagian yang belum tercakup di
/// repositories_test.dart.
void main() {
  late TestDb db;

  setUpAll(TestDb.init);
  setUp(() => db = TestDb());
  tearDown(() => db.close());

  group('UserRepository', () {
    /// Test: NIK yang sudah terdaftar tidak bisa dipakai lagi.
    test('NIK ganda ditolak', () async {
      await db.addTenant(n: 1);
      final sameNik = User(
          nik: '3578012345678901',
          fullName: 'Lain',
          phone: '089999999999',
          email: 'lain@mail.com');
      await expectLater(
          db.users.insert(sameNik), throwsA(isA<DataException>()));
    });

    /// Test: Cari akun lewat email dan ubah status verifikasi.
    test('findByEmail tidak peka huruf besar/kecil, updateStatus', () async {
      await db.addTenant(n: 1);
      expect(await db.users.findByEmail('  PENYEWA01@Mail.com '), isNotNull);

      final id = await db.users.insert(User(
          nik: '1234567890123456',
          fullName: 'Ani',
          phone: '0811',
          email: 'ani@mail.com'));
      expect(await db.users.findPendingTenants(), hasLength(1));

      await db.users.updateStatus(id, UserStatus.approved);

      expect(await db.users.findPendingTenants(), isEmpty);
      expect((await db.users.findByEmail('ani@mail.com'))!.status,
          UserStatus.approved);
    });
  });

  group('VehicleRepository', () {
    /// Test: Daftar kendaraan penyewa, terbaru di atas.
    test('findByUser: subclass benar dan terbaru di atas', () async {
      final budi = await db.addTenant();
      await db.addVehicle(Bicycle(
          userId: budi,
          brandModel: 'Polygon',
          createdAt: DateTime(2026, 1, 1)));
      await db.addVehicle(ElectricCar(
          userId: budi,
          plateNumber: 'L 2 EV',
          brandModel: 'Ioniq 5',
          batteryCapacityKwh: 60,
          createdAt: DateTime(2026, 2, 1)));

      final list = await db.vehicles.findByUser(budi);

      expect(list.first, isA<ElectricCar>());
      expect((list.first as ElectricCar).batteryCapacityKwh, 60);
      expect(list.last, isA<Bicycle>());
      expect(list.last.plateNumber, isNull);
    });
  });

  group('RentalRepository', () {
    /// Test: Data sewa menampilkan nama kendaraan, penyewa, dan tipe.
    test('findByUser: nama kendaraan, penyewa, dan tipe ikut terbaca',
        () async {
      final budi = await db.addTenant(name: 'Budi');
      final car = await db.addCar(budi, plate: 'L 1 AB');
      await db.rent(car, await db.addCarGarage());

      final r = (await db.rentals.findByUser(budi)).single;

      expect(r.vehicleName, 'Jazz (L 1 AB)');
      expect(r.tenantName, 'Budi');
      expect(r.vehicleType, VehicleType.car);
      expect(r.garageType, GarageType.car);
    });
  });

  /// Test: Jumlah transaksi pada baris laporan.
  test('ReportRow: jumlah transaksi dan kolom kosong', () {
    const row =
        ReportRow(label: '11', rentalCount: 3, extensionCount: 2, revenue: 100);
    expect(row.transactionCount, 5); // sewa baru + perpanjangan

    final empty = ReportRow.fromMap({'label': 'car'});
    expect(empty.rentalCount, 0);
    expect(empty.revenue, 0);
  });
}
