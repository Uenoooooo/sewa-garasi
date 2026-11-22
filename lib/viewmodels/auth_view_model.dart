import 'package:flutter/foundation.dart';

import 'package:sewa_garasi/core/constants/enums.dart';
import 'package:sewa_garasi/core/database/database_helper.dart';
import 'package:sewa_garasi/core/utils/password_hasher.dart';
import 'package:sewa_garasi/models/user.dart';
import 'package:sewa_garasi/repositories/user_repository.dart';

/// Registrasi, Login, Logout, Verifikasi Penyewa.
class AuthViewModel extends ChangeNotifier {
  AuthViewModel([UserRepository? repository])
      : _repository = repository ?? UserRepository();

  final UserRepository _repository;

  User? currentUser;
  List<User> pendingTenants = [];
  bool isLoading = false;
  String? errorMessage;

  /// Registrasi: daftar penyewa baru (status pending).
  Future<bool> register(User user, String password) async {
    return _run(() async {
      final newUser = User(
        nik: user.nik,
        fullName: user.fullName.trim(),
        phone: user.phone.trim(),
        email: user.email.trim().toLowerCase(),
        passwordHash: _hashPassword(password),
        role: UserRole.tenant,
        status: UserStatus.pending,
        ktpImagePath: user.ktpImagePath,
      );
      await _repository.insert(newUser);
    });
  }

  /// Login: penyewa hanya bisa masuk bila sudah diterima admin.
  Future<bool> login(String email, String password) async {
    return _run(() async {
      final user = await _repository.findByEmail(email);
      if (user == null || !PasswordHasher.verify(password, user.passwordHash)) {
        throw DataException('Email atau password salah');
      }
      if (!user.isAdmin()) {
        if (user.status == UserStatus.pending) {
          throw DataException('Akun Anda masih menunggu verifikasi admin');
        }
        if (user.status == UserStatus.rejected) {
          throw DataException('Pendaftaran Anda ditolak admin');
        }
      }
      currentUser = user;
    });
  }

  /// Verifikasi Penyewa: muat daftar pendaftar.
  Future<void> loadPendingTenants() async {
    await _run(() async {
      pendingTenants = await _repository.findPendingTenants();
    });
  }

  /// Verifikasi Penyewa: terima atau tolak pendaftar.
  Future<bool> verifyTenant(int userId, bool approved) async {
    return _run(() async {
      await _repository.updateStatus(
        userId,
        approved ? UserStatus.approved : UserStatus.rejected,
      );
      pendingTenants = await _repository.findPendingTenants();
    });
  }

  /// Logout: hapus data pengguna yang login.
  void logout() {
    currentUser = null;
    pendingTenants = [];
    errorMessage = null;
    notifyListeners();
  }

  String _hashPassword(String password) => PasswordHasher.hash(password);

  Future<bool> _run(Future<void> Function() action) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      await action();
      return true;
    } on DataException catch (e) {
      errorMessage = e.message;
      return false;
    } catch (e) {
      errorMessage = 'Terjadi kesalahan: $e';
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}
