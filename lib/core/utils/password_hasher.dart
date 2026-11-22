import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Registrasi & Login: hash password SHA-256 agar tidak disimpan asli.
class PasswordHasher {
  PasswordHasher._();

  static const String _salt = 'sewa-garasi::';

  static String hash(String password) {
    final bytes = utf8.encode('$_salt$password');
    return sha256.convert(bytes).toString();
  }

  static bool verify(String password, String hashed) =>
      hash(password) == hashed;
}
