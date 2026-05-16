import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/booking_models.dart';
import '../services/booking_service.dart';
import '../utils/constants.dart';
import 'tracking_screen.dart';

class BookingSearchScreen extends StatefulWidget {
  const BookingSearchScreen({
    required this.bookingId,
    required this.type,
    required this.primaryColor,
    super.key,
  });

  final String bookingId;
  final String type;
  final Color primaryColor;

  @override
  State<BookingSearchScreen> createState() => _BookingSearchScreenState();
}

class _BookingSearchScreenState extends State<BookingSearchScreen> {
  Timer? _timeoutTimer;
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
    _timeoutTimer = Timer(const Duration(seconds: 60), () async {
      await BookingService.autoCancelIfStillSearching(widget.bookingId);
    });
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    super.dispose();
  }

  Widget _searchingView() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: 86,
          height: 86,
          child: CircularProgressIndicator(
            strokeWidth: 6,
            color: widget.primaryColor,
          ),
        ),
        const SizedBox(height: 18),
        Text(
          '$_entityGu શોધી રહ્યા છીએ... / Searching for $_entityEn...',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 10),
        Text(
          widget.type == BookingType.haul
              ? 'કૃપા કરીને રાહ જુઓ. નજીકના વાહન માલિકોને વિનંતી મોકલાઈ છે.\nPlease wait while nearby vehicle owners respond.'
              : 'કૃપા કરીને રાહ જુઓ. નજીકના ડ્રાઇવરને વિનંતી મોકલાઈ છે.\nPlease wait while nearby drivers respond.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.textSecondary),
        ),
      ],
    );
  }

  Widget _requestStatsView() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('driver_requests')
          .where('bookingId', isEqualTo: widget.bookingId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();

        final docs = snapshot.data!.docs;
        int pending = 0;
        int accepted = 0;
        int rejected = 0;

        for (final doc in docs) {
          final status = (doc.data()['status'] ?? '').toString();
          if (status == DriverRequestStatus.pending) pending++;
          if (status == DriverRequestStatus.accepted) accepted++;
          if (status == DriverRequestStatus.rejected) rejected++;
        }

        final elapsed = DateTime.now().difference(_startedAt);
        if (!_autoCancelledNoRequests &&
            elapsed.inSeconds >= 12 &&
            docs.isEmpty &&
            mounted) {
          _autoCancelledNoRequests = true;
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            await BookingService.autoCancelIfStillSearching(widget.bookingId);
          });
        }

        return Padding(
          padding: const EdgeInsets.only(top: 14),
          child: Text(
            'Requests: ${docs.length}  |  Pending: $pending  |  Accepted: $accepted  |  Rejected: $rejected',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Booking Status'),
        backgroundColor: widget.primaryColor,
        foregroundColor: Colors.white,
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
                child: Text(
                  'નેટવર્ક ભૂલ / Network error\n${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.error),
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
          final saathiId = (data['saathiId'] ?? '').toString();
          final saathiName = (data['saathiName'] ?? 'Gaam Saathi').toString();

          if (status == BookingStatus.accepted) {
            if (!_navigatedToRide) {
              _navigatedToRide = true;
              final trackingSaathiId = saathiId.isNotEmpty ? saathiId : driverId;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute<void>(
                    builder: (_) => TrackingScreen(
                      bookingId: widget.bookingId,
                      saathiId: trackingSaathiId,
                      saathiName: saathiName,
                    ),
                  ),
                );
              });
            }

            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle, color: widget.primaryColor, size: 64),
                  const SizedBox(height: 12),
                  const Text(
                    'બુકિંગ કન્ફર્મ થયું / Booking Accepted',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Opening ride tracking...',
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
                    content: Text('Booking rejected by Saathi. Please try again.'),
                  ),
                );
              });
            }

            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.cancel, color: AppColors.error, size: 56),
                    const SizedBox(height: 12),
                    const Text(
                      'રાઇડ નકારી / Booking Rejected',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Please search again to find another Saathi.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: widget.primaryColor,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Back'),
                    ),
                  ],
                ),
              ),
            );
          }

          if (status == BookingStatus.cancelled) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.timer_off, color: AppColors.error, size: 56),
                    const SizedBox(height: 12),
                    const Text(
                      'સમય પૂરો / Booking Timed Out',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '60 સેકન્ડમાં કોઈ ડ્રાઇવર મળ્યો નથી.\nNo driver accepted within 60 seconds.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: widget.primaryColor,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }

          return Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _searchingView(),
                  _requestStatsView(),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
