import 'package:sewa_garasi/core/database/database_helper.dart';
import 'package:sewa_garasi/models/vehicle.dart';

/// Kendaraan Penyewa: akses tabel vehicles.
class VehicleRepository {
  VehicleRepository([DatabaseHelper? db]) : _db = db ?? DatabaseHelper.instance;

  final DatabaseHelper _db;

  /// Tambah Kendaraan: simpan kendaraan baru.
  Future<int> insert(Vehicle vehicle) async {
    final db = await _db.database;
    return db.insert('vehicles', vehicle.toMap());
  }

  /// Daftar Kendaraan: semua kendaraan milik penyewa.
  Future<List<Vehicle>> findByUser(int userId) async {
    final db = await _db.database;
    final rows = await db.query('vehicles',
        where: 'user_id = ?', whereArgs: [userId], orderBy: 'created_at DESC');
    return rows.map(Vehicle.fromMap).toList();
  }

  /// Daftar Kendaraan: kendaraan yang sedang parkir hari ini.
  Future<Set<int>> findParkedVehicleIds(int userId, String date) async {
    final db = await _db.database;
    final rows = await db.rawQuery('''
      SELECT DISTINCT r.vehicle_id FROM rentals r
      JOIN vehicles v ON v.id = r.vehicle_id
      WHERE v.user_id = ? AND r.start_date <= ? AND r.end_date >= ?
    ''', [userId, date, date]);
    return rows.map((r) => r['vehicle_id'] as int).toSet();
  }
}
