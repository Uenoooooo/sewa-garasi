import 'package:flutter_test/flutter_test.dart';

import 'package:sewa_garasi/core/utils/date_helper.dart';

void main() {
  /// Test: Tanggal selesai sewa harian (hari mulai ikut dihitung).
  test('dailyEndDate: hari mulai ikut dihitung', () {
    expect(DateHelper.dailyEndDate(DateTime(2026, 11, 21), 1),
        DateTime(2026, 11, 21));
    expect(DateHelper.dailyEndDate(DateTime(2026, 11, 21), 3),
        DateTime(2026, 11, 23));
    // Melewati pergantian bulan dan tahun.
    expect(DateHelper.dailyEndDate(DateTime(2026, 12, 25), 30),
        DateTime(2027, 1, 23));
    expect(() => DateHelper.dailyEndDate(DateTime(2026, 11, 21), 0),
        throwsArgumentError);
  });

  /// Test: Tanggal selesai sewa bulanan mengikuti jumlah hari bulan mulai.
  test('monthlyEndDate: berlaku sejumlah hari bulan mulai', () {
    expect(DateHelper.monthlyEndDate(DateTime(2026, 11, 21)),
        DateTime(2026, 12, 20));
    // Januari 31 hari.
    expect(
        DateHelper.monthlyEndDate(DateTime(2026, 1, 31)), DateTime(2026, 3, 2));
    // Februari 2027 28 hari.
    expect(
        DateHelper.monthlyEndDate(DateTime(2027, 2, 1)), DateTime(2027, 2, 28));
    expect(DateHelper.monthlyEndDate(DateTime(2027, 2, 15)),
        DateTime(2027, 3, 14));
    expect(DateHelper.monthlyEndDate(DateTime(2026, 12, 1)),
        DateTime(2026, 12, 31));
  });

  /// Test: Jumlah hari sewa bulanan sesuai bulan mulai.
  test('daysInRentalMonth: jumlah hari bulan mulai', () {
    expect(DateHelper.daysInRentalMonth(DateTime(2026, 11, 21)), 30);
    expect(DateHelper.daysInRentalMonth(DateTime(2027, 2, 1)), 28);
    expect(DateHelper.daysInRentalMonth(DateTime(2028, 2, 1)), 29); // kabisat
  });

  /// Test: Batas sewa harian = jumlah hari bulan mulai - 1.
  test('maxDailyDays: jumlah hari bulan mulai dikurangi 1', () {
    expect(DateHelper.maxDailyDays(DateTime(2027, 2, 10)), 27);
    expect(DateHelper.maxDailyDays(DateTime(2028, 2, 1)), 28); // kabisat
    expect(DateHelper.maxDailyDays(DateTime(2027, 4, 1)), 29);
    expect(DateHelper.maxDailyDays(DateTime(2027, 1, 31)), 30);
  });

  /// Test: Menghitung selisih hari dan jumlah hari (inklusif).
  test('daysBetween dan daysInclusive', () {
    expect(
        DateHelper.daysBetween(DateTime(2026, 11, 20), DateTime(2026, 11, 25)),
        5);
    expect(
        DateHelper.daysInclusive(
            DateTime(2026, 11, 21), DateTime(2026, 11, 21)),
        1);
  });

  /// Test: Format tanggal untuk database.
  test('format database bolak-balik', () {
    final d = DateTime(2026, 3, 5);
    expect(DateHelper.toDb(d), '2026-03-05');
    expect(DateHelper.fromDb('2026-03-05'), d);
  });

  /// Test: Format tanggal di tampilan.
  test('format tampilan: display, shortDate, displayRange', () {
    const nbsp = ' ';
    expect(
        DateHelper.display(DateTime(2026, 11, 21)), '21${nbsp}Nov${nbsp}2026');
    expect(DateHelper.shortDate(DateTime(2026, 12, 5)), '05${nbsp}Des');
    // Satu tanggal saja bila mulai = selesai.
    expect(
        DateHelper.displayRange(DateTime(2026, 11, 21), DateTime(2026, 11, 21)),
        '21${nbsp}Nov${nbsp}2026');
    expect(
        DateHelper.displayRange(DateTime(2026, 11, 21), DateTime(2026, 11, 25)),
        '21${nbsp}Nov${nbsp}2026 - 25${nbsp}Nov${nbsp}2026');
  });
}
