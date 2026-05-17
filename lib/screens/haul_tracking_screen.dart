import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/booking_models.dart';
import '../utils/constants.dart';

class HaulTrackingScreen extends StatefulWidget {
  const HaulTrackingScreen({
    required this.bookingId,
    required this.customerLocation,
    super.key,
    this.vehicleOwnerId,
    this.ownerName,
    this.ownerPhone,
    this.vehicleType,
    this.destinationVillage,
    this.totalFare,
  });

  final String bookingId;
  final LatLng customerLocation;
  final String? vehicleOwnerId;
  final String? ownerName;
  final String? ownerPhone;
  final String? vehicleType;
  final String? destinationVillage;
  final double? totalFare;

  static const Color _orange = Color(0xFFE65100);

  @override
  State<HaulTrackingScreen> createState() => _HaulTrackingScreenState();
}

class _HaulTrackingScreenState extends State<HaulTrackingScreen> {
  GoogleMapController? _mapController;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _bookingSub;
  Timer? _animationTimer;

  LatLng? _animatedOwnerPosition;
  String _status = BookingStatus.accepted;
  String _ownerName = '';
  String _ownerPhone = '';

  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};

  @override
  void initState() {
    super.initState();
    _ownerName = widget.ownerName ?? 'Vehicle Owner';
    _ownerPhone = widget.ownerPhone ?? '';
    _listenToBooking();
  }

  @override
  void dispose() {
    _bookingSub?.cancel();
    _animationTimer?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  void _listenToBooking() {
    _bookingSub = FirebaseFirestore.instance
        .collection(AppConstants.bookingsCollection)
        .doc(widget.bookingId)
        .snapshots()
        .listen((snap) {
      if (!mounted) return;
      final data = snap.data();
      if (data == null) return;

      final status = (data['status'] ?? BookingStatus.accepted).toString();
      final ownerLat = (data['saathiLat'] as num?)?.toDouble();
      final ownerLng = (data['saathiLng'] as num?)?.toDouble();
      final ownerName = (data['saathiName'] ?? _ownerName).toString();
      final ownerPhone = (data['saathiPhone'] ?? _ownerPhone).toString();

      if (status == BookingStatus.completed) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Haul completed! / વાહન સેવા પૂર્ણ!'),
              backgroundColor: HaulTrackingScreen._orange,
            ),
          );
          Navigator.of(context).pop();
        }
        return;
      }

      setState(() {
        _status = status;
        _ownerName = ownerName;
        _ownerPhone = ownerPhone;

        if (ownerLat != null && ownerLng != null) {
          final newPos = LatLng(ownerLat, ownerLng);
          if (_animatedOwnerPosition == null) {
            _animatedOwnerPosition = newPos;
          } else {
            _animateOwnerMarker(newPos);
          }
        }
        _rebuildMapElements();
      });
    });
  }

  void _animateOwnerMarker(LatLng newPosition) {
    _animationTimer?.cancel();
    final startPos = _animatedOwnerPosition ?? newPosition;
    const steps = 20;
    int step = 0;

    _animationTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      step++;
      if (step >= steps) {
        timer.cancel();
        if (mounted) {
          setState(() {
            _animatedOwnerPosition = newPosition;
            _rebuildMapElements();
          });
        }
        return;
      }

      final t = step / steps;
      final lat =
          startPos.latitude + (newPosition.latitude - startPos.latitude) * t;
      final lng =
          startPos.longitude + (newPosition.longitude - startPos.longitude) * t;

      if (mounted) {
        setState(() {
          _animatedOwnerPosition = LatLng(lat, lng);
          _rebuildMapElements();
        });
      }
    });
  }

  void _rebuildMapElements() {
    final markers = <Marker>{};

    markers.add(Marker(
      markerId: const MarkerId('customer'),
      position: widget.customerLocation,
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
      infoWindow: const InfoWindow(title: 'Pickup'),
    ));

    final ownerPos = _animatedOwnerPosition;
    if (ownerPos != null) {
      markers.add(Marker(
        markerId: const MarkerId('owner'),
        position: ownerPos,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
        infoWindow: InfoWindow(title: _ownerName),
      ));

      _polylines = {
        Polyline(
          polylineId: const PolylineId('haul_route'),
          points: [ownerPos, widget.customerLocation],
          color: HaulTrackingScreen._orange,
          width: 4,
        ),
      };
    }

    _markers = markers;
  }

  Future<void> _callOwner() async {
    final phone = _ownerPhone;
    if (phone.isEmpty) return;
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  String _vehicleIcon() {
    final v = (widget.vehicleType ?? '').toLowerCase();
    if (v.contains('tractor')) return '🚜';
    if (v.contains('pickup')) return '🛻';
    if (v.contains('truck') || v.contains('407')) return '🚛';
    return '🚚';
  }

  String _statusLabel() {
    switch (_status) {
      case BookingStatus.accepted:
        return '${_vehicleIcon()} વાહન આવી રહ્યું છે / Vehicle on the way';
      case BookingStatus.arriving:
        return '📍 વાહન પહોંચ્યું / Vehicle has arrived';
      case BookingStatus.started:
        return '🚀 Haul in progress';
      default:
        return 'Status: $_status';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
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

          // Top status
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSizes.cardRadius),
                ),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          color: HaulTrackingScreen._orange,
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

          // Bottom card
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
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
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor:
                            HaulTrackingScreen._orange.withValues(alpha: 0.12),
                        radius: 26,
                        child: Text(
                          _vehicleIcon(),
                          style: const TextStyle(fontSize: 22),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _ownerName,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              widget.vehicleType ?? 'Vehicle',
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (widget.totalFare != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: HaulTrackingScreen._orange
                                .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '₹${widget.totalFare!.toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              color: HaulTrackingScreen._orange,
                              fontSize: 15,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (_ownerPhone.isNotEmpty)
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _callOwner,
                        icon: const Icon(Icons.phone, size: 18),
                        label: const Text('વાહન માલિકને કૉલ / Call Owner'),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(
                              color: HaulTrackingScreen._orange),
                          foregroundColor: HaulTrackingScreen._orange,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(AppSizes.buttonRadius),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
