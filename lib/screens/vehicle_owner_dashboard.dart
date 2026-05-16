import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geoflutterfire_plus/geoflutterfire_plus.dart';
import 'package:geolocator/geolocator.dart';

import '../models/booking_models.dart';
import '../services/booking_service.dart';
import '../utils/constants.dart';
import 'vehicle_register_screen.dart';

class VehicleOwnerDashboard extends StatefulWidget {
  const VehicleOwnerDashboard({
    required this.vehicleDocId,
    this.onSwitchToSearch,
    super.key,
  });

  final String vehicleDocId;
  final VoidCallback? onSwitchToSearch;

  @override
  State<VehicleOwnerDashboard> createState() => _VehicleOwnerDashboardState();
}

class _VehicleOwnerDashboardState extends State<VehicleOwnerDashboard> {
  static const Color _orange = Color(0xFFE65100);
  bool _isUpdatingAvailability = false;
  String? _updatingRequestId;
  String? _lastAlertedRequestId;

  String _vehicleTypeLabel(String value) {
    switch (value) {
      case 'mini_tempo':
        return 'મિની ટેમ્પો';
      case 'pickup':
        return 'પિકઅપ ટ્રક';
      case 'tractor':
        return 'ટ્રેક્ટર';
      default:
        return value;
    }
  }

