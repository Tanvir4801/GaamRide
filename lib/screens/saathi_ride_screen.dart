import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/booking_models.dart';
import '../services/booking_service.dart';
import '../services/location_service.dart';
import '../utils/constants.dart';

class SaathiRideScreen extends StatefulWidget {
  const SaathiRideScreen({
    required this.bookingId,
    required this.saathiId,
    required this.saathiName,
    super.key,
    this.customerLat,
    this.customerLng,
    this.customerName,
    this.customerPhone,
    this.destinationVillage,
    this.fareAmount,
  });

  final String bookingId;
  final String saathiId;
  final String saathiName;
  final double? customerLat;
  final double? customerLng;
  final String? customerName;
  final String? customerPhone;
  final String? destinationVillage;
  final double? fareAmount;

  @override
  State<SaathiRideScreen> createState() => _SaathiRideScreenState();
}

class _SaathiRideScreenState extends State<SaathiRideScreen> {
  GoogleMapController? _mapController;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _bookingSub;

  String _status = BookingStatus.accepted;
  String _otpInput = '';
  bool _isVerifyingOtp = false;
  bool _isCompleting = false;
  bool _isMarkingArrived = false;

  LatLng? _customerPosition;
  LatLng? _saathiPosition;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};

  final TextEditingController _otpController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.customerLat != null && widget.customerLng != null) {
      _customerPosition = LatLng(widget.customerLat!, widget.customerLng!);
    }
    _startParallelLocationUpdates();
    _listenToBooking();
  }

  @override
  void dispose() {
    _bookingSub?.cancel();
    LocationService.stopRideLocationUpdates();
    _mapController?.dispose();
    _otpController.dispose();
    super.dispose();
  }

  /// Start parallel location updates: every 5 seconds updates both ride doc and saathis collection
  void _startParallelLocationUpdates() {
    LocationService.startRideLocationUpdates(
      bookingId: widget.bookingId,
      saathiId: widget.saathiId,
      intervalSeconds: 5,
      onUpdate: (lat, lng) {
        if (!mounted) return;
        setState(() {
          _saathiPosition = LatLng(lat, lng);
          _rebuildMapElements();
        });
      },
    );
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
      setState(() {
        _status = status;
      });

      if (status == BookingStatus.completed) {
        LocationService.stopRideLocationUpdates();
        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('સવારી પૂર્ણ! / Ride completed!')),
          );
        }
      }
    });
  }

  void _rebuildMapElements() {
    final markers = <Marker>{};
    if (_customerPosition != null) {
      markers.add(Marker(
        markerId: const MarkerId('customer'),
        position: _customerPosition!,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        infoWindow: InfoWindow(title: widget.customerName ?? 'Customer'),
      ));
    }
    if (_saathiPosition != null) {
      markers.add(Marker(
        markerId: const MarkerId('saathi'),
        position: _saathiPosition!,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        infoWindow: InfoWindow(title: widget.saathiName),
      ));
    }
    if (_customerPosition != null && _saathiPosition != null) {
      _polylines = {
        Polyline(
          polylineId: const PolylineId('route'),
          points: [_saathiPosition!, _customerPosition!],
          color: AppColors.primary,
          width: 4,
        ),
      };
    } else {
      _polylines = {};
    }
    _markers = markers;
  }

  Future<void> _markArrived() async {
    if (_isMarkingArrived) return;
    setState(() => _isMarkingArrived = true);
    try {
      await BookingService.markSaathiArriving(widget.bookingId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ગ્રાહક સ્થળ પર પહોંચ્યા / Arrived at customer')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error updating status')),
        );
      }
    } finally {
      if (mounted) setState(() => _isMarkingArrived = false);
    }
  }

  Future<void> _verifyOtp() async {
    final otp = _otpController.text.trim();
    if (otp.length != 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('4 અંકનો OTP દાખલ કરો / Enter 4-digit OTP')),
      );
      return;
    }

    setState(() => _isVerifyingOtp = true);
    try {
      final success = await BookingService.verifyOtpAndStartRide(
        bookingId: widget.bookingId,
        enteredOtp: otp,
      );

      if (!mounted) return;
      if (success) {
        HapticFeedback.mediumImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('OTP સાચો! સવારી શરૂ / OTP verified! Ride started'),
            backgroundColor: AppColors.success,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ખોટો OTP / Wrong OTP, try again'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('OTP verification failed')),
        );
      }
    } finally {
      if (mounted) setState(() => _isVerifyingOtp = false);
    }
  }

  Future<void> _completeRide() async {
    if (_isCompleting) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('સવારી પૂર્ણ કરો?'),
        content: const Text(
          'શું ગ્રાહક ગંતવ્ય પર પહોંચ્યા?\nIs the customer at destination?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('ના / No'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('હા, પૂર્ણ / Yes, Complete'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() => _isCompleting = true);
    try {
      await BookingService.completeRide(
        bookingId: widget.bookingId,
        saathiId: widget.saathiId,
      );
      LocationService.stopRideLocationUpdates();
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('સવારી પૂર્ણ કરવામાં ભૂલ / Error completing ride')),
        );
      }
    } finally {
      if (mounted) setState(() => _isCompleting = false);
    }
  }

  Future<void> _callCustomer() async {
    final phone = widget.customerPhone ?? '';
    if (phone.isEmpty) return;
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  @override
  Widget build(BuildContext context) {
    final mapCenter = _customerPosition ?? LocationService.serviceCenter;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: const Text('સવારી / Ride'),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Map (expandable)
          Expanded(
            flex: 2,
            child: GoogleMap(
              onMapCreated: (c) {
                _mapController = c;
                _rebuildMapElements();
              },
              initialCameraPosition: CameraPosition(target: mapCenter, zoom: 14),
              markers: _markers,
              polylines: _polylines,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
            ),
          ),

          // Bottom controls
          Expanded(
            flex: 3,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSizes.defaultPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Customer info card
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppSizes.cardRadius),
                      side: const BorderSide(color: AppColors.border),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          const CircleAvatar(
                            backgroundColor: AppColors.primarySurface,
                            child: Icon(Icons.person, color: AppColors.primary),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.customerName ?? 'Customer',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16,
                                  ),
                                ),
                                if (widget.destinationVillage != null)
                                  Text(
                                    '→ ${widget.destinationVillage}',
                                    style: const TextStyle(color: AppColors.textSecondary),
                                  ),
                              ],
                            ),
                          ),
                          if (widget.fareAmount != null)
                            Text(
                              '₹${widget.fareAmount!.toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 18,
                                color: AppColors.primary,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Status-based action buttons
                  if (_status == BookingStatus.accepted) ...[
                    ElevatedButton.icon(
                      onPressed: _isMarkingArrived ? null : _markArrived,
                      icon: _isMarkingArrived
                          ? const SizedBox(
                              width: 18, height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.location_on),
                      label: const Text(
                        'ગ્રાહક સ્થળ પર પહોંચ્યા / Arrived at customer',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(AppSizes.largeButtonHeight),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppSizes.buttonRadius),
                        ),
                      ),
                    ),
                  ],

                  if (_status == BookingStatus.arriving) ...[
                    // OTP input
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(AppSizes.cardRadius),
                        border: Border.all(color: AppColors.warning),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'ગ્રાહક પાસેથી OTP મેળવો / Get OTP from customer',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _otpController,
                            keyboardType: TextInputType.number,
                            maxLength: 4,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 10,
                            ),
                            decoration: InputDecoration(
                              hintText: '----',
                              counterText: '',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(AppSizes.buttonRadius),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(AppSizes.buttonRadius),
                                borderSide: const BorderSide(color: AppColors.warning, width: 2),
                              ),
                            ),
                            onChanged: (v) => setState(() => _otpInput = v),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _isVerifyingOtp ? null : _verifyOtp,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.warning,
                                foregroundColor: Colors.white,
                                minimumSize: const Size.fromHeight(AppSizes.largeButtonHeight),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(AppSizes.buttonRadius),
                                ),
                              ),
                              child: _isVerifyingOtp
                                  ? const SizedBox(
                                      width: 20, height: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                    )
                                  : const Text(
                                      'OTP ચકાસો / Verify OTP & Start Ride',
                                      style: TextStyle(fontWeight: FontWeight.w700),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  if (_status == BookingStatus.started) ...[
                    ElevatedButton.icon(
                      onPressed: _isCompleting ? null : _completeRide,
                      icon: _isCompleting
                          ? const SizedBox(
                              width: 18, height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.flag),
                      label: const Text(
                        'સવારી પૂર્ણ / Complete Ride',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(AppSizes.largeButtonHeight),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppSizes.buttonRadius),
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 12),

                  // Call customer
                  if (widget.customerPhone != null && widget.customerPhone!.isNotEmpty)
                    OutlinedButton.icon(
                      onPressed: _callCustomer,
                      icon: const Icon(Icons.phone, size: 18),
                      label: const Text('ગ્રાહકને કૉલ / Call Customer'),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.primary),
                        foregroundColor: AppColors.primary,
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppSizes.buttonRadius),
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
