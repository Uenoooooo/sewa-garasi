import 'package:sewa_garasi/core/constants/enums.dart';

/// Kelola Garasi: data garasi (tabel garages).
class Garage {
  static const int monthlyMultiplier = 25;

  final String id;
  final GarageType type;
  final int dailyPrice;
  final GarageStatus status;
  final DateTime createdAt;

  Garage({
    required this.id,
    required this.type,
    required this.dailyPrice,
    this.status = GarageStatus.available,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  /// Sewa Bulanan: harga = 25 x harga harian.
  int monthlyPrice() => dailyPrice * monthlyMultiplier;

  bool get isAvailable => status == GarageStatus.available;

  int? get pricePerKwh => null;

  Map<String, dynamic> toMap() => {
        'id': id,
        'type': type.name,
        'daily_price': dailyPrice,
        'price_per_kwh': pricePerKwh,
        'status': status.name,
        'created_at': createdAt.toIso8601String(),
      };

  /// Database: buat ElectricGarage bila garasi listrik, selain itu Garage.
  factory Garage.fromMap(Map<String, dynamic> map) {
    final type = GarageType.values.byName(map['type'] as String);
    final status = GarageStatus.values.byName(map['status'] as String);
    final createdAt = DateTime.parse(map['created_at'] as String);
    if (type == GarageType.electric) {
      return ElectricGarage(
        id: map['id'] as String,
        dailyPrice: map['daily_price'] as int,
        pricePerKwh: map['price_per_kwh'] as int,
        status: status,
        createdAt: createdAt,
      );
    }
    return Garage(
      id: map['id'] as String,
      type: type,
      dailyPrice: map['daily_price'] as int,
      status: status,
      createdAt: createdAt,
    );
  }
}

/// Garasi Listrik: punya tarif isi listrik per kWh.
class ElectricGarage extends Garage {
  final int _pricePerKwh;

  ElectricGarage({
    required super.id,
    required super.dailyPrice,
    required int pricePerKwh,
    super.status,
    super.createdAt,
  })  : _pricePerKwh = pricePerKwh,
        super(type: GarageType.electric);

  @override
  int get pricePerKwh => _pricePerKwh;

  /// Sewa Garasi Listrik: biaya isi listrik.
  int chargingCost(double kwh) => (kwh * _pricePerKwh).round();
}
