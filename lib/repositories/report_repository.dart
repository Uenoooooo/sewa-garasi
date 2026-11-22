import 'package:sewa_garasi/core/database/database_helper.dart';

/// Laporan: satu baris pendapatan (bulan/tanggal/tipe/penyewa).
class ReportRow {
  final String label;
  final int rentalCount;
  final int extensionCount;
  final int revenue;

  final int rentalRevenue;
  final int extensionRevenue;

  const ReportRow({
    required this.label,
    required this.rentalCount,
    required this.extensionCount,
    required this.revenue,
    this.rentalRevenue = 0,
    this.extensionRevenue = 0,
  });

  /// Laporan: jumlah transaksi (sewa baru + perpanjangan).
  int get transactionCount => rentalCount + extensionCount;

  factory ReportRow.fromMap(Map<String, dynamic> map) => ReportRow(
        label: '${map['label']}',
        rentalCount: (map['rental_count'] as int?) ?? 0,
        extensionCount: (map['extension_count'] as int?) ?? 0,
        revenue: (map['revenue'] as int?) ?? 0,
        rentalRevenue: (map['rental_revenue'] as int?) ?? 0,
        extensionRevenue: (map['extension_revenue'] as int?) ?? 0,
      );
}

/// Laporan: pendapatan = biaya sewa baru + biaya perpanjangan.
class ReportRepository {
  ReportRepository([DatabaseHelper? db]) : _db = db ?? DatabaseHelper.instance;

  final DatabaseHelper _db;

  static const String _transactions = '''
    WITH tx AS (
      SELECT r.start_date AS tx_date, 1 AS is_rental, r.total_cost AS amount,
             g.type AS garage_type, v.user_id AS user_id
      FROM rentals r
      JOIN garages g ON g.id = r.garage_id
      JOIN vehicles v ON v.id = r.vehicle_id
      UNION ALL
      SELECT SUBSTR(e.created_at, 1, 10), 0, e.extra_cost,
             g.type, v.user_id
      FROM extensions e
      JOIN rentals r ON r.id = e.rental_id
      JOIN garages g ON g.id = r.garage_id
      JOIN vehicles v ON v.id = r.vehicle_id
    )
  ''';

  static const String _aggregates = '''
    SUM(is_rental) AS rental_count,
    SUM(1 - is_rental) AS extension_count,
    SUM(amount) AS revenue,
    SUM(CASE WHEN is_rental = 1 THEN amount ELSE 0 END) AS rental_revenue,
    SUM(CASE WHEN is_rental = 0 THEN amount ELSE 0 END) AS extension_revenue
  ''';

  /// Laporan Bulanan: pendapatan per bulan dalam satu tahun.
  Future<List<ReportRow>> monthly(int year) => _query('''
      $_transactions
      SELECT STRFTIME('%m', tx_date) AS label, $_aggregates
      FROM tx WHERE STRFTIME('%Y', tx_date) = ?
      GROUP BY label ORDER BY label
    ''', ['$year']);

  /// Laporan Harian: pendapatan per tanggal dalam satu bulan.
  Future<List<ReportRow>> daily(int year, int month) => _query('''
      $_transactions
      SELECT tx_date AS label, $_aggregates
      FROM tx WHERE STRFTIME('%Y-%m', tx_date) = ?
      GROUP BY label ORDER BY label
    ''', ['$year-${month.toString().padLeft(2, '0')}']);

  /// Laporan per Tipe Garasi.
  Future<List<ReportRow>> byGarageType() => _query('''
      $_transactions
      SELECT garage_type AS label, $_aggregates
      FROM tx GROUP BY label ORDER BY revenue DESC
    ''');

  /// Laporan per Penyewa.
  Future<List<ReportRow>> byTenant() => _query('''
      $_transactions
      SELECT u.full_name || ' (' || u.email || ')' AS label, $_aggregates
      FROM tx JOIN users u ON u.id = tx.user_id
      GROUP BY tx.user_id ORDER BY revenue DESC
    ''');

  /// Laporan: pilihan tahun/bulan yang ada transaksinya.
  Future<Map<int, List<int>>> availablePeriods() async {
    final db = await _db.database;
    final rows = await db.rawQuery('''
      $_transactions
      SELECT DISTINCT STRFTIME('%Y-%m', tx_date) AS period
      FROM tx WHERE tx_date IS NOT NULL ORDER BY period DESC
    ''');
    final result = <int, List<int>>{};
    for (final row in rows) {
      final parts = '${row['period']}'.split('-');
      if (parts.length != 2) continue;
      final year = int.tryParse(parts[0]);
      final month = int.tryParse(parts[1]);
      if (year == null || month == null) continue;
      result.putIfAbsent(year, () => []).add(month);
    }
    return result;
  }

  Future<List<ReportRow>> _query(String sql, [List<Object?>? args]) async {
    final db = await _db.database;
    final rows = await db.rawQuery(sql, args);
    return rows.map(ReportRow.fromMap).toList();
  }
}
