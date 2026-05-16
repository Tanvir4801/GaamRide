import 'dart:math';

class OtpGenerator {
  static final Random _random = Random.secure();

  /// Generate a random 4-digit OTP string (1000–9999)
  static String generate() => (1000 + _random.nextInt(9000)).toString();

  /// Verify that the entered OTP matches the stored one
  static bool verify(String entered, String stored) {
    return entered.trim() == stored.trim();
  }
}
