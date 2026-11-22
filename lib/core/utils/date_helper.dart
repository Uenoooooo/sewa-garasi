import 'package:intl/intl.dart';

/// Sewa Garasi: perhitungan dan format tanggal (tanggal selesai ikut dihitung).
class DateHelper {
  DateHelper._();

  static const int maxDailyDaysAnyMonth = 30;

  static const int maxBookingAheadDays = 365;

  static int daysInMonth(DateTime date) =>
      DateTime(date.year, date.month + 1, 0).day;

  /// Sewa Harian: batas hari = jumlah hari bulan mulai - 1.
  static int maxDailyDays(DateTime start) => daysInMonth(start) - 1;

  static final DateFormat _dbFormat = DateFormat('yyyy-MM-dd');

  static DateTime today() => dateOnly(DateTime.now());

  static DateTime dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  /// Sewa Harian: tanggal selesai.
  static DateTime dailyEndDate(DateTime start, int days) {
    if (days < 1) {
      throw ArgumentError('Jumlah hari minimal 1');
    }
    final s = dateOnly(start);
    return DateTime(s.year, s.month, s.day + days - 1);
  }

  /// Sewa Bulanan: tanggal selesai (lama = jumlah hari bulan mulai).
  static DateTime monthlyEndDate(DateTime start) {
    final s = dateOnly(start);
    return DateTime(s.year, s.month, s.day + daysInMonth(s) - 1);
  }

  static int daysInRentalMonth(DateTime start) =>
      daysInclusive(start, monthlyEndDate(start));

  static int daysInclusive(DateTime start, DateTime end) =>
      daysBetween(start, end) + 1;

  /// Perpanjang Sewa: selisih hari antar tanggal.
  static int daysBetween(DateTime from, DateTime to) {
    final a = DateTime.utc(from.year, from.month, from.day);
    final b = DateTime.utc(to.year, to.month, to.day);
    return b.difference(a).inDays;
  }

  /// Database: simpan tanggal sebagai yyyy-MM-dd.
  static String toDb(DateTime date) => _dbFormat.format(date);

  static DateTime fromDb(String value) => DateTime.parse(value);

  static const List<String> _shortMonths = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'Mei',
    'Jun',
    'Jul',
    'Agu',
    'Sep',
    'Okt',
    'Nov',
    'Des',
  ];

  /// Tampilan: format tanggal "05 Des 2026".
  static String display(DateTime date) {
    const nbsp = '\u00A0';
    final day = date.day.toString().padLeft(2, '0');
    return '$day$nbsp${_shortMonths[date.month - 1]}$nbsp${date.year}';
  }

  static String shortDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}\u00A0${_shortMonths[date.month - 1]}';

  static String displayRange(DateTime start, DateTime end) =>
      dateOnly(start) == dateOnly(end)
          ? display(start)
          : '${display(start)} - ${display(end)}';

  static String monthName(int month) {
    const names = [
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember',
    ];
    return names[month - 1];
  }
}
