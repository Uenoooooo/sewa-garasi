import 'package:sewa_garasi/core/utils/date_helper.dart';

/// Semua form: validasi input (null = valid, selain itu pesan error).
class Validators {
  Validators._();

  static String? required(String? value, [String field = 'Field']) {
    if (value == null || value.trim().isEmpty) return '$field wajib diisi';
    return null;
  }

  static String? nik(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'NIK wajib diisi';
    if (!RegExp(r'^\d{16}$').hasMatch(v)) return 'NIK harus 16 digit angka';
    return null;
  }

  static String? email(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Email wajib diisi';
    if (!RegExp(r'^[\w.+-]+@[\w-]+(\.[\w-]+)+$').hasMatch(v)) {
      return 'Format email tidak valid';
    }
    return null;
  }

  static String? phone(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Nomor telepon wajib diisi';
    if (!RegExp(r'^(\+62|0)8\d{8,11}$').hasMatch(v)) {
      return 'Nomor telepon tidak valid (contoh: 081234567890)';
    }
    return null;
  }

  static String? password(String? value) {
    final v = value ?? '';
    if (v.isEmpty) return 'Password wajib diisi';
    if (v.length < 6) return 'Password minimal 6 karakter';
    return null;
  }

  static String? rentalDays(String? value, [DateTime? startDate]) {
    final days = int.tryParse(value?.trim() ?? '');
    if (days == null) return 'Jumlah hari wajib berupa angka';
    if (days < 1) return 'Jumlah hari minimal 1';
    final max = startDate == null
        ? DateHelper.maxDailyDaysAnyMonth
        : DateHelper.maxDailyDays(startDate);
    if (days > max) {
      return startDate == null
          ? 'Sewa harian maksimal $max hari'
          : 'Sewa harian mulai ${DateHelper.monthName(startDate.month)} '
              'maksimal $max hari';
    }
    return null;
  }

  static String? garageCount(String? value) {
    final count = int.tryParse(value?.trim() ?? '');
    if (count == null) return 'Jumlah garasi wajib berupa angka';
    if (count < 1 || count > 999) return 'Jumlah garasi antara 1 - 999';
    return null;
  }

  static String? positiveInt(String? value, [String field = 'Nilai']) {
    final n = int.tryParse(value?.trim() ?? '');
    if (n == null) return '$field wajib berupa angka';
    if (n <= 0) return '$field harus lebih dari 0';
    return null;
  }

  static String? positiveDouble(String? value, [String field = 'Nilai']) {
    final n = double.tryParse(value?.trim().replaceAll(',', '.') ?? '');
    if (n == null) return '$field wajib berupa angka';
    if (n <= 0) return '$field harus lebih dari 0';
    return null;
  }

  static String? batteryRemaining(String? value, double capacity) {
    final n = double.tryParse(value?.trim().replaceAll(',', '.') ?? '');
    if (n == null) return 'Sisa baterai wajib berupa angka';
    if (n < 0) return 'Sisa baterai tidak boleh negatif';
    if (n > capacity) return 'Sisa baterai melebihi kapasitas ($capacity kWh)';
    return null;
  }

  static String? plateNumber(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Nomor plat wajib diisi';
    if (!RegExp(r'^[A-Za-z]{1,2}\s?\d{1,4}\s?[A-Za-z]{0,3}$').hasMatch(v)) {
      return 'Format plat tidak valid (contoh: L 1234 AB)';
    }
    return null;
  }
}
