import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sewa_garasi/app.dart';

/// Smoke test: aplikasi terbuka di halaman login.
void main() {
  /// Test: Aplikasi pertama kali dibuka.
  testWidgets('aplikasi menampilkan halaman login', (tester) async {
    await tester.pumpWidget(const SewaGarasiApp());
    expect(find.text('Sewa Garasi'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Login'), findsOneWidget);
    expect(
        find.text('Belum punya akun? Daftar sebagai Penyewa'), findsOneWidget);
  });
}
