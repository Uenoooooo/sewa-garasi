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

/// Database SQLite di memori untuk unit test, lengkap dengan semua
/// repository dan fungsi pembuat data contoh.
///
/// Pemakaian:
/// ```dart
/// late TestDb db;
/// setUpAll(TestDb.init);
/// setUp(() => db = TestDb());
/// tearDown(() => db.close());
/// ```
class TestDb {
  TestDb() : helper = DatabaseHelper.forTesting(inMemoryDatabasePath) {
    users = UserRepository(helper);
    vehicles = VehicleRepository(helper);
    garages = GarageRepository(helper);
    rentals = RentalRepository(helper);
    reports = ReportRepository(helper);
  }

  /// Dipanggil sekali di `setUpAll`: memakai SQLite versi desktop
  /// sehingga test bisa jalan tanpa emulator.
  static void init() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  final DatabaseHelper helper;
  late final UserRepository users;
  late final VehicleRepository vehicles;
  late final GarageRepository garages;
  late final RentalRepository rentals;
  late final ReportRepository reports;

  Future<void> close() => helper.close();

  static DateTime get today => DateHelper.today();

  /// Penyewa yang sudah diterima admin. [n] membedakan NIK/email/telepon.
  Future<int> addTenant({String name = 'Budi', int n = 1}) {
    final num = n.toString().padLeft(2, '0');
    return users.insert(User(
      nik: '35780123456789$num',
      fullName: name,
      phone: '08123456789$num',
      email: 'penyewa$num@mail.com',
      passwordHash: 'x',
      status: UserStatus.approved,
    ));
  }

  /// Menyimpan [vehicle] dan mengembalikannya dengan id terisi.
  Future<T> addVehicle<T extends Vehicle>(T vehicle) async {
    final id = await vehicles.insert(vehicle);
    return Vehicle.fromMap({...vehicle.toMap(), 'id': id}) as T;
  }

  Future<Car> addCar(int userId, {String plate = 'L 1 AB'}) =>
      addVehicle(Car(userId: userId, plateNumber: plate, brandModel: 'Jazz'));

  Future<ElectricCar> addElectricCar(int userId) => addVehicle(ElectricCar(
      userId: userId,
      plateNumber: 'L 2 EV',
      brandModel: 'Ioniq 5',
      batteryCapacityKwh: 60));

  Future<Garage> addCarGarage({String id = 'C001', int price = 20000}) async {
    final g = Garage(id: id, type: GarageType.car, dailyPrice: price);
    await garages.insertAll([g]);
    return g;
  }

  Future<ElectricGarage> addElectricGarage({String id = 'E001'}) async {
    final g = ElectricGarage(id: id, dailyPrice: 30000, pricePerKwh: 2500);
    await garages.insertAll([g]);
    return g;
  }

  /// Sewa harian [days] hari mulai [start] (default hari ini).
  Future<int> rent(Vehicle vehicle, Garage garage,
      {int days = 2, DateTime? start}) {
    return rentals.insert(RentalViewModel().buildRental(
      vehicle: vehicle,
      garage: garage,
      rentalType: RentalType.daily,
      days: days,
      startDate: start ?? today,
      paymentProofPath: 'bukti.jpg',
    ));
  }
}
