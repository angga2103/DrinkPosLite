import 'dart:convert';
import 'package:crypto/crypto.dart';

class PinSecurity {
  static const String _defaultSalt = 'drinkpos_lite_salt_2026_ansor_studi';

  /// Hash a 4 to 6 digit numeric PIN with salt using SHA-256
  static String hashPin(String pin, {String salt = _defaultSalt}) {
    final bytes = utf8.encode('$salt:$pin');
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Verify if an entered PIN matches the stored hash
  static bool verifyPin(String enteredPin, String storedHash, {String salt = _defaultSalt}) {
    final computedHash = hashPin(enteredPin, salt: salt);
    return computedHash == storedHash;
  }
}
