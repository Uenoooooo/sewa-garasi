import 'package:flutter_test/flutter_test.dart';

import 'package:sewa_garasi/core/constants/enums.dart';
import 'package:sewa_garasi/core/database/database_helper.dart';
import 'package:sewa_garasi/models/garage.dart';
import 'package:sewa_garasi/models/rental.dart';
import 'package:sewa_garasi/models/user.dart';
import 'package:sewa_garasi/models/vehicle.dart';

void main() {
  group('Vehicle', () {
    final bike = Bicycle(userId: 1, brandModel: 'Polygon');
    final moto =
        Motorcycle(userId: 1, plateNumber: 'L 1 A', brandModel: 'Vario');
    final car = Car(userId: 1, plateNumber: 'L 2 B', brandModel: 'Jazz');
    final ev = ElectricCar(
        userId: 1,
        plateNumber: 'L 3 C',
        brandModel: 'Ioniq 5',
        batteryCapacityKwh: 72.6);

    /// Test: Kendaraan hanya boleh parkir di garasi sesuai tipenya.
    test('canParkIn: setiap kendaraan hanya di garasi tipenya', () {
      // Sepeda dan sepeda motor di garasi sepeda.
      expect(bike.allowedGarageTypes, [GarageType.bicycle]);
      expect(moto.canParkIn(GarageType.bicycle), isTrue);
      expect(moto.canParkIn(GarageType.car), isFalse);
      expect(moto.canParkIn(GarageType.electric), isFalse);
      // Mobil di garasi mobil.
      expect(car.allowedGarageTypes, [GarageType.car]);
      // Mobil listrik di garasi mobil atau garasi mobil listrik.
      expect(ev.allowedGarageTypes, [GarageType.car, GarageType.electric]);
      expect(ev.canParkIn(GarageType.car), isTrue);
      expect(ev.canParkIn(GarageType.bicycle), isFalse);
      expect(VehicleType.electricCar.allowedGarageTypes,
          [GarageType.car, GarageType.electric]);
    });

    /// Test: Plat nomor wajib kecuali sepeda, kapasitas baterai hanya untuk mobil listrik.
    test('VehicleType: plat wajib kecuali sepeda, baterai hanya mobil listrik',
        () {
      expect(VehicleType.bicycle.requiresPlate, isFalse);
      expect(VehicleType.motorcycle.requiresPlate, isTrue);
      expect(VehicleType.car.requiresPlate, isTrue);
      expect(VehicleType.electricCar.requiresPlate, isTrue);
      expect(VehicleType.electricCar.hasBattery, isTrue);
      expect(VehicleType.car.hasBattery, isFalse);
    });

    /// Test: Menghitung kebutuhan isi daya sampai penuh.
    test('kwhToFull menghitung kebutuhan isi daya', () {
      expect(ev.kwhToFull(22.6), closeTo(50, 0.0001));
      expect(() => ev.kwhToFull(80), throwsArgumentError);
    });

    /// Test: Kendaraan dibuat dan dibaca ulang dari database sesuai jenisnya.
    test('create, toMap -> fromMap menghasilkan subclass yang benar', () {
      expect(
          Vehicle.create(
              type: VehicleType.bicycle, userId: 1, brandModel: 'Polygon'),
          isA<Bicycle>());
      expect(
          Vehicle.create(
              type: VehicleType.motorcycle,
              userId: 1,
              plateNumber: 'L 1 A',
              brandModel: 'Vario'),
          isA<Motorcycle>());

      final restored = Vehicle.fromMap({...ev.toMap(), 'id': 7});
      expect(restored, isA<ElectricCar>());
      expect((restored as ElectricCar).batteryCapacityKwh, 72.6);
      expect(restored.id, 7);
    });

    /// Test: Nama tampilan kendaraan.
    test('displayName: sepeda tanpa plat, mobil dengan plat', () {
      expect(bike.plateNumber, isNull);
      expect(bike.displayName, 'Polygon');
      final car = Car(userId: 1, plateNumber: 'L 1234 AB', brandModel: 'Jazz');
      expect(car.displayName, 'Jazz (L 1234 AB)');
    });
  });

  group('Garage', () {
    /// Test: Harga sewa bulanan = 25 × harga harian.
    test('harga bulanan = 25 x harga harian', () {
      final g = Garage(id: 'C001', type: GarageType.car, dailyPrice: 20000);
      expect(g.monthlyPrice(), 500000);
    });

    /// Test: Biaya isi listrik di garasi mobil listrik.
    test('biaya isi listrik ElectricGarage', () {
      final g =
          ElectricGarage(id: 'E001', dailyPrice: 30000, pricePerKwh: 2500);
      expect(g.chargingCost(40), 100000);
      expect(g.chargingCost(10.5), 26250);
    });

    /// Test: Garasi listrik dan garasi biasa dibaca ulang dari database.
    test('fromMap: ElectricGarage punya harga per kWh, garasi biasa tidak', () {
      final e =
          ElectricGarage(id: 'E001', dailyPrice: 30000, pricePerKwh: 2500);
      final restored = Garage.fromMap(e.toMap());
      expect(restored, isA<ElectricGarage>());
      expect(restored.pricePerKwh, 2500);

      final s = Garage(id: 'S001', type: GarageType.bicycle, dailyPrice: 5000);
      expect(Garage.fromMap(s.toMap()).pricePerKwh, isNull);
    });

    /// Test: Ketersediaan garasi mengikuti statusnya.
    test('isAvailable mengikuti status', () {
      expect(
          Garage(id: 'C001', type: GarageType.car, dailyPrice: 1).isAvailable,
          isTrue);
      expect(
          Garage(
                  id: 'C001',
                  type: GarageType.car,
                  dailyPrice: 1,
                  status: GarageStatus.used)
              .isAvailable,
          isFalse);
    });
  });

  group('User', () {
    /// Test: Pengguna baru otomatis penyewa berstatus pending.
    test('default penyewa berstatus pending, toMap -> fromMap', () {
      final u = User(
          id: 3,
          nik: '1234567890123456',
          fullName: 'Budi',
          phone: '0812',
          email: 'b@mail.com',
          passwordHash: 'x');
      expect(u.role, UserRole.tenant);
      expect(u.status, UserStatus.pending);
      expect(u.isAdmin(), isFalse);

      final r = User.fromMap(u.toMap());
      expect(r.nik, u.nik);
      expect(r.email, u.email);
      expect(r.status, UserStatus.pending);
    });

    /// Test: Mengubah sebagian data pengguna.
    test('copyWith: hanya field yang diberikan yang berubah', () {
      final u = User(fullName: 'Ani', phone: '0812', email: 'a@mail.com');
      final approved = u.copyWith(id: 5, status: UserStatus.approved);
      expect(approved.id, 5);
      expect(approved.status, UserStatus.approved);
      expect(approved.fullName, 'Ani');
      expect(approved.email, 'a@mail.com');
      expect(u.status, UserStatus.pending); // objek lama tidak berubah
    });
  });

  /// Test: Sewa aktif dari hari mulai sampai hari selesai.
  test('Rental.isActiveOn: aktif dari hari mulai sampai hari selesai', () {
    final rental = Rental(
      vehicleId: 1,
      garageId: 'C001',
      rentalType: RentalType.daily,
      days: 3,
      startDate: DateTime(2026, 12, 10),
      endDate: DateTime(2026, 12, 12),
      dailyPrice: 20000,
      rentalCost: 60000,
      totalCost: 60000,
      paymentProofPath: 'x',
    );
    expect(rental.isActiveOn(DateTime(2026, 12, 9)), isFalse);
    expect(rental.isActiveOn(DateTime(2026, 12, 10)), isTrue);
    // Hari terakhir masih aktif, jam diabaikan.
    expect(rental.isActiveOn(DateTime(2026, 12, 12, 23)), isTrue);
    expect(rental.isActiveOn(DateTime(2026, 12, 13)), isFalse);
  });

  /// Test: Pesan kesalahan data dapat ditampilkan.
  test('DataException.toString berisi pesannya', () {
    expect('${DataException('Garasi penuh')}', 'Garasi penuh');
  });
}
