import 'package:sewa_garasi/core/constants/enums.dart';
import 'package:sewa_garasi/core/database/database_helper.dart';
import 'package:sewa_garasi/core/utils/date_helper.dart';
import 'package:sewa_garasi/models/rental.dart';
import 'package:sewa_garasi/models/rental_extension.dart';

/// Sewa & Perpanjangan: akses tabel rentals dan extensions.
class RentalRepository {
  RentalRepository([DatabaseHelper? db]) : _db = db ?? DatabaseHelper.instance;

  final DatabaseHelper _db;

  static const String _baseSelect = '''
    SELECT r.*, v.brand_model, v.plate_number, v.type AS vehicle_type,
           g.type AS garage_type, u.id AS tenant_id, u.full_name AS tenant_name
    FROM rentals r
    JOIN vehicles v ON v.id = r.vehicle_id
    JOIN garages g ON g.id = r.garage_id
    JOIN users u ON u.id = v.user_id
  ''';

  /// Cek bentrok: periode beririsan bila mulai A <= selesai B dan selesai A >= mulai B.
  static const String _overlaps = 'start_date <= ? AND end_date >= ?';

  /// Sewa Garasi: simpan sewa, tolak bila garasi/kendaraan bentrok.
  Future<int> insert(Rental rental) async {
    final db = await _db.database;
    final start = DateHelper.toDb(rental.startDate);
    final end = DateHelper.toDb(rental.endDate);
    return db.transaction<int>((txn) async {
      final garageBusy = await txn.rawQuery(
        'SELECT 1 FROM rentals WHERE garage_id = ? AND $_overlaps LIMIT 1',
        [rental.garageId, end, start],
      );
      if (garageBusy.isNotEmpty) {
        throw DataException(
            'Garasi ${rental.garageId} sudah dipesan pada periode tersebut');
      }
      final vehicleBusy = await txn.rawQuery(
        'SELECT 1 FROM rentals WHERE vehicle_id = ? AND $_overlaps LIMIT 1',
        [rental.vehicleId, end, start],
      );
      if (vehicleBusy.isNotEmpty) {
        throw DataException(
            'Kendaraan ini sudah parkir di garasi lain pada periode tersebut');
      }
      final id = await txn.insert('rentals', rental.toMap());
      final today = DateHelper.today();
      if (!rental.startDate.isAfter(today) && !rental.endDate.isBefore(today)) {
        await txn.update('garages', {'status': GarageStatus.used.name},
            where: 'id = ?', whereArgs: [rental.garageId]);
      }
      return id;
    });
  }

  /// Perpanjang Sewa: cari sewa berdasarkan ID.
  Future<Rental?> findById(int id) async {
    final db = await _db.database;
    final rows = await db.rawQuery('$_baseSelect WHERE r.id = ?', [id]);
    return rows.isEmpty ? null : Rental.fromMap(rows.first);
  }

  /// Perpanjang Sewa: sewa yang sedang berjalan.
  Future<List<Rental>> findActive(DateTime date) async {
    final db = await _db.database;
    final d = DateHelper.toDb(date);
    final rows = await db.rawQuery(
      '$_baseSelect WHERE r.start_date <= ? AND r.end_date >= ? '
      'ORDER BY r.end_date, r.garage_id',
      [d, d],
    );
    return rows.map(Rental.fromMap).toList();
  }

  /// Perpanjang Sewa: sewa yang akan datang, terdekat di atas.
  Future<List<Rental>> findUpcoming(DateTime date) async {
    final db = await _db.database;
    final rows = await db.rawQuery(
      '$_baseSelect WHERE r.start_date > ? ORDER BY r.start_date, r.garage_id',
      [DateHelper.toDb(date)],
    );
    return rows.map(Rental.fromMap).toList();
  }

  /// Dashboard Admin: sewa yang segera berakhir.
  Future<List<Rental>> findEndingSoon(DateTime date, int withinDays) async {
    final db = await _db.database;
    final rows = await db.rawQuery(
      '$_baseSelect WHERE r.start_date <= ? AND r.end_date >= ? '
      'AND r.end_date <= ? ORDER BY r.end_date, r.garage_id',
      [
        DateHelper.toDb(date),
        DateHelper.toDb(date),
        DateHelper.toDb(date.add(Duration(days: withinDays))),
      ],
    );
    return rows.map(Rental.fromMap).toList();
  }

  /// Sewa Garasi: jadwal sewa penyewa yang belum selesai.
  Future<List<Rental>> findBookingsByUser(int userId, DateTime date) async {
    final db = await _db.database;
    final rows = await db.rawQuery(
      '$_baseSelect WHERE v.user_id = ? AND r.end_date >= ? '
      'ORDER BY r.start_date, r.id',
      [userId, DateHelper.toDb(date)],
    );
    return rows.map(Rental.fromMap).toList();
  }

  /// Riwayat Sewa: semua sewa penyewa, terbaru di atas.
  Future<List<Rental>> findByUser(int userId) async {
    final db = await _db.database;
    final rows = await db.rawQuery(
      '$_baseSelect WHERE v.user_id = ? ORDER BY r.start_date DESC, r.id DESC',
      [userId],
    );
    return rows.map(Rental.fromMap).toList();
  }

  /// Perpanjang Sewa: simpan perpanjangan dan geser tanggal selesai, tolak bila bentrok.
  Future<int> insertExtension(RentalExtension ext) async {
    final db = await _db.database;
    return db.transaction<int>((txn) async {
      final current = await txn.query('rentals',
          columns: ['garage_id', 'vehicle_id'],
          where: 'id = ?',
          whereArgs: [ext.rentalId]);
      if (current.isEmpty) throw DataException('Data sewa tidak ditemukan');
      final from = DateHelper.toDb(ext.oldEndDate.add(const Duration(days: 1)));
      final to = DateHelper.toDb(ext.newEndDate);
      final garageBusy = await txn.rawQuery(
        'SELECT start_date FROM rentals WHERE garage_id = ? AND id != ? '
        'AND $_overlaps ORDER BY start_date LIMIT 1',
        [current.first['garage_id'], ext.rentalId, to, from],
      );
      if (garageBusy.isNotEmpty) {
        final next =
            DateHelper.fromDb(garageBusy.first['start_date'] as String);
        throw DataException('Garasi sudah dipesan penyewa lain mulai '
            '${DateHelper.display(next)}. Perpanjangan maksimal sampai '
            '${DateHelper.display(next.subtract(const Duration(days: 1)))}');
      }
      final vehicleBusy = await txn.rawQuery(
        'SELECT 1 FROM rentals WHERE vehicle_id = ? AND id != ? '
        'AND $_overlaps LIMIT 1',
        [current.first['vehicle_id'], ext.rentalId, to, from],
      );
      if (vehicleBusy.isNotEmpty) {
        throw DataException(
            'Kendaraan ini sudah parkir di garasi lain pada tambahan periode');
      }
      final id = await txn.insert('extensions', ext.toMap());
      await txn.update(
        'rentals',
        {'end_date': DateHelper.toDb(ext.newEndDate)},
        where: 'id = ?',
        whereArgs: [ext.rentalId],
      );
      return id;
    });
  }

  /// Detail Sewa: daftar perpanjangan satu sewa.
  Future<List<RentalExtension>> findExtensions(int rentalId) async {
    final db = await _db.database;
    final rows = await db.query('extensions',
        where: 'rental_id = ?', whereArgs: [rentalId], orderBy: 'id');
    return rows.map(RentalExtension.fromMap).toList();
  }
}
