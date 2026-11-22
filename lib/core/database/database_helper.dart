import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'package:sewa_garasi/core/constants/enums.dart';
import 'package:sewa_garasi/core/utils/password_hasher.dart';

/// Semua fitur: pesan error aturan bisnis, misalnya garasi sudah terpakai.
class DataException implements Exception {
  DataException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Database: koneksi SQLite (satu instance) dan pembuatan tabel.
class DatabaseHelper {
  DatabaseHelper._internal({String? path}) : _path = path;

  /// Aplikasi: koneksi yang dipakai semua repository.
  static final DatabaseHelper instance = DatabaseHelper._internal();

  /// Unit test: database terpisah (in-memory).
  factory DatabaseHelper.forTesting(String path) =>
      DatabaseHelper._internal(path: path);

  static const String _dbName = 'sewa_garasi.db';
  static const int _dbVersion = 1;

  /// Login admin: akun bawaan saat database pertama dibuat.
  static const String defaultAdminEmail = 'admin@garasi.com';
  static const String defaultAdminPassword = 'admin123';

  final String? _path;
  Database? _database;

  /// Semua repository: ambil koneksi, buka bila belum terbuka.
  Future<Database> get database async {
    return _database ??= await _open();
  }

  Future<Database> _open() async {
    final path = _path ?? p.join(await getDatabasesPath(), _dbName);
    return openDatabase(
      path,
      version: _dbVersion,
      onConfigure: _onConfigure,
      onCreate: _onCreate,
    );
  }

  /// Unit test: tutup koneksi.
  Future<void> close() async {
    await _database?.close();
    _database = null;
  }

  Future<void> _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  /// Database: buat tabel users, vehicles, garages, rentals, extensions.
  Future<void> _onCreate(Database db, int version) async {
    final batch = db.batch();

    batch.execute('''
      CREATE TABLE users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nik TEXT UNIQUE,
        full_name TEXT NOT NULL,
        phone TEXT NOT NULL,
        email TEXT NOT NULL UNIQUE,
        password_hash TEXT NOT NULL,
        role TEXT NOT NULL CHECK (role IN ('admin', 'tenant')),
        status TEXT NOT NULL CHECK (status IN ('pending', 'approved', 'rejected')),
        ktp_image_path TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    batch.execute('''
      CREATE TABLE vehicles (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        type TEXT NOT NULL
          CHECK (type IN ('bicycle', 'motorcycle', 'car', 'electricCar')),
        plate_number TEXT,
        brand_model TEXT NOT NULL,
        battery_capacity_kwh REAL,
        created_at TEXT NOT NULL
      )
    ''');

    batch.execute('''
      CREATE TABLE garages (
        id TEXT PRIMARY KEY,
        type TEXT NOT NULL CHECK (type IN ('bicycle', 'car', 'electric')),
        daily_price INTEGER NOT NULL CHECK (daily_price > 0),
        price_per_kwh INTEGER,
        status TEXT NOT NULL DEFAULT 'available'
          CHECK (status IN ('available', 'used')),
        created_at TEXT NOT NULL
      )
    ''');

    batch.execute('''
      CREATE TABLE rentals (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        vehicle_id INTEGER NOT NULL REFERENCES vehicles(id),
        garage_id TEXT NOT NULL REFERENCES garages(id),
        rental_type TEXT NOT NULL CHECK (rental_type IN ('daily', 'monthly')),
        days INTEGER NOT NULL,
        start_date TEXT NOT NULL,
        end_date TEXT NOT NULL,
        daily_price INTEGER NOT NULL,
        rental_cost INTEGER NOT NULL,
        battery_remaining_kwh REAL,
        charged_kwh REAL,
        price_per_kwh INTEGER,
        charging_cost INTEGER NOT NULL DEFAULT 0,
        total_cost INTEGER NOT NULL,
        payment_proof_path TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');

    batch.execute('''
      CREATE TABLE extensions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        rental_id INTEGER NOT NULL REFERENCES rentals(id) ON DELETE CASCADE,
        admin_id INTEGER NOT NULL REFERENCES users(id),
        old_end_date TEXT NOT NULL,
        new_end_date TEXT NOT NULL,
        added_days INTEGER NOT NULL CHECK (added_days > 0),
        daily_price INTEGER NOT NULL,
        extra_cost INTEGER NOT NULL,
        payment_proof_path TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');

    batch.execute(
        'CREATE INDEX idx_rentals_garage_end ON rentals(garage_id, end_date)');
    batch.execute('CREATE INDEX idx_rentals_start ON rentals(start_date)');
    batch.execute('CREATE INDEX idx_vehicles_user ON vehicles(user_id)');

    await batch.commit(noResult: true);
    await _seedAdmin(db);
  }

  /// Login admin: buat akun admin bawaan.
  Future<void> _seedAdmin(Database db) async {
    await db.insert('users', {
      'nik': null,
      'full_name': 'Administrator',
      'phone': '081200000000',
      'email': defaultAdminEmail,
      'password_hash': PasswordHasher.hash(defaultAdminPassword),
      'role': UserRole.admin.name,
      'status': UserStatus.approved.name,
      'ktp_image_path': null,
      'created_at': DateTime.now().toIso8601String(),
    });
  }
}
