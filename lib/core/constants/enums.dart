library;

/// Login: peran pengguna (admin / penyewa).
enum UserRole {
  admin('Admin'),
  tenant('Penyewa');

  const UserRole(this.label);
  final String label;
}

/// Verifikasi Penyewa: status pendaftaran.
enum UserStatus {
  pending('Menunggu Verifikasi'),
  approved('Diterima'),
  rejected('Ditolak');

  const UserStatus(this.label);
  final String label;
}

/// Kelola Garasi: tipe garasi dan huruf ID-nya (S, C, E).
enum GarageType {
  bicycle('Garasi Sepeda', 'S'),
  car('Garasi Mobil', 'C'),
  electric('Garasi Mobil Listrik', 'E');

  const GarageType(this.label, this.idPrefix);
  final String label;
  final String idPrefix;
}

/// Kendaraan Penyewa: tipe kendaraan dan garasi yang boleh ditempati.
enum VehicleType {
  bicycle('Sepeda', [GarageType.bicycle]),
  motorcycle('Sepeda Motor', [GarageType.bicycle]),
  car('Mobil', [GarageType.car]),
  electricCar('Mobil Listrik', [GarageType.car, GarageType.electric]);

  const VehicleType(this.label, this.allowedGarageTypes);
  final String label;

  final List<GarageType> allowedGarageTypes;

  bool get requiresPlate => this != VehicleType.bicycle;

  bool get hasBattery => this == VehicleType.electricCar;
}

/// Status Garasi: tersedia / terpakai.
enum GarageStatus {
  available('Tersedia'),
  used('Digunakan');

  const GarageStatus(this.label);
  final String label;
}

/// Sewa Garasi: jenis sewa harian / bulanan.
enum RentalType {
  daily('Harian'),
  monthly('Bulanan');

  const RentalType(this.label);
  final String label;
}
