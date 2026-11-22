import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:sewa_garasi/core/constants/enums.dart';
import 'package:sewa_garasi/core/database/database_helper.dart';
import 'package:sewa_garasi/core/utils/date_helper.dart';
import 'package:sewa_garasi/models/garage.dart';
import 'package:sewa_garasi/models/user.dart';
import 'package:sewa_garasi/models/vehicle.dart';
import 'package:sewa_garasi/repositories/garage_repository.dart';
import 'package:sewa_garasi/repositories/rental_repository.dart';
import 'package:sewa_garasi/repositories/report_repository.dart';
import 'package:sewa_garasi/repositories/user_repository.dart';
import 'package:sewa_garasi/repositories/vehicle_repository.dart';
import 'package:sewa_garasi/viewmodels/rental_view_model.dart';

/// Unit test akses basis data memakai SQLite in-memory (sqflite_common_ffi),
/// sehingga bisa dijalankan dengan `flutter test` tanpa emulator.
void main() {
  late DatabaseHelper helper;
  late UserRepository userRepo;
  late VehicleRepository vehicleRepo;
  late GarageRepository garageRepo;
  late RentalRepository rentalRepo;
  late ReportRepository reportRepo;
  final rentalVm = RentalViewModel();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() {
    helper = DatabaseHelper.forTesting(inMemoryDatabasePath);
    userRepo = UserRepository(helper);
    vehicleRepo = VehicleRepository(helper);
    garageRepo = GarageRepository(helper);
    rentalRepo = RentalRepository(helper);
    reportRepo = ReportRepository(helper);
  });

  tearDown(() => helper.close());

  /// Membuat penyewa + mobil listrik, mengembalikan kendaraan tersimpan.
  Future<ElectricCar> seedTenantWithEv() async {
    final userId = await userRepo.insert(User(
      nik: '3578012345678901',
      fullName: 'Budi',
      phone: '081234567890',
      email: 'budi@mail.com',
      passwordHash: 'x',
      status: UserStatus.approved,
    ));
    final ev = ElectricCar(
        userId: userId,
        plateNumber: 'L 1 EV',
        brandModel: 'Ioniq 5',
        batteryCapacityKwh: 60);
    final id = await vehicleRepo.insert(ev);
    return Vehicle.fromMap({...ev.toMap(), 'id': id}) as ElectricCar;
  }

  /// Membuat penyewa + mobil biasa, mengembalikan kendaraan tersimpan.
  Future<Car> seedTenantWithCar() async {
    final userId = await userRepo.insert(User(
      nik: '3578012345678902',
      fullName: 'Budi',
      phone: '081234567891',
      email: 'budi.car@mail.com',
      passwordHash: 'x',
      status: UserStatus.approved,
    ));
    final car = Car(userId: userId, plateNumber: 'L 2 CAR', brandModel: 'Jazz');
    final id = await vehicleRepo.insert(car);
    return Vehicle.fromMap({...car.toMap(), 'id': id}) as Car;
  }

  group('Sewa', () {
    /// Test: Sewa baru membuat garasi terpakai.
    test('sewa baru mengubah status garasi menjadi used', () async {
      final ev = await seedTenantWithEv();
      final garage =
          ElectricGarage(id: 'E001', dailyPrice: 30000, pricePerKwh: 2500);
      await garageRepo.insertAll([garage]);

      final rental = rentalVm.buildRental(
        vehicle: ev,
        garage: garage,
        rentalType: RentalType.daily,
        days: 2,
        batteryRemainingKwh: 20,
        paymentProofPath: 'bukti.jpg',
      );
      await rentalRepo.insert(rental);

      final all = await garageRepo.findAll();
      expect(all.single.status, GarageStatus.used);
      expect(
          await garageRepo.findAvailable(
              GarageType.electric, DateHelper.today()),
          isEmpty);
    });

    /// Test: Garasi tersedia lagi setelah masa sewa habis.
    test('garasi kembali tersedia setelah masa sewa habis', () async {
      final car = await seedTenantWithCar();
      final garage =
          Garage(id: 'C001', type: GarageType.car, dailyPrice: 20000);
      await garageRepo.insertAll([garage]);
      final rental = rentalVm.buildRental(
        vehicle: car,
        garage: garage,
        rentalType: RentalType.daily,
        days: 3,
        paymentProofPath: 'x',
        startDate: DateHelper.today().subtract(const Duration(days: 10)),
      );
      await rentalRepo.insert(rental);

      final available =
          await garageRepo.findAvailable(GarageType.car, DateHelper.today());
      expect(available.map((g) => g.id), ['C001']);
      expect(available.single.status, GarageStatus.available);
    });
  });

  group('Pesan di muka', () {
    late Car car;
    final garage = Garage(id: 'C001', type: GarageType.car, dailyPrice: 20000);
    final today = DateHelper.today();

    Future<int> book(DateTime start, {int days = 3}) =>
        rentalRepo.insert(rentalVm.buildRental(
          vehicle: car,
          garage: garage,
          rentalType: RentalType.daily,
          days: days,
          paymentProofPath: 'x',
          startDate: start,
        ));

    setUp(() async {
      car = await seedTenantWithCar();
      await garageRepo.insertAll([garage]);
    });

    /// Test: Pesanan untuk tanggal mendatang belum memakai garasi hari ini.
    test('pesanan di masa depan belum membuat garasi terpakai hari ini',
        () async {
      await book(today.add(const Duration(days: 10)));
      expect(
          (await garageRepo.findAll()).single.status, GarageStatus.available);
      expect(
          await garageRepo.findAvailable(GarageType.car, today), hasLength(1));
    });

    /// Test: Pesanan garasi yang tanggalnya bentrok ditolak.
    test('pesanan beririsan ditolak, yang tidak beririsan diterima', () async {
      await book(today.add(const Duration(days: 10)));
      await expectLater(() => book(today.add(const Duration(days: 12))),
          throwsA(isA<DataException>()));
      expect(await book(today.add(const Duration(days: 13))), isPositive);
    });

    /// Test: Perpanjangan tidak boleh bentrok dengan pesanan berikutnya.
    test('perpanjangan ditolak bila bentrok dengan pesanan berikutnya',
        () async {
      final id = await book(today); // hari ke-0 s/d 2
      await book(today.add(const Duration(days: 5))); // hari ke-5 s/d 7
      final rental = (await rentalRepo.findById(id))!;

      final tooFar = rentalVm.buildExtension(
        rental: rental,
        newEndDate: today.add(const Duration(days: 5)),
        adminId: 1,
        paymentProofPath: 'y',
      );
      await expectLater(() => rentalRepo.insertExtension(tooFar),
          throwsA(isA<DataException>()));

      final ok = rentalVm.buildExtension(
        rental: rental,
        newEndDate: today.add(const Duration(days: 4)),
        adminId: 1,
        paymentProofPath: 'y',
      );
      await rentalRepo.insertExtension(ok);
      expect((await rentalRepo.findById(id))!.endDate,
          today.add(const Duration(days: 4)));
    });
  });

  group('Detail garasi', () {
    /// Test: Ringkasan pemakaian satu garasi.
    test('ringkasan pemakaian garasi', () async {
      final car = await seedTenantWithCar();
      final garage =
          Garage(id: 'C001', type: GarageType.car, dailyPrice: 20000);
      await garageRepo.insertAll([garage]);
      final today = DateHelper.today();
      await rentalRepo.insert(rentalVm.buildRental(
          vehicle: car,
          garage: garage,
          rentalType: RentalType.daily,
          days: 2,
          paymentProofPath: 'x'));
      await rentalRepo.insert(rentalVm.buildRental(
          vehicle: car,
          garage: garage,
          rentalType: RentalType.daily,
          days: 2,
          startDate: today.add(const Duration(days: 10)),
          paymentProofPath: 'x'));

      final usage = await garageRepo.usage('C001', today);
      expect(usage.totalRentals, 2);
      expect(usage.upcomingRentals, 1);
      expect(usage.isRentedNow, isTrue);
      expect(usage.currentTenant, 'Budi');
      expect(usage.currentEndDate, today.add(const Duration(days: 1)));
    });
  });

  group('Laporan', () {
    /// Test: Pendapatan laporan = sewa + perpanjangan.
    test('pendapatan menjumlahkan sewa dan perpanjangan', () async {
      final car = await seedTenantWithCar();
      final garage =
          Garage(id: 'C001', type: GarageType.car, dailyPrice: 20000);
      await garageRepo.insertAll([garage]);
      final id = await rentalRepo.insert(rentalVm.buildRental(
          vehicle: car,
          garage: garage,
          rentalType: RentalType.daily,
          days: 3,
          paymentProofPath: 'x'));
      final rental = (await rentalRepo.findById(id))!;
      await rentalRepo.insertExtension(rentalVm.buildExtension(
        rental: rental,
        newEndDate: rental.endDate.add(const Duration(days: 1)),
        adminId: 1,
        paymentProofPath: 'y',
      ));

      final byType = await reportRepo.byGarageType();
      expect(byType.single.label, 'car');
      expect(byType.single.rentalCount, 1);
      expect(byType.single.extensionCount, 1);
      expect(byType.single.revenue, 80000);
      expect(byType.single.rentalRevenue, 60000);
      expect(byType.single.extensionRevenue, 20000);

      final monthly = await reportRepo.monthly(DateTime.now().year);
      expect(monthly.fold<int>(0, (s, r) => s + r.revenue), 80000);

      final byTenant = await reportRepo.byTenant();
      expect(byTenant.single.label, contains('Budi'));
    });

    /// Test: Pilihan periode laporan hanya bulan yang ada transaksi.
    test('periode tersedia hanya bulan yang ada transaksinya', () async {
      expect(await reportRepo.availablePeriods(), isEmpty);

      final car = await seedTenantWithCar();
      final garage =
          Garage(id: 'C001', type: GarageType.car, dailyPrice: 20000);
      await garageRepo.insertAll([garage]);
      final today = DateHelper.today();
      final later = DateTime(today.year, today.month + 3, 1);
      for (final start in [today, later]) {
        await rentalRepo.insert(rentalVm.buildRental(
            vehicle: car,
            garage: garage,
            rentalType: RentalType.daily,
            days: 2,
            startDate: start,
            paymentProofPath: 'x'));
      }

      final periods = await reportRepo.availablePeriods();
      final expected = <int, List<int>>{};
      for (final d in [later, today]) {
        expected.putIfAbsent(d.year, () => []).add(d.month);
      }
      expect(periods, expected);
    });
  });
}
