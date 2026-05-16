import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../models/booking_models.dart';
import '../services/booking_service.dart';
import '../utils/constants.dart';
import 'ride_tracking_screen.dart';
import 'haul_tracking_screen.dart';

class BookingSearchScreen extends StatefulWidget {
  const BookingSearchScreen({
    required this.bookingId,
    required this.type,
    required this.primaryColor,
    super.key,
    this.pickupLocation,
    this.destinationVillage,
    this.otp,
    this.fare,
  });

  final String bookingId;
  final String type;
  final Color primaryColor;
  final LatLng? pickupLocation;
  final String? destinationVillage;
  final String? otp;
  final double? fare;

  @override
  State<BookingSearchScreen> createState() => _BookingSearchScreenState();
}

class _BookingSearchScreenState extends State<BookingSearchScreen>
    with SingleTickerProviderStateMixin {
  Timer? _timeoutTimer;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  final DateTime _startedAt = DateTime.now();
  bool _autoCancelledNoRequests = false;
  bool _navigatedToRide = false;
  bool _shownRejectedMessage = false;

  String get _entityGu =>
      widget.type == BookingType.haul ? 'વાહન' : 'સાથી';

  String get _entityEn =>
      widget.type == BookingType.haul ? 'Vehicle' : 'Saathi';

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.85, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _timeoutTimer = Timer(const Duration(seconds: 90), () async {
      await BookingService.autoCancelIfStillSearching(widget.bookingId);
    });
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  void _navigateToTracking({
    required String saathiId,
    required String saathiName,
    String saathiPhone = '',
    String? otp,
    double? fare,
  }) {
    if (_navigatedToRide) return;
    _navigatedToRide = true;

    final pickup = widget.pickupLocation ?? const LatLng(20.8306, 73.2469);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      if (widget.type == BookingType.ride) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) => RideTrackingScreen(
              bookingId: widget.bookingId,
              customerLocation: pickup,
              saathiId: saathiId,
              saathiName: saathiName,
              saathiPhone: saathiPhone,
              destinationVillage: widget.destinationVillage,
              otp: otp ?? widget.otp,
              fare: fare ?? widget.fare,
            ),
          ),
        );
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) => HaulTrackingScreen(
              bookingId: widget.bookingId,
              customerLocation: pickup,
              vehicleOwnerId: saathiId,
              ownerName: saathiName,
              ownerPhone: saathiPhone,
              destinationVillage: widget.destinationVillage,
              totalFare: fare ?? widget.fare,
            ),
          ),
        );
      }
    });
  }

  Widget _buildSearchingView() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ScaleTransition(
          scale: _pulseAnimation,
          child: Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: widget.primaryColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              widget.type == BookingType.haul
                  ? Icons.local_shipping
                  : Icons.directions_bike,
              color: widget.primaryColor,
              size: 50,
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          '$_entityGu શોધી રહ્યા છીએ...',
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        Text(
          'Searching for $_entityEn...',
          style: const TextStyle(
            fontSize: 14,
            color: AppColors.textSecondary,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Text(
          widget.type == BookingType.haul
              ? 'નજીકના વાહન માલિકોને વિનંતી મોકલાઈ છે.\nPlease wait while nearby owners respond.'
              : 'નજીકના ડ્રાઇવરને વિનંતી મોકલાઈ છે.\nPlease wait while nearby Saathis respond.',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 13,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildRequestStats() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection(AppConstants.driverRequestsCollection)
          .where('bookingId', isEqualTo: widget.bookingId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();

        final docs = snapshot.data!.docs;
        int pending = 0, accepted = 0, rejected = 0;
        for (final doc in docs) {
          final status = (doc.data()['status'] ?? '').toString();
          if (status == DriverRequestStatus.pending) pending++;
          if (status == DriverRequestStatus.accepted) accepted++;
          if (status == DriverRequestStatus.rejected) rejected++;
        }

        final elapsed = DateTime.now().difference(_startedAt);
        if (!_autoCancelledNoRequests &&
            elapsed.inSeconds >= 15 &&
            docs.isEmpty &&
            mounted) {
          _autoCancelledNoRequests = true;
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            await BookingService.autoCancelIfStillSearching(widget.bookingId);
          });
        }

        if (docs.isEmpty) return const SizedBox.shrink();

        return Container(
          margin: const EdgeInsets.only(top: 16),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppSizes.cardRadius),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _statChip('Notified', '${docs.length}', Colors.blue),
              _statChip('Pending', '$pending', AppColors.warning),
              _statChip('Rejected', '$rejected', AppColors.error),
            ],
          ),
        );
      },
    );
  }

  Widget _statChip(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('$_entityGu શોધ / Booking Status'),
        backgroundColor: widget.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: BookingService.bookingStream(widget.bookingId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.wifi_off, size: 56, color: AppColors.error),
                    const SizedBox(height: 12),
                    Text(
                      AppConstants.noInternetMessage,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.error),
                    ),
                  ],
                ),
              ),
            );
          }

          final data = snapshot.data?.data();
          if (data == null) {
            return const Center(
              child: Text('બુકિંગ મળ્યું નથી / Booking not found'),
            );
          }

          final status = (data['status'] ?? BookingStatus.pending).toString();
          final driverId = (data['driverId'] ?? '').toString();
          final saathiId = (data['saathiId'] ?? driverId).toString();
          final saathiName = (data['saathiName'] ?? '$_entityEn').toString();
          final saathiPhone = (data['saathiPhone'] ?? '').toString();
          final otp = data['otp']?.toString();
          final fare = (data['fare'] as num?)?.toDouble();

          // Auto-navigate to tracking when accepted
          if (status == BookingStatus.accepted) {
            _navigateToTracking(
              saathiId: saathiId.isNotEmpty ? saathiId : driverId,
              saathiName: saathiName,
              saathiPhone: saathiPhone,
              otp: otp,
              fare: fare,
            );

            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle, color: widget.primaryColor, size: 72),
                  const SizedBox(height: 16),
                  Text(
                    '$_entityGu મળ્યો! / $_entityEn Found!',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 20,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    saathiName,
                    style: TextStyle(
                      fontSize: 16,
                      color: widget.primaryColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Tracking ખોલી રહ્યા... / Opening tracking...',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              ),
            );
          }

          if (status == BookingStatus.rejected) {
            if (!_shownRejectedMessage) {
              _shownRejectedMessage = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('$_entityGu ઉપલબ્ધ ન હતા. ફરી પ્રયાસ કરો.'),
                  ),
                );
              });
            }

            return _buildOutcomeScreen(
              icon: Icons.cancel,
              iconColor: AppColors.error,
              title: 'વિનંતી નકારી / Request Rejected',
              subtitle: 'Please search again to find another $_entityEn.',
              buttonLabel: 'ફરી પ્રયાસ / Retry',
              onButton: () => Navigator.of(context).pop(),
            );
          }

          if (status == BookingStatus.cancelled) {
            return _buildOutcomeScreen(
              icon: Icons.timer_off,
              iconColor: AppColors.error,
              title: 'સમય પૂરો / Timed Out',
              subtitle:
                  'No $_entityEn accepted within the time limit.\nPlease try again.',
              buttonLabel: 'ફરી શોધો / Search Again',
              onButton: () => Navigator.of(context).pop(),
            );
          }

          // Still searching
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSizes.largePadding),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildSearchingView(),
                  _buildRequestStats(),
                  const SizedBox(height: 24),
                  TextButton.icon(
                    onPressed: () async {
                      await BookingService.cancelBooking(widget.bookingId);
                      if (mounted) Navigator.of(context).pop();
                    },
                    icon: const Icon(Icons.close, color: AppColors.error),
                    label: const Text(
                      'રદ કરો / Cancel',
                      style: TextStyle(color: AppColors.error),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildOutcomeScreen({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required String buttonLabel,
    required VoidCallback onButton,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.largePadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: iconColor, size: 72),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: onButton,
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.primaryColor,
                foregroundColor: Colors.white,
                minimumSize: const Size(200, AppSizes.largeButtonHeight),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSizes.buttonRadius),
                ),
              ),
              child: Text(
                buttonLabel,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
