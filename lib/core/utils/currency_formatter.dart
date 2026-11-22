import 'package:intl/intl.dart';

/// Tampilan: format angka ke Rupiah (125000 -> "Rp125.000").
class CurrencyFormatter {
  CurrencyFormatter._();

  static final NumberFormat _rupiah = NumberFormat.currency(
    locale: 'id',
    symbol: 'Rp',
    decimalDigits: 0,
  );

  static String rupiah(num value) => _rupiah.format(value);
}