  Future<GeoFirePoint?> _currentGeoPoint() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return null;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return null;
    }

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
    return GeoFirePoint(GeoPoint(position.latitude, position.longitude));
  }

  Future<void> _updateAvailability(bool value) async {
    if (_isUpdatingAvailability) return;

    setState(() {
      _isUpdatingAvailability = true;
    });

    try {
      final payload = <String, dynamic>{
        'isAvailable': value,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (value) {
        final point = await _currentGeoPoint();
        if (point != null) {
          payload['position'] = point.data;
        }
      }

      await FirebaseFirestore.instance
          .collection('haul_vehicles')
          .doc(widget.vehicleDocId)
          .set(payload, SetOptions(merge: true));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ઉપલબ્ધતા અપડેટ થઈ નથી / Failed to update availability'),
        ),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        _isUpdatingAvailability = false;
      });
    }
  }

  Future<void> _openEditScreen() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const VehicleRegisterScreen(),
      ),
    );
  }

  Widget _buildStatCard(String title, String subtitle, String count) {
    return Expanded(
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: Colors.black.withValues(alpha: 0.08)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                count,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _updateRequestStatus({
    required String requestId,
    required bool accept,
    required String saathiName,
  }) async {
    if (_updatingRequestId != null) return;

    setState(() {
      _updatingRequestId = requestId;
    });

    try {
      if (accept) {
        await BookingService.acceptDriverRequest(
          requestId: requestId,
          driverId: widget.vehicleDocId,
          saathiName: saathiName,
        );
      } else {
        await BookingService.rejectDriverRequest(requestId);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            accept
                ? 'બુકિંગ સ્વીકાર્યું / Booking accepted'
                : 'બુકિંગ નકાર્યું / Booking rejected',
          ),
        ),
      );
    } on AlreadyAcceptedException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('આ બુકિંગ પહેલેથી સ્વીકારાઈ ગયું / Already accepted'),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('રીક્વેસ્ટ અપડેટ થઈ નથી / Failed to update request'),
        ),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        _updatingRequestId = null;
      });
    }
  }

  Widget _buildIncomingRequestCard(GeoPoint? ownerGeoPoint, String ownerName) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('driver_requests')
          .where('driverId', isEqualTo: widget.vehicleDocId)
          .where('status', isEqualTo: DriverRequestStatus.pending)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }

        final docs = [...snapshot.data!.docs];
        docs.sort((a, b) {
          final aTs = (a.data()['timestamp'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
          final bTs = (b.data()['timestamp'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
          return bTs.compareTo(aTs);
        });

        final request = docs.first;
        final requestData = request.data();
        final bookingId = (requestData['bookingId'] ?? '').toString();
        if (bookingId.isEmpty) {
          return const SizedBox.shrink();
        }

        if (_lastAlertedRequestId != request.id) {
          _lastAlertedRequestId = request.id;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            HapticFeedback.mediumImpact();
          });
        }

        return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          future: FirebaseFirestore.instance
              .collection('bookings')
              .doc(bookingId)
              .get(),
          builder: (context, bookingSnapshot) {
            final bookingData = bookingSnapshot.data?.data();
            if (bookingData == null ||
                (bookingData['status']?.toString() ?? '') !=
                    BookingStatus.searching) {
              return const SizedBox.shrink();
            }

            final pickupLat = (bookingData['pickupLat'] as num?)?.toDouble();
            final pickupLng = (bookingData['pickupLng'] as num?)?.toDouble();
            final destinationVillage =
                (bookingData['destinationVillage'] ?? '').toString();
            final isUpdating = _updatingRequestId == request.id;

            String? etaText;
            if (pickupLat != null && pickupLng != null && ownerGeoPoint != null) {
              final distanceMeters = Geolocator.distanceBetween(
                ownerGeoPoint.latitude,
                ownerGeoPoint.longitude,
                pickupLat,
                pickupLng,
              );
              final distanceKm = distanceMeters / 1000;
              final etaMinutes = ((distanceKm / 30) * 60).round();
              etaText =
                  '${distanceKm.toStringAsFixed(1)} km · ~$etaMinutes min to pickup';
            }

            return Card(
              margin: const EdgeInsets.only(bottom: 16),
              elevation: 4,
              color: _orange.withValues(alpha: 0.08),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'નવી Haul વિનંતી / New Haul Request',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                    ),
                    const SizedBox(height: 6),
                    Text('ગંતવ્ય / Destination: $destinationVillage'),
                    if (pickupLat != null && pickupLng != null)
                      Text(
                        'Pickup: ${pickupLat.toStringAsFixed(4)}, ${pickupLng.toStringAsFixed(4)}',
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                    if (etaText != null)
                      Text(
                        etaText,
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: isUpdating
                                ? null
                                : () => _updateRequestStatus(
                                      requestId: request.id,
                                      accept: true,
                                  saathiName: ownerName,
                                    ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.success,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Accept'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: isUpdating
                                ? null
                                : () => _updateRequestStatus(
                                      requestId: request.id,
                                      accept: false,
                                  saathiName: ownerName,
                                    ),
                            child: const Text(
                              'Reject',
                              style: TextStyle(color: AppColors.error),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: _orange,
        foregroundColor: Colors.white,
        title: const Text('GaamHaul'),
        actions: [
          if (widget.onSwitchToSearch != null)
            TextButton(
              onPressed: widget.onSwitchToSearch,
              child: const Text(
                'શોધો / Search',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
              ),
            ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('haul_vehicles')
            .doc(widget.vehicleDocId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data?.data();
          if (data == null) {
            return const Center(
              child: Text('વાહન માહિતી મળી નથી / Vehicle info not found'),
            );
          }

          final isAvailable = data['isAvailable'] as bool? ?? false;
          final vehicleType = _vehicleTypeLabel((data['vehicleType'] ?? '').toString());
          final capacity = (data['capacity'] ?? '').toString();
          final ratePerHour = (data['ratePerHour'] ?? 0).toString();
          final position = data['position'];
          GeoPoint? ownerGeoPoint;
          if (position is Map<String, dynamic>) {
            final geo = position['geopoint'];
            if (geo is GeoPoint) {
              ownerGeoPoint = geo;
            }
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppSizes.defaultPadding),
            child: Column(
              children: [
                _buildIncomingRequestCard(
                  ownerGeoPoint,
                  (data['ownerName'] ?? data['name'] ?? 'Saathi').toString(),
                ),
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(color: Colors.black.withValues(alpha: 0.08)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'ઉપલબ્ધ છો? / Available now?',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                isAvailable
                                    ? 'હા, બુકિંગ મળી શકે'
                                    : 'ઑફલાઇન',
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IgnorePointer(
                          ignoring: _isUpdatingAvailability,
                          child: Switch(
                            value: isAvailable,
                            activeColor: _orange,
                            onChanged: _updateAvailability,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _buildStatCard('આ મહિને', 'This month', '0'),
                    const SizedBox(width: 10),
                    _buildStatCard('કુલ', 'Total', '0'),
                  ],
                ),
                const SizedBox(height: 16),
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(color: Colors.black.withValues(alpha: 0.08)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          vehicleType,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '₹$ratePerHour/કલાક · $capacity',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton(
                            onPressed: _openEditScreen,
                            child: const Text('માહિતી બદલો / Edit'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}