import 'package:sewa_garasi/core/constants/enums.dart';

/// Registrasi & Login: data pengguna admin / penyewa (tabel users).
class User {
  final int? id;
  final String? nik;
  final String fullName;
  final String phone;
  final String email;
  final String passwordHash;
  final UserRole role;
  final UserStatus status;
  final String? ktpImagePath;
  final DateTime createdAt;

  User({
    this.id,
    this.nik,
    required this.fullName,
    required this.phone,
    required this.email,
    this.passwordHash = '',
    this.role = UserRole.tenant,
    this.status = UserStatus.pending,
    this.ktpImagePath,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  bool isAdmin() => role == UserRole.admin;

  User copyWith({
    int? id,
    String? passwordHash,
    UserStatus? status,
  }) {
    return User(
      id: id ?? this.id,
      nik: nik,
      fullName: fullName,
      phone: phone,
      email: email,
      passwordHash: passwordHash ?? this.passwordHash,
      role: role,
      status: status ?? this.status,
      ktpImagePath: ktpImagePath,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'nik': nik,
        'full_name': fullName,
        'phone': phone,
        'email': email,
        'password_hash': passwordHash,
        'role': role.name,
        'status': status.name,
        'ktp_image_path': ktpImagePath,
        'created_at': createdAt.toIso8601String(),
      };

  factory User.fromMap(Map<String, dynamic> map) => User(
        id: map['id'] as int?,
        nik: map['nik'] as String?,
        fullName: map['full_name'] as String,
        phone: map['phone'] as String,
        email: map['email'] as String,
        passwordHash: map['password_hash'] as String? ?? '',
        role: UserRole.values.byName(map['role'] as String),
        status: UserStatus.values.byName(map['status'] as String),
        ktpImagePath: map['ktp_image_path'] as String?,
        createdAt: DateTime.parse(map['created_at'] as String),
      );
}
