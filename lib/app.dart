import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:sewa_garasi/core/constants/app_colors.dart';
import 'package:sewa_garasi/core/theme/app_theme.dart';
import 'package:sewa_garasi/viewmodels/auth_view_model.dart';
import 'package:sewa_garasi/viewmodels/dashboard_view_model.dart';
import 'package:sewa_garasi/viewmodels/garage_view_model.dart';
import 'package:sewa_garasi/viewmodels/rental_view_model.dart';
import 'package:sewa_garasi/viewmodels/report_view_model.dart';
import 'package:sewa_garasi/viewmodels/vehicle_view_model.dart';
import 'package:sewa_garasi/views/auth/login_screen.dart';

/// Aplikasi: daftarkan semua ViewModel ke Provider.
class SewaGarasiApp extends StatelessWidget {
  const SewaGarasiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthViewModel()),
        ChangeNotifierProvider(create: (_) => VehicleViewModel()),
        ChangeNotifierProvider(create: (_) => GarageViewModel()),
        ChangeNotifierProvider(create: (_) => RentalViewModel()),
        ChangeNotifierProvider(create: (_) => ReportViewModel()),
        ChangeNotifierProvider(create: (_) => DashboardViewModel()),
      ],
      child: MaterialApp(
        title: 'Sewa Garasi',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: const LoginScreen(),
      ),
    );
  }
}

/// Logout: keluar akun lalu kembali ke halaman login.
void logout(BuildContext context) {
  context.read<AuthViewModel>().logout();
  Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => const LoginScreen()),
    (_) => false,
  );
}

/// Semua halaman: tampilkan pesan singkat (SnackBar).
void showMessage(BuildContext context, String message, {bool isError = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Row(
        children: [
          Icon(isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(message)),
        ],
      ),
      backgroundColor: isError ? AppColors.danger : AppColors.textPrimary,
    ));
}
