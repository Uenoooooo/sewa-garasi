import 'package:sewa_garasi/core/constants/enums.dart';

/// Kendaraan Penyewa: kelas induk kendaraan (tabel vehicles).
abstract class Vehicle {
  final int? id;
  final int userId;
  final String? plateNumber;
  final String brandModel;
  final DateTime createdAt;

  Vehicle({
    this.id,
    required this.userId,
    this.plateNumber,
    required this.brandModel,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  VehicleType get type;

  /// Sewa Garasi: cek kendaraan boleh di garasi tipe ini.
  bool canParkIn(GarageType garageType);

  List<GarageType> get allowedGarageTypes =>
      GarageType.values.where(canParkIn).toList();

  /// Tampilan: nama kendaraan, contoh "Jazz (L 1234 AB)".
  String get displayName => plateNumber == null
      ? brandModel
      : '$brandModel (${plateNumber!.replaceAll(' ', '\u00A0')})';

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'user_id': userId,
        'type': type.name,
        'plate_number': plateNumber,
        'brand_model': brandModel,
        'battery_capacity_kwh': null,
        'created_at': createdAt.toIso8601String(),
      };

  /// Tambah Kendaraan: buat objek sesuai tipe kendaraan.
  factory Vehicle.create({
    int? id,
    required VehicleType type,
    required int userId,
    String? plateNumber,
    required String brandModel,
    double? batteryCapacityKwh,
    DateTime? createdAt,
  }) {
    switch (type) {
      case VehicleType.bicycle:
        return Bicycle(
            id: id,
            userId: userId,
            brandModel: brandModel,
            createdAt: createdAt);
      case VehicleType.motorcycle:
        return Motorcycle(
            id: id,
            userId: userId,
            plateNumber: plateNumber!,
            brandModel: brandModel,
            createdAt: createdAt);
      case VehicleType.car:
        return Car(
            id: id,
            userId: userId,
            plateNumber: plateNumber!,
            brandModel: brandModel,
            createdAt: createdAt);
      case VehicleType.electricCar:
        return ElectricCar(
            id: id,
            userId: userId,
            plateNumber: plateNumber!,
            brandModel: brandModel,
            batteryCapacityKwh: batteryCapacityKwh!,
            createdAt: createdAt);
    }
  }

  factory Vehicle.fromMap(Map<String, dynamic> map) => Vehicle.create(
        id: map['id'] as int?,
        type: VehicleType.values.byName(map['type'] as String),
        userId: map['user_id'] as int,
        plateNumber: map['plate_number'] as String?,
        brandModel: map['brand_model'] as String,
        batteryCapacityKwh: (map['battery_capacity_kwh'] as num?)?.toDouble(),
        createdAt: DateTime.parse(map['created_at'] as String),
      );
}

/// Sepeda: tanpa plat, parkir di garasi sepeda.
class Bicycle extends Vehicle {
  Bicycle({
    super.id,
    required super.userId,
    required super.brandModel,
    super.createdAt,
  }) : super(plateNumber: null);

  @override
  VehicleType get type => VehicleType.bicycle;

  @override
  bool canParkIn(GarageType garageType) => garageType == GarageType.bicycle;
}

/// Sepeda Motor: parkir di garasi sepeda.
class Motorcycle extends Vehicle {
  Motorcycle({
    super.id,
    required super.userId,
    required String super.plateNumber,
    required super.brandModel,
    super.createdAt,
  });

  @override
  VehicleType get type => VehicleType.motorcycle;

  @override
  bool canParkIn(GarageType garageType) => garageType == GarageType.bicycle;
}

/// Mobil: parkir di garasi mobil.
class Car extends Vehicle {
  Car({
    super.id,
    required super.userId,
    required String super.plateNumber,
    required super.brandModel,
    super.createdAt,
  });

  @override
  VehicleType get type => VehicleType.car;

  @override
  bool canParkIn(GarageType garageType) => garageType == GarageType.car;
}

/// Mobil Listrik: parkir di garasi listrik.
class ElectricCar extends Vehicle {
  final double batteryCapacityKwh;

  ElectricCar({
    super.id,
    required super.userId,
    required String super.plateNumber,
    required super.brandModel,
    required this.batteryCapacityKwh,
    super.createdAt,
  });

  @override
  VehicleType get type => VehicleType.electricCar;

  @override
  bool canParkIn(GarageType garageType) => garageType == GarageType.electric;

  /// Sewa Garasi Listrik: kWh yang perlu diisi sampai penuh.
  double kwhToFull(double remainingKwh) {
    if (remainingKwh < 0 || remainingKwh > batteryCapacityKwh) {
      throw ArgumentError('Sisa baterai harus 0 - $batteryCapacityKwh kWh');
    }
    return batteryCapacityKwh - remainingKwh;
  }

  @override
  Map<String, dynamic> toMap() =>
      {...super.toMap(), 'battery_capacity_kwh': batteryCapacityKwh};
}
