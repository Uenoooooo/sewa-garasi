import 'package:flutter_test/flutter_test.dart';

import 'package:sewa_garasi/core/utils/currency_formatter.dart';
import 'package:sewa_garasi/core/utils/password_hasher.dart';
import 'package:sewa_garasi/core/utils/validators.dart';

void main() {
  group('Validators', () {
    /// Test: Validasi NIK wajib 16 digit angka.
    test('nik: wajib 16 digit angka', () {
      expect(Validators.nik('3578012345678901'), isNull);
      expect(Validators.nik('12345'), isNotNull);
      expect(Validators.nik('35780123456789AB'), isNotNull);
      expect(Validators.nik(''), isNotNull);
    });

    /// Test: Validasi format email.
    test('email: wajib ada @', () {
      expect(Validators.email('budi@mail.com'), isNull);
      expect(Validators.email('budimail.com'), isNotNull);
    });

    /// Test: Validasi nomor HP.
    test('phone: format 08xx atau +628xx', () {
      expect(Validators.phone('081234567890'), isNull);
      expect(Validators.phone('+6281234567890'), isNull);
      expect(Validators.phone('0812'), isNotNull);
    });

    /// Test: Validasi jumlah hari sewa harian 1-30 hari.
    test('rentalDays tanpa tanggal mulai: 1-30 hari', () {
      expect(Validators.rentalDays('1'), isNull);
      expect(Validators.rentalDays('30'), isNull);
      expect(Validators.rentalDays('31'), isNotNull);
      expect(Validators.rentalDays('0'), isNotNull);
      expect(Validators.rentalDays('abc'), isNotNull);
    });

    /// Test: Validasi jumlah hari sewa harian mengikuti bulan mulai.
    test('rentalDays mengikuti bulan mulai', () {
      final feb2027 = DateTime(2027, 2, 1);
      expect(Validators.rentalDays('27', feb2027), isNull);
      expect(Validators.rentalDays('28', feb2027), isNotNull);
      expect(Validators.rentalDays('30', DateTime(2027, 1, 5)), isNull);
    });

    /// Test: Validasi jumlah garasi yang dibuat 1-999.
    test('garageCount: 1-999', () {
      expect(Validators.garageCount('999'), isNull);
      expect(Validators.garageCount('1000'), isNotNull);
      expect(Validators.garageCount('0'), isNotNull);
    });

    /// Test: Validasi sisa baterai 0 sampai kapasitas.
    test('batteryRemaining: 0 sampai kapasitas', () {
      expect(Validators.batteryRemaining('20', 60), isNull);
      expect(Validators.batteryRemaining('70', 60), isNotNull);
      expect(Validators.batteryRemaining('-1', 60), isNotNull);
    });

    /// Test: Validasi plat nomor (huruf-angka-huruf).
    test('plateNumber: huruf-angka-huruf', () {
      expect(Validators.plateNumber('L 1234 AB'), isNull);
      expect(Validators.plateNumber('B1234XYZ'), isNull);
      expect(Validators.plateNumber('1234'), isNotNull);
    });

    /// Test: Validasi field wajib diisi.
    test('required: tidak boleh kosong atau spasi saja', () {
      expect(Validators.required('Avanza'), isNull);
      expect(Validators.required('   ', 'Merk'), 'Merk wajib diisi');
      expect(Validators.required(null), isNotNull);
    });

    /// Test: Validasi password minimal 6 karakter.
    test('password: minimal 6 karakter', () {
      expect(Validators.password('abcdef'), isNull);
      expect(Validators.password('abcde'), contains('minimal 6'));
      expect(Validators.password(''), 'Password wajib diisi');
    });

    /// Test: Validasi harga berupa angka lebih dari 0.
    test('positiveInt (harga): angka lebih dari 0', () {
      expect(Validators.positiveInt('20000'), isNull);
      expect(Validators.positiveInt('0', 'Harga'), 'Harga harus lebih dari 0');
      expect(
          Validators.positiveInt('abc', 'Harga'), 'Harga wajib berupa angka');
    });

    /// Test: Validasi kapasitas baterai berupa desimal lebih dari 0.
    test('positiveDouble (kapasitas baterai): desimal lebih dari 0', () {
      expect(Validators.positiveDouble('60,5'), isNull);
      expect(Validators.positiveDouble('0'), contains('lebih dari 0'));
      expect(Validators.positiveDouble('x'), contains('angka'));
    });
  });

  /// Test: Password disimpan dalam bentuk hash.
  test('PasswordHasher: hash konsisten, bukan plaintext, bisa diverifikasi',
      () {
    final h = PasswordHasher.hash('rahasia');
    expect(h, PasswordHasher.hash('rahasia'));
    expect(h, isNot('rahasia'));
    expect(h.length, 64);
    expect(PasswordHasher.verify('rahasia', h), isTrue);
    expect(PasswordHasher.verify('salah', h), isFalse);
  });

  /// Test: Format angka ke Rupiah.
  test('CurrencyFormatter.rupiah', () {
    expect(CurrencyFormatter.rupiah(125000), 'Rp125.000');
  });
}
