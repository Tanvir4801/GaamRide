import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../services/location_service.dart';
import '../utils/constants.dart';
import 'ride_tracking_screen.dart';

/// Legacy tracking screen — redirects to the new RideTrackingScreen.
/// Kept for backward compatibility with any existing navigation references.
class TrackingScreen extends StatelessWidget {
  const TrackingScreen({
    required this.bookingId,
    super.key,
    this.saathiId,
    this.saathiName,
  });

  final String bookingId;
  final String? saathiId;
  final String? saathiName;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection(AppConstants.bookingsCollection)
          .doc(bookingId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final data = snapshot.data?.data();
        final pickupLat = (data?['pickupLat'] as num?)?.toDouble();
        final pickupLng = (data?['pickupLng'] as num?)?.toDouble();
        final otp = data?['otp']?.toString();
        final fare = (data?['fare'] as num?)?.toDouble();
        final resolvedSaathiId = (data?['saathiId'] ?? saathiId ?? '').toString();
        final resolvedSaathiName = (data?['saathiName'] ?? saathiName ?? 'Gaam Saathi').toString();
        final saathiPhone = (data?['saathiPhone'] ?? '').toString();
        final destination = (data?['destinationVillage'] ?? '').toString();

        final customerLocation = (pickupLat != null && pickupLng != null)
            ? LatLng(pickupLat, pickupLng)
            : LocationService.serviceCenter;

        return RideTrackingScreen(
          bookingId: bookingId,
          customerLocation: customerLocation,
          saathiId: resolvedSaathiId,
          saathiName: resolvedSaathiName,
          saathiPhone: saathiPhone,
          destinationVillage: destination.isNotEmpty ? destination : null,
          otp: otp,
          fare: fare,
        );
      },
    );
  }
}
