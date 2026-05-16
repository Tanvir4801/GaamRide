import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../utils/constants.dart';

class TrackingScreen extends StatelessWidget {
  const TrackingScreen({
    required this.bookingId,
    this.saathiId,
    this.saathiName,
    super.key,
  });

  final String bookingId;
  final String? saathiId;
  final String? saathiName;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tracking'),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('bookings').doc(bookingId).snapshots(),
        builder: (context, bookingSnapshot) {
          final bookingData = bookingSnapshot.data?.data();
          final bookingStatus = bookingData?['status']?.toString() ?? 'pending';
          final assignedSaathiId = (bookingData?['saathiId'] ?? saathiId ?? '').toString();
          final assignedSaathiName = (bookingData?['saathiName'] ?? saathiName ?? 'Gaam Saathi').toString();

          if (assignedSaathiId.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Tracking will appear after the booking is accepted.\nCurrent status: $bookingStatus',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance.collection('saathis').doc(assignedSaathiId).snapshots(),
            builder: (context, saathiSnapshot) {
              final saathiData = saathiSnapshot.data?.data();
              final position = saathiData?['position'];
              GeoPoint? geoPoint;
              if (position is Map<String, dynamic>) {
                final value = position['geopoint'];
                if (value is GeoPoint) {
                  geoPoint = value;
                }
              }

              final pickupLat = (bookingData?['pickupLat'] as num?)?.toDouble();
              final pickupLng = (bookingData?['pickupLng'] as num?)?.toDouble();

              final markers = <Marker>{};
              if (geoPoint != null) {
                markers.add(
                  Marker(
                    markerId: const MarkerId('saathi'),
                    position: LatLng(geoPoint.latitude, geoPoint.longitude),
                    infoWindow: InfoWindow(title: assignedSaathiName),
                  ),
                );
              }
              if (pickupLat != null && pickupLng != null) {
                markers.add(
                  Marker(
                    markerId: const MarkerId('pickup'),
                    position: LatLng(pickupLat, pickupLng),
                    infoWindow: const InfoWindow(title: 'Pickup'),
                  ),
                );
              }

              final initialCameraPosition = geoPoint != null
                  ? CameraPosition(
                      target: LatLng(geoPoint.latitude, geoPoint.longitude),
                      zoom: 14,
                    )
                  : const CameraPosition(
                      target: LatLng(20.8306, 73.2469),
                      zoom: 12,
                    );

              return Column(
                children: [
                  Container(
                    width: double.infinity,
                    color: AppColors.primary,
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      '$assignedSaathiName is on the way',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  Expanded(
                    child: GoogleMap(
                      initialCameraPosition: initialCameraPosition,
                      markers: markers,
                      myLocationButtonEnabled: false,
                      zoomControlsEnabled: false,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Status: $bookingStatus',
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 6),
                            Text('Saathi: $assignedSaathiName'),
                            if (geoPoint != null) ...[
                              const SizedBox(height: 6),
                              Text(
                                'Current location: ${geoPoint.latitude.toStringAsFixed(4)}, ${geoPoint.longitude.toStringAsFixed(4)}',
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}