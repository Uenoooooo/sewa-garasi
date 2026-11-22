import 'package:flutter_test/flutter_test.dart';

import 'package:sewa_garasi/core/constants/enums.dart';
import 'package:sewa_garasi/core/database/database_helper.dart';
import 'package:sewa_garasi/models/garage.dart';
import 'package:sewa_garasi/models/rental.dart';
import 'package:sewa_garasi/models/vehicle.dart';
import 'package:sewa_garasi/repositories/rental_repository.dart';
import 'package:sewa_garasi/viewmodels/rental_view_model.dart';

import '../helpers/test_db.dart';

/// Repository palsu yang selalu gagal, untuk menguji pesan error.
class _BrokenRentalRepository extends RentalRepository {
  @override
  Future<List<Rental>> findByUser(int userId) => throw Exception('rusak');
}

/// Membuat objek sewa tanpa database, cukup untuk cek jadwal.
Rental _booking(int vehicleId, DateTime start, DateTime end) => Rental(
      vehicleId: vehicleId,
      garageId: 'C001',
      rentalType: RentalType.daily,
      days: end.difference(start).inDays + 1,
      startDate: start,
      endDate: end,
      dailyPrice: 20000,
      rentalCost: 0,
      totalCost: 0,
      paymentProofPath: 'x',
    );

