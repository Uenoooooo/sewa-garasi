import 'package:sewa_garasi/core/constants/enums.dart';
import 'package:sewa_garasi/core/database/database_helper.dart';
import 'package:sewa_garasi/core/utils/date_helper.dart';
import 'package:sewa_garasi/models/garage.dart';

/// Detail Garasi: ringkasan pemakaian satu garasi.
class GarageUsage {
  const GarageUsage({
    this.totalRentals = 0,
    this.upcomingRentals = 0,
    this.currentTenant,
    this.currentVehicle,
    this.currentEndDate,
  });

  final int totalRentals;

  final int upcomingRentals;

  final String? currentTenant;
  final String? currentVehicle;
  final DateTime? currentEndDate;

  bool get isRentedNow => currentTenant != null;
}

/// Beranda Penyewa: jumlah garasi tersedia dan harga termurah per tipe.
class GarageAvailability {
  const GarageAvailability({
    required this.type,
    required this.available,
    required this.total,
    this.minDailyPrice,
  });

  final GarageType type;
  final int available;
  final int total;

  final int? minDailyPrice;
}

/// Kelola Garasi: akses tabel garages.
class GarageRepository {
  GarageRepository([DatabaseHelper? db]) : _db = db ?? DatabaseHelper.instance;

  final DatabaseHelper _db;

  /// Buat Garasi: simpan banyak garasi sekaligus (satu transaksi).
  Future<void> insertAll(List<Garage> garages) async {
    final db = await _db.database;
    await db.transaction((txn) async {
      final batch = txn.batch();
      for (final g in garages) {
        batch.insert('garages', g.toMap());
      }
      await batch.commit(noResult: true);
    });
  }

  /// Buat Garasi: nomor terakhir per tipe untuk ID berikutnya (C012 -> 12).
  Future<int> lastNumberByType(GarageType type) async {
    final db = await _db.database;
    final rows = await db.rawQuery(
      'SELECT MAX(CAST(SUBSTR(id, 2) AS INTEGER)) AS last '
      'FROM garages WHERE type = ?',
      [type.name],
    );
    return (rows.first['last'] as int?) ?? 0;
  }

  /// Sewa Garasi: garasi yang kosong selama periode sewa.
  Future<List<Garage>> findAvailable(GarageType type, DateTime start,
      [DateTime? end]) async {
    await syncStatuses(DateHelper.today());
    final db = await _db.database;
    final rows = await db.rawQuery('''
      SELECT g.* FROM garages g
      WHERE g.type = ?
        AND NOT EXISTS (
          SELECT 1 FROM rentals r
          WHERE r.garage_id = g.id AND r.start_date <= ? AND r.end_date >= ?
        )
      ORDER BY g.id
    ''', [type.name, DateHelper.toDb(end ?? start), DateHelper.toDb(start)]);
    return rows.map(Garage.fromMap).toList();
  }

  /// Daftar Garasi: semua garasi, bisa difilter per tipe.
  Future<List<Garage>> findAll({GarageType? type}) async {
    await syncStatuses(DateHelper.today());
    final db = await _db.database;
    final rows = await db.query('garages',
        where: type == null ? null : 'type = ?',
        whereArgs: type == null ? null : [type.name],
        orderBy: 'type, id');
    return rows.map(Garage.fromMap).toList();
  }

  /// Beranda Penyewa: ketersediaan garasi per tipe.
  Future<List<GarageAvailability>> availabilityByType(DateTime date) async {
    final db = await _db.database;
    final d = DateHelper.toDb(date);
    final rows = await db.rawQuery('''
      SELECT g.type, COUNT(*) AS total,
             SUM(CASE WHEN busy.garage_id IS NULL THEN 1 ELSE 0 END)
               AS available,
             MIN(CASE WHEN busy.garage_id IS NULL THEN g.daily_price END)
               AS min_price
      FROM garages g
      LEFT JOIN (
        SELECT DISTINCT garage_id FROM rentals
        WHERE start_date <= ? AND end_date >= ?
      ) busy ON busy.garage_id = g.id
      GROUP BY g.type
    ''', [d, d]);
    final byType = {
      for (final r in rows) r['type'] as String: r,
    };
    return [
      for (final type in GarageType.values)
        GarageAvailability(
          type: type,
          total: (byType[type.name]?['total'] as int?) ?? 0,
          available: (byType[type.name]?['available'] as int?) ?? 0,
          minDailyPrice: byType[type.name]?['min_price'] as int?,
        ),
    ];
  }

  /// Detail Garasi: cari garasi berdasarkan ID.
  Future<Garage?> findById(String id) async {
    await syncStatuses(DateHelper.today());
    final db = await _db.database;
    final rows = await db.query('garages', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : Garage.fromMap(rows.first);
  }

  /// Detail Garasi: total sewa, sewa mendatang, dan penyewa saat ini.
  Future<GarageUsage> usage(String id, DateTime date) async {
    final db = await _db.database;
    final d = DateHelper.toDb(date);
    final counts = await db.rawQuery('''
      SELECT COUNT(*) AS total,
             SUM(CASE WHEN start_date > ? THEN 1 ELSE 0 END) AS upcoming
      FROM rentals WHERE garage_id = ?
    ''', [d, id]);
    final current = await db.rawQuery('''
      SELECT u.full_name, v.brand_model, v.plate_number, r.end_date
      FROM rentals r
      JOIN vehicles v ON v.id = r.vehicle_id
      JOIN users u ON u.id = v.user_id
      WHERE r.garage_id = ? AND r.start_date <= ? AND r.end_date >= ?
      LIMIT 1
    ''', [id, d, d]);
    final now = current.isEmpty ? null : current.first;
    String? vehicle;
    if (now != null) {
      final plate = now['plate_number'] as String?;
      vehicle = plate == null
          ? '${now['brand_model']}'
          : '${now['brand_model']} (${plate.replaceAll(' ', ' ')})';
    }
    return GarageUsage(
      totalRentals: (counts.first['total'] as int?) ?? 0,
      upcomingRentals: (counts.first['upcoming'] as int?) ?? 0,
      currentTenant: now?['full_name'] as String?,
      currentVehicle: vehicle,
      currentEndDate:
          now == null ? null : DateHelper.fromDb(now['end_date'] as String),
    );
  }

  /// Status Garasi: set used/available sesuai sewa yang berjalan.
  Future<void> syncStatuses(DateTime date) async {
    final db = await _db.database;
    await db.rawUpdate('''
      UPDATE garages SET status = CASE
        WHEN EXISTS (
          SELECT 1 FROM rentals r
          WHERE r.garage_id = garages.id
            AND r.start_date <= ? AND r.end_date >= ?
        ) THEN 'used'
        ELSE 'available'
      END
    ''', [DateHelper.toDb(date), DateHelper.toDb(date)]);
  }
}
