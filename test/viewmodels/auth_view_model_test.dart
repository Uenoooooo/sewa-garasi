import 'package:flutter_test/flutter_test.dart';

import 'package:sewa_garasi/core/constants/enums.dart';
import 'package:sewa_garasi/core/database/database_helper.dart';
import 'package:sewa_garasi/core/utils/password_hasher.dart';
import 'package:sewa_garasi/models/user.dart';
import 'package:sewa_garasi/repositories/user_repository.dart';
import 'package:sewa_garasi/viewmodels/auth_view_model.dart';

import '../helpers/test_db.dart';

/// Repository palsu yang selalu gagal, untuk menguji pesan error.
class _BrokenUserRepository extends UserRepository {
  @override
  Future<User?> findByEmail(String email) => throw Exception('rusak');
}

void main() {
  late TestDb db;
  late AuthViewModel vm;

  setUpAll(TestDb.init);
  setUp(() {
    db = TestDb();
    vm = AuthViewModel(db.users);
  });
  tearDown(() => db.close());

  User newTenant(
          {String email = 'ani@mail.com', String nik = '1234567890123456'}) =>
      User(
          nik: nik, fullName: '  Ani  ', phone: ' 081111111111 ', email: email);

  group('AuthViewModel.register', () {
    /// Test: Registrasi penyewa baru.
    test('data dirapikan, password di-hash, status pending, email unik',
        () async {
      expect(await vm.register(newTenant(email: ' Ani@Mail.COM '), 'rahasia'),
          isTrue);

      final saved = (await db.users.findByEmail('ani@mail.com'))!;
      expect(saved.fullName, 'Ani');
      expect(saved.phone, '081111111111');
      expect(saved.email, 'ani@mail.com');
      expect(saved.role, UserRole.tenant);
      expect(saved.status, UserStatus.pending);
      expect(saved.passwordHash, isNot('rahasia'));
      expect(PasswordHasher.verify('rahasia', saved.passwordHash), isTrue);

      // Email yang sama tidak bisa didaftarkan lagi.
      expect(await vm.register(newTenant(), 'rahasia'), isFalse);
      expect(vm.errorMessage, 'Email sudah terdaftar');
    });
  });

  group('AuthViewModel.login', () {
    /// Test: Login admin.
    test('admin bisa login', () async {
      expect(
          await vm.login(DatabaseHelper.defaultAdminEmail,
              DatabaseHelper.defaultAdminPassword),
          isTrue);
      expect(vm.currentUser!.isAdmin(), isTrue);
    });

    /// Test: Login dengan data salah ditolak.
    test('email tidak terdaftar atau password salah ditolak', () async {
      expect(
          await vm.login(DatabaseHelper.defaultAdminEmail, 'salah'), isFalse);
      expect(vm.errorMessage, 'Email atau password salah');
      expect(vm.currentUser, isNull);

      expect(await vm.login('tidakada@mail.com', 'rahasia'), isFalse);
      expect(vm.errorMessage, 'Email atau password salah');
    });

    /// Test: Login penyewa mengikuti status verifikasi admin.
    test('login penyewa mengikuti status verifikasi', () async {
      // Pending: belum bisa login.
      await vm.register(newTenant(), 'rahasia');
      expect(await vm.login('ani@mail.com', 'rahasia'), isFalse);
      expect(vm.errorMessage, contains('menunggu verifikasi'));

      // Ditolak admin: tidak bisa login.
      await vm.register(
          newTenant(email: 'tolak@mail.com', nik: '1234567890123459'),
          'rahasia');
      final rejected = (await db.users.findByEmail('tolak@mail.com'))!;
      await vm.verifyTenant(rejected.id!, false);
      expect(await vm.login('tolak@mail.com', 'rahasia'), isFalse);
      expect(vm.errorMessage, contains('ditolak'));

      // Diterima admin: bisa login.
      final ani = (await db.users.findByEmail('ani@mail.com'))!;
      await vm.verifyTenant(ani.id!, true);
      expect(await vm.login('ani@mail.com', 'rahasia'), isTrue);
      expect(vm.currentUser!.fullName, 'Ani');
    });

    /// Test: Pesan saat terjadi error ketika login.
    test('error tak terduga diberi awalan "Terjadi kesalahan"', () async {
      final broken = AuthViewModel(_BrokenUserRepository());
      expect(await broken.login('a@mail.com', 'x'), isFalse);
      expect(broken.errorMessage, contains('Terjadi kesalahan'));
      expect(broken.isLoading, isFalse);
    });
  });

  group('AuthViewModel verifikasi & logout', () {
    /// Test: Admin memverifikasi pendaftar.
    test('daftar pendaftar berkurang setelah diverifikasi', () async {
      await vm.register(newTenant(email: 'a@mail.com'), 'rahasia');
      await vm.register(
          User(
              nik: '1234567890123457',
              fullName: 'Bayu',
              phone: '081111111112',
              email: 'b@mail.com'),
          'rahasia');

      await vm.loadPendingTenants();
      expect(vm.pendingTenants, hasLength(2));

      await vm.verifyTenant(vm.pendingTenants.first.id!, true);
      expect(vm.pendingTenants, hasLength(1));
    });

    /// Test: Logout.
    test('logout menghapus data pengguna', () async {
      await vm.login(DatabaseHelper.defaultAdminEmail,
          DatabaseHelper.defaultAdminPassword);
      await vm.loadPendingTenants();

      vm.logout();

      expect(vm.currentUser, isNull);
      expect(vm.pendingTenants, isEmpty);
      expect(vm.errorMessage, isNull);
    });
  });
}
