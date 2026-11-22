import 'package:flutter/material.dart';

import 'package:sewa_garasi/core/constants/app_colors.dart';
import 'package:sewa_garasi/core/constants/enums.dart';

extension VehicleTypeIcon on VehicleType {
  IconData get icon => switch (this) {
        VehicleType.bicycle => Icons.pedal_bike,
        VehicleType.motorcycle => Icons.two_wheeler,
        VehicleType.car => Icons.directions_car,
        VehicleType.electricCar => Icons.electric_car,
      };

  (Color, Color) get colors => switch (this) {
        VehicleType.electricCar => (AppColors.success, AppColors.successLight),
        _ => (AppColors.primary, AppColors.primaryLight),
      };
}

extension GarageTypeIcon on GarageType {
  IconData get icon => switch (this) {
        GarageType.bicycle => Icons.pedal_bike,
        GarageType.car => Icons.directions_car_outlined,
        GarageType.electric => Icons.electric_car_outlined,
      };

  (Color, Color) get colors => switch (this) {
        GarageType.bicycle => (AppColors.warning, AppColors.warningLight),
        GarageType.car => (AppColors.primary, AppColors.primaryLight),
        GarageType.electric => (AppColors.success, AppColors.successLight),
      };
}
