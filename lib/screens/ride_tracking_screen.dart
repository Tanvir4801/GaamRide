import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/booking_models.dart';
import '../services/booking_service.dart';
import '../utils/constants.dart';
import 'ride_complete_screen.dart';

class RideTrackingScreen extends StatefulWidget {
  const RideTrackingScreen({
    required this.bookingId,
    required this.customerLocation,
    super.key,
    this.saathiId,
    this.saathiName,
    this.saathiPhone,
    this.destinationVillage,
    this.otp,
    this.fare,
  });

  final String bookingId;
  final LatLng customerLocation;
  final String? saathiId;
  final String? saathiName;
  final String? saathiPhone;
  final String? destinationVillage;
  final String? otp;
  final double? fare;

  @override
  State<RideTrackingScreen> createState() => _RideTrackingScreenState();
}

class _RideTrackingScreenState extends State<RideTrackingScreen> {
  GoogleMapController? _mapController;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _bookingSubscription;
  Timer? _animationTimer;

  LatLng? _saathiPosition;
  LatLng? _animatedSaathiPosition;
  String _status = BookingStatus.accepted;
  String? _otp;
  double? _fare;
  String _saathiName = '';
  String _saathiPhone = '';

  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  bool _navigatingToComplete = false;

  @override
  void initState() {
    super.initState();
    _saathiName = widget.saathiName ?? 'Gaam Saathi';
    _saathiPhone = widget.saathiPhone ?? '';
    _otp = widget.otp;
    _fare = widget.fare;
    _listenToBooking();
  }

  @override
  void dispose() {
    _bookingSubscription?.cancel();
    _animationTimer?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  void _listenToBooking() {
    _bookingSubscription = FirebaseFirestore.instance
        .collection(AppConstants.bookingsCollection)
        .doc(widget.bookingId)
        .snapshots()
        .listen((snapshot) {
      if (!mounted) return;
      final data = snapshot.data();
      if (data == null) return;

      final status = (data['status'] ?? BookingStatus.accepted).toString();
      final saathiLat = (data['saathiLat'] as num?)?.toDouble();
      final saathiLng = (data['saathiLng'] as num?)?.toDouble();
      final otp = data['otp']?.toString();
      final fare = (data['fare'] as num?)?.toDouble();
      final saathiName = (data['saathiName'] ?? _saathiName).toString();
      final saathiPhone = (data['saathiPhone'] ?? _saathiPhone).toString();

      if (status == BookingStatus.completed && !_navigatingToComplete) {
        _navigatingToComplete = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          Navigator.of(context).pushReplacement(
            MaterialPageRoute<void>(
              builder: (_) => RideCompleteScreen(
                bookingId: widget.bookingId,
                saathiId: widget.saathiId ?? '',
                saathiName: saathiName,
                fare: fare ?? _fare ?? 30.0,
              ),
            ),
          );
        });
        return;
      }

      setState(() {
        _status = status;
        if (otp != null) _otp = otp;
        if (fare != null) _fare = fare;
        _saathiName = saathiName;
        _saathiPhone = saathiPhone;

        if (saathiLat != null && saathiLng != null) {
          final newPos = LatLng(saathiLat, saathiLng);
          if (_animatedSaathiPosition == null) {
            _animatedSaathiPosition = newPos;
            _saathiPosition = newPos;
          } else {
            _animateSaathiMarker(newPos);
          }
          _saathiPosition = newPos;
        }

        _rebuildMapElements();
      });
    });
  }

  /// Smooth marker animation using linear interpolation over 20 steps × 50ms = 1 second
  void _animateSaathiMarker(LatLng newPosition) {
    _animationTimer?.cancel();
    final startPos = _animatedSaathiPosition ?? newPosition;
    const steps = 20;
    int step = 0;

    _animationTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      step++;
      if (step >= steps) {
        timer.cancel();
        if (mounted) {
          setState(() {
            _animatedSaathiPosition = newPosition;
            _rebuildMapElements();
          });
        }
        return;
      }

      final t = step / steps;
      final lat = startPos.latitude +
          (newPosition.latitude - startPos.latitude) * t;
      final lng = startPos.longitude +
          (newPosition.longitude - startPos.longitude) * t;

      if (mounted) {
        setState(() {
          _animatedSaathiPosition = LatLng(lat, lng);
          _rebuildMapElements();
        });
      }
    });
  }

  void _rebuildMapElements() {
    final markers = <Marker>{};

    // Customer marker (blue, static)
    markers.add(Marker(
      markerId: const MarkerId('customer'),
      position: widget.customerLocation,
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
      infoWindow: const InfoWindow(title: 'તમારું સ્થાન / Your Location'),
    ));

    // Saathi marker (green, animated)
    final saathiPos = _animatedSaathiPosition;
    if (saathiPos != null) {
      markers.add(Marker(
        markerId: const MarkerId('saathi'),
        position: saathiPos,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        infoWindow: InfoWindow(title: _saathiName),
      ));

      // Polyline from saathi to customer
      _polylines = {
        Polyline(
          polylineId: const PolylineId('route'),
          points: [saathiPos, widget.customerLocation],
          color: AppColors.primary,
          width: 4,
        ),
      };
    }

    _markers = markers;
  }

  Future<void> _callSaathi() async {
    final phone = _saathiPhone;
    if (phone.isEmpty) return;
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  String _statusLabel() {
    switch (_status) {
      case BookingStatus.accepted:
        return '🛵 સાથી આવી રહ્યા છે / Saathi is on the way';
      case BookingStatus.arriving:
        return '📍 સાથી પહોંચ્યા / Saathi has arrived';
      case BookingStatus.started:
        return '🚀 સવારી શરૂ / Ride in progress';
      default:
        return 'સ્ટેટસ: $_status';
    }
  }

  Color _statusColor() {
    switch (_status) {
      case BookingStatus.arriving:
        return AppColors.warning;
      case BookingStatus.started:
        return AppColors.primaryLight;
      default:
        return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Full-screen map
          GoogleMap(
            onMapCreated: (c) => _mapController = c,
            initialCameraPosition: CameraPosition(
              target: widget.customerLocation,
              zoom: 14,
            ),
            markers: _markers,
            polylines: _polylines,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
          ),

          // Top status bar
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSizes.cardRadius),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: _statusColor(),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _statusLabel(),
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Bottom info card
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildBottomCard(),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(height: 16),

          // Saathi info row
          Row(
            children: [
              CircleAvatar(
                backgroundColor: AppColors.primarySurface,
                radius: 26,
                child: const Icon(
                  Icons.directions_bike,
                  color: AppColors.primary,
                  size: 26,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _saathiName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      widget.destinationVillage != null
                          ? '→ ${widget.destinationVillage}'
                          : 'GaamRide',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (_fare != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primarySurface,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '₹${_fare!.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                      fontSize: 15,
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 16),

          // OTP section (shown when saathi has arrived)
          if (_status == BookingStatus.arriving && _otp != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.warning, width: 1.5),
              ),
              child: Column(
                children: [
                  const Text(
                    'OTP સાથીને આપો / Share OTP with Saathi',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _otp!,
                    style: const TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w900,
                      color: AppColors.warning,
                      letterSpacing: 8,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Call button
          if (_saathiPhone.isNotEmpty)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _callSaathi,
                icon: const Icon(Icons.phone, size: 18),
                label: const Text('સાથીને કૉલ કરો / Call Saathi'),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.primary),
                  foregroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSizes.buttonRadius),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
