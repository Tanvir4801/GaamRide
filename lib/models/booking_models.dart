class BookingType {
  static const String ride = 'ride';
  static const String haul = 'haul';
}

class BookingStatus {
  static const String pending = 'pending';
  static const String searching = pending;
  static const String accepted = 'accepted';
  static const String rejected = 'rejected';
  static const String completed = 'completed';
  static const String cancelled = 'cancelled';
}

class DriverRequestStatus {
  static const String pending = 'pending';
  static const String accepted = 'accepted';
  static const String rejected = 'rejected';
}

class CreateBookingInput {
  const CreateBookingInput({
    required this.type,
    required this.userId,
    required this.pickupLat,
    required this.pickupLng,
    required this.destinationVillage,
    this.vehicleType,
    this.durationLabel,
    this.loadDescription,
    this.radiusKm,
  });

  final String type;
  final String userId;
  final double pickupLat;
  final double pickupLng;
  final String destinationVillage;
  final String? vehicleType;
  final String? durationLabel;
  final String? loadDescription;
  final double? radiusKm;
}

class BookingCreateResult {
  const BookingCreateResult({
    required this.bookingId,
    required this.notifiedDriverCount,
  });

  final String bookingId;
  final int notifiedDriverCount;
}
