import 'package:sewa_garasi/core/constants/enums.dart';
import 'package:sewa_garasi/core/utils/date_helper.dart';

/// Sewa Garasi: data transaksi sewa (tabel rentals + data join untuk tampilan).
class Rental {
  final int? id;
  final int vehicleId;
  final String garageId;
  final RentalType rentalType;
  final int days;
  final DateTime startDate;
  final DateTime endDate;
  final int dailyPrice;
  final int rentalCost;
  final double? batteryRemainingKwh;
  final double? chargedKwh;
  final int? pricePerKwh;
  final int chargingCost;
  final int totalCost;
  final String paymentProofPath;
  final DateTime createdAt;

  final String? vehicleName;
  final VehicleType? vehicleType;
  final GarageType? garageType;
  final String? tenantName;
  final int? tenantId;

  Rental({
    this.id,
    required this.vehicleId,
    required this.garageId,
    required this.rentalType,
    required this.days,
    required this.startDate,
    required this.endDate,
    required this.dailyPrice,
    required this.rentalCost,
    this.batteryRemainingKwh,
    this.chargedKwh,
    this.pricePerKwh,
    this.chargingCost = 0,
    required this.totalCost,
    required this.paymentProofPath,
    DateTime? createdAt,
    this.vehicleName,
    this.vehicleType,
    this.garageType,
    this.tenantName,
    this.tenantId,
  }) : createdAt = createdAt ?? DateTime.now();

  /// Sewa Garasi: cek sewa aktif pada suatu tanggal.
  bool isActiveOn(DateTime date) {
    final d = DateHelper.dateOnly(date);
    return !d.isBefore(startDate) && !d.isAfter(endDate);
  }

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'vehicle_id': vehicleId,
        'garage_id': garageId,
        'rental_type': rentalType.name,
        'days': days,
        'start_date': DateHelper.toDb(startDate),
        'end_date': DateHelper.toDb(endDate),
        'daily_price': dailyPrice,
        'rental_cost': rentalCost,
        'battery_remaining_kwh': batteryRemainingKwh,
        'charged_kwh': chargedKwh,
        'price_per_kwh': pricePerKwh,
        'charging_cost': chargingCost,
        'total_cost': totalCost,
        'payment_proof_path': paymentProofPath,
        'created_at': createdAt.toIso8601String(),
      };

  factory Rental.fromMap(Map<String, dynamic> map) {
    return Rental(
      id: map['id'] as int?,
      vehicleId: map['vehicle_id'] as int,
      garageId: map['garage_id'] as String,
      rentalType: RentalType.values.byName(map['rental_type'] as String),
      days: map['days'] as int,
      startDate: DateHelper.fromDb(map['start_date'] as String),
      endDate: DateHelper.fromDb(map['end_date'] as String),
      dailyPrice: map['daily_price'] as int,
      rentalCost: map['rental_cost'] as int,
      batteryRemainingKwh: (map['battery_remaining_kwh'] as num?)?.toDouble(),
      chargedKwh: (map['charged_kwh'] as num?)?.toDouble(),
      pricePerKwh: map['price_per_kwh'] as int?,
      chargingCost: map['charging_cost'] as int? ?? 0,
      totalCost: map['total_cost'] as int,
      paymentProofPath: map['payment_proof_path'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      vehicleName: _vehicleName(
          map['brand_model'] as String?, map['plate_number'] as String?),
      vehicleType: map['vehicle_type'] == null
          ? null
          : VehicleType.values.byName(map['vehicle_type'] as String),
      garageType: map['garage_type'] == null
          ? null
          : GarageType.values.byName(map['garage_type'] as String),
      tenantName: map['tenant_name'] as String?,
      tenantId: map['tenant_id'] as int?,
    );
  }

  static String? _vehicleName(String? brand, String? plate) {
    if (brand == null) return null;
    if (plate == null) return brand;
    return '$brand (${plate.replaceAll(' ', '\u00A0')})';
  }
}
