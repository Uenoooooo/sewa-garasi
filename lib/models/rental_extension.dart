import 'package:sewa_garasi/core/utils/date_helper.dart';

/// Perpanjang Sewa: data perpanjangan oleh admin (tabel extensions).
class RentalExtension {
  final int? id;
  final int rentalId;
  final int adminId;
  final DateTime oldEndDate;
  final DateTime newEndDate;
  final int addedDays;
  final int dailyPrice;
  final int extraCost;
  final String paymentProofPath;
  final DateTime createdAt;

  RentalExtension({
    this.id,
    required this.rentalId,
    required this.adminId,
    required this.oldEndDate,
    required this.newEndDate,
    required this.addedDays,
    required this.dailyPrice,
    required this.extraCost,
    required this.paymentProofPath,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'rental_id': rentalId,
        'admin_id': adminId,
        'old_end_date': DateHelper.toDb(oldEndDate),
        'new_end_date': DateHelper.toDb(newEndDate),
        'added_days': addedDays,
        'daily_price': dailyPrice,
        'extra_cost': extraCost,
        'payment_proof_path': paymentProofPath,
        'created_at': createdAt.toIso8601String(),
      };

  factory RentalExtension.fromMap(Map<String, dynamic> map) => RentalExtension(
        id: map['id'] as int?,
        rentalId: map['rental_id'] as int,
        adminId: map['admin_id'] as int,
        oldEndDate: DateHelper.fromDb(map['old_end_date'] as String),
        newEndDate: DateHelper.fromDb(map['new_end_date'] as String),
        addedDays: map['added_days'] as int,
        dailyPrice: map['daily_price'] as int,
        extraCost: map['extra_cost'] as int,
        paymentProofPath: map['payment_proof_path'] as String,
        createdAt: DateTime.parse(map['created_at'] as String),
      );
}
