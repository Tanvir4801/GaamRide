import 'package:google_maps_flutter/google_maps_flutter.dart';

class BookingType {
  static const String ride = 'ride';
  static const String haul = 'haul';
}

class BookingStatus {
  static const String pending = 'pending';
  static const String searching = pending;
  static const String accepted = 'accepted';
  static const String arriving = 'arriving';
  static const String started = 'started';
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
    this.customerName,
    this.customerPhone,
    this.vehicleType,
    this.durationLabel,
    this.loadDescription,
    this.radiusKm,
    this.otp,
    this.fare,
  });

  final String type;
  final String userId;
  final double pickupLat;
  final double pickupLng;
  final String destinationVillage;
  final String? customerName;
  final String? customerPhone;
  final String? vehicleType;
  final String? durationLabel;
  final String? loadDescription;
  final double? radiusKm;
  final String? otp;
  final double? fare;
}

class BookingCreateResult {
  const BookingCreateResult({
    required this.bookingId,
    required this.notifiedDriverCount,
    this.otp,
    this.fare,
  });

  final String bookingId;
  final int notifiedDriverCount;
  final String? otp;
  final double? fare;
}

class ActiveBookingInfo {
  const ActiveBookingInfo({
    required this.bookingId,
    required this.status,
    required this.saathiId,
    required this.saathiName,
    required this.saathiPhone,
    required this.pickupLocation,
    required this.destinationVillage,
    this.saathiPosition,
    this.otp,
    this.fare,
    this.distance,
  });

  final String bookingId;
  final String status;
  final String saathiId;
  final String saathiName;
  final String saathiPhone;
  final LatLng pickupLocation;
  final String destinationVillage;
  final LatLng? saathiPosition;
  final String? otp;
  final double? fare;
  final double? distance;

  factory ActiveBookingInfo.fromMap(
    String bookingId,
    Map<String, dynamic> data,
  ) {
    final saathiLat = (data['saathiLat'] as num?)?.toDouble();
    final saathiLng = (data['saathiLng'] as num?)?.toDouble();

    return ActiveBookingInfo(
      bookingId: bookingId,
      status: (data['status'] ?? BookingStatus.accepted).toString(),
      saathiId: (data['saathiId'] ?? data['driverId'] ?? '').toString(),
      saathiName: (data['saathiName'] ?? 'Gaam Saathi').toString(),
      saathiPhone: (data['saathiPhone'] ?? '').toString(),
      pickupLocation: LatLng(
        (data['pickupLat'] as num?)?.toDouble() ?? 0,
        (data['pickupLng'] as num?)?.toDouble() ?? 0,
      ),
      destinationVillage: (data['destinationVillage'] ?? '').toString(),
      saathiPosition: (saathiLat != null && saathiLng != null)
          ? LatLng(saathiLat, saathiLng)
          : null,
      otp: data['otp']?.toString(),
      fare: (data['fare'] as num?)?.toDouble(),
      distance: (data['distance'] as num?)?.toDouble(),
    );
  }
}