void main() {
  group('RentalViewModel jadwal kendaraan (tanpa database)', () {
    // Contoh jadwal: kendaraan 1 parkir 10-12 Des dan 13-15 Des.
    final d10 = DateTime(2026, 12, 10);
    final d15 = DateTime(2026, 12, 15);
    final d16 = DateTime(2026, 12, 16);
    final bookings = [
      _booking(1, d10, DateTime(2026, 12, 12)),
      _booking(1, DateTime(2026, 12, 13), d15),
    ];
    final vm = RentalViewModel();

    /// Test: Cek jadwal kendaraan bentrok.
    test('vehicleConflict: periode beririsan dengan sewa kendaraan itu', () {
      final c = vm.vehicleConflict(bookings, 1, DateTime(2026, 12, 8), d10);
      expect(c!.startDate, d10);
      // Hari terakhir sewa masih bentrok, sehari setelahnya bebas.
      expect(vm.vehicleConflict(bookings, 1, d15, d15), isNotNull);
      expect(vm.vehicleConflict(bookings, 1, d16, d16), isNull);
      // Kendaraan lain tidak terpengaruh.
      expect(vm.vehicleConflict(bookings, 2, d10, d15), isNull);
    });

    /// Test: Mencari hari pertama kendaraan bebas.
    test('firstFreeDay: hari pertama kendaraan bebas', () {
      final d9 = DateTime(2026, 12, 9);
      expect(vm.firstFreeDay(bookings, 1, d9), d9);
      // Melompati sewa yang bersambung.
      expect(vm.firstFreeDay(bookings, 1, d10), d16);
      // Jam diabaikan, hanya tanggal.
      expect(vm.firstFreeDay([], 1, DateTime(2026, 12, 9, 15, 30)), d9);
    });
  });

  group('RentalViewModel perhitungan biaya', () {
    final vm = RentalViewModel();

    /// Test: Biaya sewa harian dan bulanan.
    test('biaya sewa: harian = hari x harga, bulanan = 25 x harga', () {
      expect(vm.calculateRentalCost(RentalType.daily, 3, 20000), 60000);
      expect(vm.calculateRentalCost(RentalType.monthly, 0, 20000), 500000);
      // Sewa harian maks 30 hari, atau mengikuti bulan mulai.
      expect(() => vm.calculateRentalCost(RentalType.daily, 31, 20000),
          throwsArgumentError);
      final feb = DateTime(2027, 2, 1);
      expect(
          vm.calculateRentalCost(RentalType.daily, 27, 20000, startDate: feb),
          540000);
      expect(
          () => vm.calculateRentalCost(RentalType.daily, 28, 20000,
              startDate: feb),
          throwsArgumentError);
    });

    /// Test: Biaya isi listrik sampai penuh.
    test('biaya isi listrik sampai penuh', () {
      // (60 - 20) kWh x Rp2.500 = Rp100.000
      expect(vm.calculateChargingCost(60, 20, 2500), 100000);
      expect(vm.calculateChargingCost(60, 60, 2500), 0);
      expect(() => vm.calculateChargingCost(60, 61, 2500), throwsArgumentError);
    });

    /// Test: Biaya perpanjangan = tambahan hari × harga harian.
    test('biaya perpanjangan = tambahan hari x harga harian', () {
      expect(vm.calculateExtensionCost(5, 20000), 100000);
    });
  });

  group('RentalViewModel.buildRental', () {
    final vm = RentalViewModel();
    final start = DateTime(2026, 11, 21);
    final ev = ElectricCar(
        id: 1,
        userId: 1,
        plateNumber: 'L 1 A',
        brandModel: 'Ioniq',
        batteryCapacityKwh: 60);
    final car = Car(id: 2, userId: 1, plateNumber: 'L 2 B', brandModel: 'Jazz');
    final eGarage =
        ElectricGarage(id: 'E001', dailyPrice: 30000, pricePerKwh: 2500);
    final cGarage = Garage(id: 'C001', type: GarageType.car, dailyPrice: 20000);
    final sGarage =
        Garage(id: 'S001', type: GarageType.bicycle, dailyPrice: 5000);

    /// Test: Sewa mobil listrik di garasi listrik.
    test('mobil listrik di garasi listrik: sewa + isi daya', () {
      final r = vm.buildRental(
        vehicle: ev,
        garage: eGarage,
        rentalType: RentalType.daily,
        days: 2,
        batteryRemainingKwh: 20,
        paymentProofPath: 'bukti.jpg',
        startDate: start,
      );
      expect(r.rentalCost, 60000);
      expect(r.chargedKwh, 40);
      expect(r.chargingCost, 100000);
      expect(r.totalCost, 160000);
      expect(r.endDate, DateTime(2026, 11, 22));
    });

    /// Test: Sewa mobil listrik di garasi mobil biasa tanpa isi daya.
    test('mobil listrik di garasi mobil: diterima tanpa isi daya', () {
      final r = vm.buildRental(
        vehicle: ev,
        garage: cGarage,
        rentalType: RentalType.daily,
        days: 2,
        paymentProofPath: 'bukti.jpg',
        startDate: start,
      );
      expect(r.garageId, 'C001');
      expect(r.chargedKwh, isNull);
      expect(r.chargingCost, 0);
      expect(r.totalCost, 40000);
    });

    /// Test: Sewa mobil biasa tanpa biaya listrik.
    test('mobil biasa di garasi mobil: tanpa isi daya', () {
      final r = vm.buildRental(
        vehicle: car,
        garage: cGarage,
        rentalType: RentalType.daily,
        days: 1,
        paymentProofPath: 'bukti.jpg',
        startDate: start,
      );
      expect(r.chargingCost, 0);
      expect(r.chargedKwh, isNull);
      expect(r.totalCost, 20000);
    });

    /// Test: Sewa bulanan.
    test('sewa bulanan: biaya 25x, lama mengikuti bulan mulai', () {
      final nov = vm.buildRental(
        vehicle: car,
        garage: cGarage,
        rentalType: RentalType.monthly,
        paymentProofPath: 'bukti.jpg',
        startDate: start,
      );
      expect(nov.totalCost, 500000);
      expect(nov.endDate, DateTime(2026, 12, 20));
      expect(nov.days, 30);

      // Februari 2027: 28 hari, biaya tetap 25x.
      final feb = vm.buildRental(
        vehicle: car,
        garage: cGarage,
        rentalType: RentalType.monthly,
        paymentProofPath: 'bukti.jpg',
        startDate: DateTime(2027, 2, 1),
      );
      expect(feb.endDate, DateTime(2027, 2, 28));
      expect(feb.days, 28);
      expect(feb.totalCost, 500000);
    });

    /// Test: Sewa ditolak bila garasi salah tipe atau sisa baterai kosong.
    test('ditolak: garasi salah tipe atau sisa baterai kosong', () {
      // Mobil di garasi sepeda.
      expect(
        () => vm.buildRental(
            vehicle: car,
            garage: sGarage,
            rentalType: RentalType.daily,
            paymentProofPath: 'x',
            startDate: start),
        throwsA(isA<DataException>()),
      );
      // Garasi listrik tanpa sisa baterai.
      expect(
        () => vm.buildRental(
            vehicle: ev,
            garage: eGarage,
            rentalType: RentalType.daily,
            paymentProofPath: 'x',
            startDate: start),
        throwsA(isA<DataException>()),
      );
    });
  });

  /// Test: Menghitung tambahan hari dan biaya perpanjangan.
  test('RentalViewModel.buildExtension: hitung tambahan hari dan biaya', () {
    final vm = RentalViewModel();
    final rental = Rental(
      id: 10,
      vehicleId: 1,
      garageId: 'C001',
      rentalType: RentalType.daily,
      days: 3,
      startDate: DateTime(2026, 11, 21),
      endDate: DateTime(2026, 11, 23),
      dailyPrice: 20000,
      rentalCost: 60000,
      totalCost: 60000,
      paymentProofPath: 'x',
    );

    final ext = vm.buildExtension(
        rental: rental,
        newEndDate: DateTime(2026, 11, 27),
        adminId: 1,
        paymentProofPath: 'y');
    expect(ext.addedDays, 4);
    expect(ext.extraCost, 80000);
    expect(ext.oldEndDate, DateTime(2026, 11, 23));

    // Tanggal baru tidak boleh sama dengan tanggal lama.
    expect(
      () => vm.buildExtension(
          rental: rental,
          newEndDate: DateTime(2026, 11, 23),
          adminId: 1,
          paymentProofPath: 'y'),
      throwsA(isA<DataException>()),
    );
  });

  group('RentalViewModel dengan database', () {
    late TestDb db;
    late RentalViewModel vm;

    setUpAll(TestDb.init);
    setUp(() {
      db = TestDb();
      vm = RentalViewModel(db.rentals);
    });
    tearDown(() => db.close());

    /// Test: Menyimpan sewa baru.
    test('createRental menyimpan sewa', () async {
      final car = await db.addCar(await db.addTenant());
      final rental = vm.buildRental(
          vehicle: car,
          garage: await db.addCarGarage(),
          rentalType: RentalType.daily,
          days: 3,
          paymentProofPath: 'x');

      expect(await vm.createRental(rental), isTrue);
      expect(vm.errorMessage, isNull);
      expect(vm.isLoading, isFalse);
    });

    /// Test: Sewa ditolak bila garasi terpakai atau kendaraan sudah parkir.
    test('createRental ditolak: garasi sudah dipesan / kendaraan sudah parkir',
        () async {
      final budi = await db.addTenant(n: 1);
      final ani = await db.addTenant(name: 'Ani', n: 2);
      final c1 = await db.addCarGarage(id: 'C001');
      final c2 = await db.addCarGarage(id: 'C002');
      final budiCar = await db.addCar(budi, plate: 'L 1 AA');
      await db.rent(budiCar, c1, days: 3);

      // Mobil Ani ke garasi C001 yang sedang dipakai Budi.
      expect(
          await vm.createRental(vm.buildRental(
              vehicle: await db.addCar(ani, plate: 'L 2 BB'),
              garage: c1,
              rentalType: RentalType.daily,
              days: 1,
              paymentProofPath: 'x')),
          isFalse);
      expect(vm.errorMessage, contains('sudah dipesan'));

      // Mobil Budi yang sedang parkir di C001 dipesankan lagi di C002.
      expect(
          await vm.createRental(vm.buildRental(
              vehicle: budiCar,
              garage: c2,
              rentalType: RentalType.daily,
              days: 1,
              paymentProofPath: 'x')),
          isFalse);
      expect(vm.errorMessage, contains('sudah parkir'));
    });

    /// Test: Jadwal sewa penyewa hanya yang belum selesai.
    test('loadBookings: hanya sewa yang belum selesai', () async {
      final budi = await db.addTenant();
      final car = await db.addCar(budi);
      final today = TestDb.today;
      await db.rent(car, await db.addCarGarage(id: 'C001'),
          start: today.subtract(const Duration(days: 10)), days: 2);
      await db.rent(car, await db.addCarGarage(id: 'C002'), days: 2);

      final list = await vm.loadBookings(budi);

      expect(list.map((r) => r.garageId), ['C002']);
    });

    /// Test: Riwayat sewa penyewa, terbaru di atas.
    test('loadRentalHistory: semua sewa milik penyewa, terbaru di atas',
        () async {
      final budi = await db.addTenant(n: 1);
      final ani = await db.addTenant(name: 'Ani', n: 2);
      final car = await db.addCar(budi, plate: 'L 1 AA');
      final today = TestDb.today;
      await db.rent(car, await db.addCarGarage(id: 'C001'),
          start: today.subtract(const Duration(days: 10)), days: 2);
      await db.rent(car, await db.addCarGarage(id: 'C002'));
      await db.rent(await db.addCar(ani, plate: 'L 2 BB'),
          await db.addCarGarage(id: 'C003'));

      await vm.loadRentalHistory(budi);

      expect(vm.rentalHistory.map((r) => r.garageId), ['C002', 'C001']);
    });

    /// Test: Pesan saat riwayat sewa gagal dimuat.
    test('loadRentalHistory: error database', () async {
      final broken = RentalViewModel(_BrokenRentalRepository());
      await broken.loadRentalHistory(1);
      expect(broken.rentalHistory, isEmpty);
      expect(broken.errorMessage, contains('Terjadi kesalahan'));
    });

    /// Test: Daftar sewa yang bisa diperpanjang.
    test('loadExtendableRentals memisahkan berjalan dan akan datang', () async {
      final budi = await db.addTenant();
      final today = TestDb.today;
      await db.rent(await db.addCar(budi, plate: 'L 1 AA'),
          await db.addCarGarage(id: 'C001'));
      await db.rent(await db.addCar(budi, plate: 'L 2 BB'),
          await db.addCarGarage(id: 'C002'),
          start: today.add(const Duration(days: 4)));

      await vm.loadExtendableRentals(today);

      expect(vm.activeRentals.map((r) => r.garageId), ['C001']);
      expect(vm.upcomingRentals.map((r) => r.garageId), ['C002']);
    });

    /// Test: Admin memperpanjang sewa.
    test('extendRental mencatat perpanjangan dan menggeser tanggal selesai',
        () async {
      expect(await vm.findRental(999), isNull); // id tidak ada

      final car = await db.addCar(await db.addTenant());
      final id = await db.rent(car, await db.addCarGarage(), days: 2);
      final rental = (await vm.findRental(id))!;

      final ext = vm.buildExtension(
          rental: rental,
          newEndDate: rental.endDate.add(const Duration(days: 3)),
          adminId: 1,
          paymentProofPath: 'y');

      expect(await vm.extendRental(ext), isTrue);
      expect((await vm.findRental(id))!.endDate, ext.newEndDate);
      expect(vm.activeRentals.single.endDate, ext.newEndDate);

      await vm.loadExtensions(id);
      expect(vm.extensions, hasLength(1));
      expect(vm.extensions.single.addedDays, 3);
      expect(vm.extensions.single.extraCost, 60000);
    });

    /// Test: Perpanjangan ditolak bila kendaraan sudah dipesan di garasi lain.
    test('extendRental ditolak bila kendaraan sudah parkir di garasi lain',
        () async {
      final car = await db.addCar(await db.addTenant());
      final today = TestDb.today;
      final id = await db.rent(car, await db.addCarGarage(id: 'C001'), days: 2);
      // Kendaraan yang sama sudah dipesan di garasi lain 2 hari kemudian.
      await db.rent(car, await db.addCarGarage(id: 'C002'),
          start: today.add(const Duration(days: 3)), days: 2);
      final rental = (await vm.findRental(id))!;

      final ext = vm.buildExtension(
          rental: rental,
          newEndDate: rental.endDate.add(const Duration(days: 2)),
          adminId: 1,
          paymentProofPath: 'y');

      expect(await vm.extendRental(ext), isFalse);
      expect(vm.errorMessage, contains('sudah parkir'));
    });
  });
}
