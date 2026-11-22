import 'package:sewa_garasi/core/constants/enums.dart';
import 'package:sewa_garasi/core/database/database_helper.dart';
import 'package:sewa_garasi/models/user.dart';

/// Registrasi, Login, Verifikasi: akses tabel users.
class UserRepository {
  UserRepository([DatabaseHelper? db]) : _db = db ?? DatabaseHelper.instance;

  final DatabaseHelper _db;

  /// Registrasi: simpan pengguna baru, tolak bila email/NIK sudah terdaftar.
  Future<int> insert(User user) async {
    final db = await _db.database;
    if (await findByEmail(user.email) != null) {
      throw DataException('Email sudah terdaftar');
    }
    if (user.nik != null) {
      final sameNik = await db.query('users',
          columns: ['id'], where: 'nik = ?', whereArgs: [user.nik], limit: 1);
      if (sameNik.isNotEmpty) throw DataException('NIK sudah terdaftar');
    }
    return db.insert('users', user.toMap());
  }

  /// Login: cari akun berdasarkan email.
  Future<User?> findByEmail(String email) async {
    final db = await _db.database;
    final rows = await db.query('users',
        where: 'LOWER(email) = ?',
        whereArgs: [email.trim().toLowerCase()],
        limit: 1);
    return rows.isEmpty ? null : User.fromMap(rows.first);
  }

  /// Verifikasi Penyewa: pendaftar yang menunggu, terlama di atas.
  Future<List<User>> findPendingTenants() async {
    final db = await _db.database;
    final rows = await db.query('users',
        where: 'role = ? AND status = ?',
        whereArgs: [UserRole.tenant.name, UserStatus.pending.name],
        orderBy: 'created_at ASC');
    return rows.map(User.fromMap).toList();
  }

  /// Verifikasi Penyewa: terima atau tolak pendaftar.
  Future<void> updateStatus(int id, UserStatus status) async {
    final db = await _db.database;
    await db.update('users', {'status': status.name},
        where: 'id = ?', whereArgs: [id]);
  }
}
