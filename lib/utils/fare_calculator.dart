class FareCalculator {
  static const double _rideBaseFare = 20.0;
  static const double _ridePerKmRate = 8.0;
  static const double _rideMinimumFare = 30.0;
  static const double _haulAppCommission = 75.0;

  static const Map<String, double> _durationHours = {
    '1_hour': 1.0,
    '2_hours': 2.0,
    'half_day': 4.0,
    'full_day': 8.0,
  };

  /// Calculates ride fare for GaamRide (person transport)
  /// ₹20 base + ₹8/km, minimum ₹30
  static double calculateRideFare(double distanceKm) {
    final fare = _rideBaseFare + (distanceKm * _ridePerKmRate);
    return fare < _rideMinimumFare ? _rideMinimumFare : fare;
  }

  /// App commission for GaamHaul booking
  /// Customer pays flat ₹75 to app; owner gets paid directly
  static double calculateHaulCommission() => _haulAppCommission;

  /// Total estimated cost for the vehicle owner's service
  /// Used to show fare estimate to customer before booking
  static double calculateHaulOwnerFare(int ratePerHour, String durationKey) {
    final hours = _durationHours[durationKey] ?? 1.0;
    return ratePerHour * hours;
  }

  /// Formatted fare string for display
  static String formatFare(double amount) => '₹${amount.toStringAsFixed(0)}';

  /// ETA in minutes based on distance and assumed speed
  static int etaMinutesForRide(double distanceKm, {double speedKmh = 25}) {
    return ((distanceKm / speedKmh) * 60).round().clamp(1, 999);
  }

  static int etaMinutesForHaul(double distanceKm, {double speedKmh = 30}) {
    return ((distanceKm / speedKmh) * 60).round().clamp(1, 999);
  }
}
